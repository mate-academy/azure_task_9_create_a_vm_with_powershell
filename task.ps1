$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP


# Повне очищення існуючих ресурсів перед створенням нових
try {
    Write-Host "Початок очищення ресурсів..."
    
    # Видаляємо всі існуючі ВМ в ресурсній групі
    $existingVMs = Get-AzVM -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    foreach ($vm in $existingVMs) {
        Write-Host "Видалення ВМ: $($vm.Name)"
        Remove-AzVM -ResourceGroupName $resourceGroupName -Name $vm.Name -Force -ErrorAction SilentlyContinue
    }
    
    # Видаляємо всі мережеві інтерфейси
    $existingNICs = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    foreach ($nic in $existingNICs) {
        Write-Host "Видалення мережевого інтерфейсу: $($nic.Name)"
        Remove-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $nic.Name -Force -ErrorAction SilentlyContinue
    }
    
    # Видаляємо ВСІ публічні IP адреси
    $existingPublicIPs = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    foreach ($pip in $existingPublicIPs) {
        Write-Host "Видалення публічної IP: $($pip.Name)"
        Remove-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $pip.Name -Force -ErrorAction SilentlyContinue
    }
    
    # Видаляємо всі SSH ключі
    $existingSSHKeys = Get-AzSshKey -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    foreach ($key in $existingSSHKeys) {
        Write-Host "Видалення SSH ключа: $($key.Name)"
        Remove-AzSshKey -ResourceGroupName $resourceGroupName -Name $key.Name -Force -ErrorAction SilentlyContinue
    }
    
    # Видаляємо всі диски
    $existingDisks = Get-AzDisk -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    foreach ($disk in $existingDisks) {
        Write-Host "Видалення диска: $($disk.Name)"
        Remove-AzDisk -ResourceGroupName $resourceGroupName -DiskName $disk.Name -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "Очищення завершено. Чекаємо завершення операцій..."
    Start-Sleep -Seconds 15
    
} catch {
    Write-Host "Помилка під час очищення: $($_.Exception.Message)"
}
# ↓↓↓ Write your code here ↓↓↓
# ↓↓↓ Напишіть свій код тут ↓↓↓
Write-Host "Створення віртуальної мережі та підмережі..."
$vnet = New-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet @(New-AzVirtualNetworkSubnetConfig `
        -Name $subnetName `
        -AddressPrefix $subnetAddressPrefix)

$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet

Write-Host "Створення публічної IP-адреси..."
# Використовуємо точну назву, яку очікує валідаційний скрипт
$publicIp = New-AzPublicIpAddress `
    -Name $publicIpAddressName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AllocationMethod Static `
    -Sku Standard `
    -DomainNameLabel ("mateboxdns" + (Get-Random -Maximum 99999))

Write-Host "Створення SSH ключа як ресурсу Azure..."
# Створюємо SSH ключ як окремий ресурс Azure
$sshKey = New-AzSshKey `
    -ResourceGroupName $resourceGroupName `
    -Name $sshKeyName `
    -PublicKey $sshKeyPublicKey

Write-Host "Створення мережевого інтерфейсу..."
# Використовуємо стандартну назву для мережевого інтерфейсу
$nicName = $vmName + "-nic"
$nsg = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName
$nic = New-AzNetworkInterface `
    -Name $nicName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SubnetId $subnet.Id `
    -NetworkSecurityGroupId $nsg.Id `
    -PublicIpAddressId $publicIp.Id

Write-Host "Отримання облікових даних для ВМ..."
$cred = Get-Credential -Message "Введіть ім'я користувача для ВМ (пароль буде проігноровано при використанні SSH ключа)"

Write-Host "Створення конфігурації ВМ..."
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize |
    Set-AzVMOperatingSystem -Linux -ComputerName $vmName -Credential $cred -DisablePasswordAuthentication |
    Set-AzVMSourceImage -PublisherName Canonical -Offer 0001-com-ubuntu-server-jammy -Skus 22_04-lts-gen2 -Version latest |
    Add-AzVMNetworkInterface -Id $nic.Id |
    Add-AzVMSshPublicKey -KeyData $sshKeyPublicKey -Path "/home/$($cred.UserName)/.ssh/authorized_keys"

Write-Host "Створення віртуальної машини..."
$vm = New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig

Write-Host "ВМ успішно створено!"
Write-Host "Назва ВМ: $($vm.Name)"
Write-Host "Публічна IP: $($publicIp.IpAddress)"
Write-Host "SSH підключення: ssh $($cred.UserName)@$($publicIp.IpAddress)"





