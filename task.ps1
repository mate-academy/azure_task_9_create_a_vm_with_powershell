# task.ps1

# ——————————————————————————————
# Параметри
# ——————————————————————————————
$location                 = "uksouth"
$resourceGroupName        = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName       = "vnet"
$subnetName               = "default"
$vnetAddressPrefix        = "10.0.0.0/16"
$subnetAddressPrefix      = "10.0.0.0/24"
$publicIpAddressName      = "linuxboxpip"
$sshKeyName               = "linuxboxsshkey"
$sshKeyPublicKey          = Get-Content "~/.ssh/id_rsa.pub" -Raw
$vmName                   = "matebox"
$vmSize                   = "Standard_B1s"
$adminUsername            = "azureuser"

$ErrorActionPreference = 'Stop'

# 1) Resource Group
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "1) Створюю RG '$resourceGroupName'..."
    New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
} else {
    Write-Host "1) RG '$resourceGroupName' уже існує."
}

# 2) NSG
if (-not (Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "`n2) Створюю NSG '$networkSecurityGroupName'..."
    $ruleSSH = New-AzNetworkSecurityRuleConfig -Name "SSH" -Protocol Tcp -Direction Inbound `
        -Priority 1001 -SourceAddressPrefix * -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
    $ruleHTTP = New-AzNetworkSecurityRuleConfig -Name "HTTP" -Protocol Tcp -Direction Inbound `
        -Priority 1002 -SourceAddressPrefix * -SourcePortRange * `
        -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow

    New-AzNetworkSecurityGroup `
        -Name              $networkSecurityGroupName `
        -ResourceGroupName $resourceGroupName `
        -Location          $location `
        -SecurityRules     $ruleSSH,$ruleHTTP | Out-Null
} else {
    Write-Host "`n2) NSG '$networkSecurityGroupName' уже існує."
}
$nsg = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName

# 3) VNet + Subnet
if (-not (Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "`n3) Створюю VNet '$virtualNetworkName'..."
    $vnet = New-AzVirtualNetwork `
        -Name              $virtualNetworkName `
        -ResourceGroupName $resourceGroupName `
        -Location          $location `
        -AddressPrefix     $vnetAddressPrefix

    Write-Host "   Додаю сабнет '$subnetName'..."
    $vnet | Add-AzVirtualNetworkSubnetConfig `
        -Name                 $subnetName `
        -AddressPrefix        $subnetAddressPrefix `
        -NetworkSecurityGroup $nsg | 
      Set-AzVirtualNetwork | Out-Null
} else {
    Write-Host "`n3) VNet '$virtualNetworkName' уже існує."
}
$vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName
$subnet = $vnet.Subnets | Where-Object Name -EQ $subnetName

# 4) Public IP
if (-not (Get-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    $dnsLabel = "mateboxpip" + ([guid]::NewGuid().ToString("N").Substring(0,8))
    Write-Host "`n4) Створюю Public IP '$publicIpAddressName' із DNS-лейблом '$dnsLabel'..."
    $pip = New-AzPublicIpAddress `
        -Name               $publicIpAddressName `
        -ResourceGroupName  $resourceGroupName `
        -Location           $location `
        -AllocationMethod   Static `
        -DomainNameLabel    $dnsLabel | Out-Null
} else {
    Write-Host "`n4) Public IP '$publicIpAddressName' уже існує."
    $pip = Get-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName
    $dnsLabel = $pip.DnsSettings.DomainNameLabel
}

# 5) SSH Key Resource
if (-not (Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType "Microsoft.Compute/sshPublicKeys" -Name $sshKeyName -ErrorAction SilentlyContinue)) {
    Write-Host "`n5) Створюю SSH-ключ-ресурс '$sshKeyName'..."
    New-AzSshKey `
        -ResourceGroupName $resourceGroupName `
        -Name              $sshKeyName `
        -PublicKey         $sshKeyPublicKey | Out-Null
} else {
    Write-Host "`n5) SSH-ключ-ресурс '$sshKeyName' уже існує."
}

# 6) Network Interface
$nicName = "$vmName-nic"
if (-not (Get-AzNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "`n6) Створюю NIC '$nicName'..."
    $ipConfig = New-AzNetworkInterfaceIpConfig `
        -Name              "$vmName-ipconfig" `
        -SubnetId          $subnet.Id `
        -PublicIpAddressId $pip.Id `
        -Primary

    $nic = New-AzNetworkInterface `
        -Name                   $nicName `
        -ResourceGroupName      $resourceGroupName `
        -Location               $location `
        -IpConfiguration        $ipConfig `
        -NetworkSecurityGroupId $nsg.Id
} else {
    Write-Host "`n6) NIC '$nicName' уже існує."
    $nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName
}

# 7) PSCredential для VM
Write-Host "`n7) Введіть будь-який пароль для '$adminUsername'..."
$cred = Get-Credential -UserName $adminUsername -Message "Enter dummy password"

# 8) Створення VM
if (-not (Get-AzVM -Name $vmName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "`n8) Конфігурую та створюю VM '$vmName'..."
    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize

    $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName `
        -Credential $cred -DisablePasswordAuthentication

    # Виправлений блок образу
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig `
        -PublisherName "Canonical" `
        -Offer "0001-com-ubuntu-server-jammy" `
        -Skus "22_04-lts-gen2" `
        -Version "latest"

    $vmConfig = Add-AzVMSshPublicKey -VM $vmConfig -KeyData $sshKeyPublicKey `
        -Path "/home/$adminUsername/.ssh/authorized_keys"

    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

    # Додаткові параметри для оптимізації
    $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
    
    New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig | Out-Null
    
    # Отримуємо публічну IP адресу після створення VM
    $pip = Get-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName
    Write-Host "`n✅ VM '$vmName' успішно створена!"
    Write-Host "   SSH доступ: ssh $adminUsername@$($pip.DnsSettings.Fqdn)"
    Write-Host "   Або за IP: ssh $adminUsername@$($pip.IpAddress)`n"
} else {
    Write-Host "`n8) VM '$vmName' уже існує."
}