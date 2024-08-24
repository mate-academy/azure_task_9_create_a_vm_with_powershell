$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$publicIpAddressName = "linuxboxpip"
$dns = "test-dns"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$networkInterfaceName = "test-network-interface-new"

# Create Resource Group
Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create Network Security Group
Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgExists = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $nsgExists) {
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
    $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
    New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP
} else {
    Write-Host "Network security group $networkSecurityGroupName already exists."
}

# Create Virtual Network
Write-Host "Creating a virtual network $virtualNetworkName ..."
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.0.0/24"
$virtualNetwork = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $subnet

# Create Public IP Address
Write-Host "Creating a public IP address $publicIpAddressName ..."
$publicIpExists = Get-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $publicIpExists) {
    $publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -AllocationMethod Static -DomainNameLabel $dns -Location $location
} else {
    Write-Host "Public IP address $publicIpAddressName already exists."
}

# Create SSH Key
Write-Host "Creating an SSH key $sshKeyName ..."
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey

# Create Network Interface
Write-Host "Creating a network interface $networkInterfaceName ..."
$nicExists = Get-AzNetworkInterface -Name $networkInterfaceName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $nicExists) {
    $networkInterface = New-AzNetworkInterface -Name $networkInterfaceName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $virtualNetwork.Subnets[0].Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId (Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $networkSecurityGroupName).Id
} else {
    Write-Host "Network interface $networkInterfaceName already exists."
}

# Create Virtual Machine
Write-Host "Creating a virtual machine $vmName ..."
New-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $vmName `
    -Image $vmImage `
    -Size $vmSize `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -PublicIpAddressName $publicIpAddressName `
    -NetworkInterface $networkInterface `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName `
    -OpenPorts 22,8080
