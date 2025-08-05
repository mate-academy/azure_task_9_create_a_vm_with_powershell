# Створення групи ресурсів
$resourceGroupName = "mate-azure-task-9"
$location = "uksouth"
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Створення мережевої групи безпеки
$nsgName = "defaultnsg"
$nsgRule = @{
    Name                     = 'allow-ssh'
    Description              = 'Allow SSH'
    Protocol                 = 'Tcp'
    Direction                = 'Inbound'
    Priority                 = 100
    SourceAddressPrefix      = '*'
    SourcePortRange          = '*'
    DestinationAddressPrefix = '*'
    DestinationPortRange     = '22'
    Access                   = 'Allow'
}
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $nsgName
$nsg | Add-AzNetworkSecurityRuleConfig @nsgRule | Set-AzNetworkSecurityGroup

# Створення віртуальної мережі та підмережі
$vnetName = "vnet"
$subnetName = "default"
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $vnetName -AddressPrefix "10.0.0.0/16"
$subnetConfig = Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.0.0/24" -VirtualNetwork $vnet -NetworkSecurityGroup $nsg
$vnet | Set-AzVirtualNetwork

# Створення публічної IP-адреси
$publicIpName = "linuxboxpip"
$publicIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -Name $publicIpName -AllocationMethod Dynamic -DomainNameLabel "matebox-$((Get-Random -Maximum 99999))"

# Створення SSH-ключа (використовуємо існуючий публічний ключ)
$sshKeyName = "linuxboxsshkey"
$publicKeyPath = "$HOME/.ssh/id_rsa.pub"
if (Test-Path $publicKeyPath) {
    $publicKey = Get-Content $publicKeyPath -Raw
    New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $publicKey
} else {
    Write-Warning "Public key not found at $publicKeyPath. Creating VM with password authentication."
}

# Параметри віртуальної машини
$vmName = "matebox"
$vmSize = "Standard_B1s"
$image = "Ubuntu2204"
$adminUsername = "azureuser"

# Створення віртуальної машини
$vmParams = @{
    ResourceGroupName   = $resourceGroupName
    Name                = $vmName
    Location            = $location
    Image               = $image
    Size                = $vmSize
    VirtualNetworkName  = $vnetName
    SubnetName         = $subnetName
    SecurityGroupName   = $nsgName
    PublicIpAddressName = $publicIpName
    Credential         = (Get-Credential -Message "Enter VM credentials" -UserName $adminUsername)
}

if (Test-Path $publicKeyPath) {
    $vmParams.Add("SshKeyName", $sshKeyName)
}

New-AzVm @vmParams

# Отримання інформації про розгорнуту VM
$vm = Get-AzVm -Name $vmName -ResourceGroupName $resourceGroupName
$ipAddress = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName).IpAddress

Write-Host "VM successfully deployed!"
Write-Host "SSH connection command: ssh ${adminUsername}@${ipAddress}"