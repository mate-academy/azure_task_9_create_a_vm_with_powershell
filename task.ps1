$location = "canadacentral"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "$HOME\.ssh\id_ed25519.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ats_v2"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓
Write-Host "OK, lets create networks..."

$sshKey = New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey -Location $location

$sec_group = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName

$sub_net = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $sec_group
$virt_net =  New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $sub_net

$pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -Name $publicIpAddressName -DomainNameLabel "matebox-dns-label"


Write-Host "Lets create VM..."
Write-Host "Location is: '$location'"
Write-Host "vmName is: '$vmName'"

Write-Host "Подготовка конфигурации VM..."


# Создание сетевого интерфейса (NIC)
$nic = New-AzNetworkInterface `
    -Name "$vmName-nic" `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SubnetId $virt_net.Subnets[0].Id `
    -PublicIpAddressId $pip.Id `
    -NetworkSecurityGroupId $sec_group.Id

# Создание конфигурации VM
$vmConfig = New-AzVMConfig `
    -VMName $vmName `
    -VMSize $vmSize

# Настройка Linux + SSH
$vmConfig = Set-AzVMOperatingSystem `
    -VM $vmConfig `
    -Linux `
    -ComputerName $vmName `
    -Credential (New-Object System.Management.Automation.PSCredential ("azureuser",(ConvertTo-SecureString "azureuser" -AsPlainText -Force)))

# Добавление SSH ключа
$vmConfig = Add-AzVMSshPublicKey `
    -VM $vmConfig `
    -KeyData $sshKeyPublicKey `
    -Path "/home/azureuser/.ssh/authorized_keys"

# Подключение NIC
$vmConfig = Add-AzVMNetworkInterface `
    -VM $vmConfig `
    -Id $nic.Id

# Указание образа Ubuntu
$vmConfig = Set-AzVMSourceImage `
    -VM $vmConfig `
    -PublisherName "Canonical" `
    -Offer "0001-com-ubuntu-server-jammy" `
    -Skus "22_04-lts-gen2" `
    -Version "latest"

# Создание VM
Write-Host "Creating virtual machine..."
New-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -VM $vmConfig `
    -Verbose