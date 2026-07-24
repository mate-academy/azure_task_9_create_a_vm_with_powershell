$location = "polandcentral"
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
$vmSize = "Standard_D2s_v4"


Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -Subnet $subnet -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix
New-AzPublicIpAddress -Name $publicIpAddressName -DomainNameLabel $vmName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -Sku Standard
New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location -PublicKey $sshKeyPublicKey
New-AzVM -Name $vmName -ResourceGroupName $resourceGroupName -Location $location -VirtualNetworkName $virtualNetworkName -SubnetName $subnetName -PublicIpAddressName $publicIpAddressName -SecurityGroupName $networkSecurityGroupName -Size $vmSize -Image $vmImage -SshKeyName $sshKeyName

