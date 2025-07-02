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
New-AzResourceGroup `
	-Name $resourceGroupName `
	-Location $location `

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating a subnet $subnetName ..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
	-Name $subnetName `
	-AddressPrefix $subnetAddressPrefix `
	-NetworkSecurityGroup $nsg

Write-Host "Creating a virtual network $virtualNetworkName ..."
New-AzVirtualNetwork `
	-Name $virtualNetworkName `
	-ResourceGroupName $resourceGroupName `
	-Location $location `
	-AddressPrefix $vnetAddressPrefix `
	-Subnet $subnetConfig `

Write-Host "Creating a public IP address $publicIpAddressName ..."
New-AzPublicIpAddress `
	-Name $publicIpAddressName `
	-ResourceGroupName $resourceGroupName `
	-Location $location `
	-Sku Standard `
	-AllocationMethod Static `

Write-Host "Creating a SSH key resource $sshKeyName ..."
New-AzSshKey `
	-Name $sshKeyName `
	-ResourceGroupName $resourceGroupName `
	-PublicKey $sshKeyPublicKey `

Write-Host "Creating a virtual machine $vmName ..."
New-AzVm `
	-ResourceGroupName $resourceGroupName `
	-Location $location `
	-Name $vmName `
	-Image $vmImage `
	-Size $vmSize `
	-VirtualNetworkName $virtualNetworkName `
	-SubnetName $subnetName `
	-PublicIpAddressName $publicIpAddressName `
	-SshKeyName $sshKeyName `

Write-Host "Virtual machine $vmName was created successfully."