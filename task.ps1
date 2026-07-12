$location = "southafricanorth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$dnsPrefix = "mate-task-9-clem"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "$HOME/.ssh/id_rsa.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ats_v2"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating a virtual network $virtualNetworkName ..."
$defaultSubnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg
$vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $defaultSubnet

Write-Host "Creating a public ip $publicIpAddressName ..."
$pip = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -AllocationMethod Static -DomainNameLabel $dnsPrefix -Location $location

Write-Host "Creating a ssh key $sshKeyName ..."
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey

Write-Host "Creating a vm $vmName ..."
New-AzVM -ResourceGroupName $resourceGroupName `
         -Name $vmName `
         -Location $location `
         -Image $vmImage `
         -Size $vmSize `
         -VirtualNetworkName $virtualNetworkName `
         -SubnetName $subnetName `
         -SecurityGroupName $networkSecurityGroupName `
         -PublicIpAddressName $publicIpAddressName `
         -SshKeyName $sshKeyName