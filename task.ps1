$location = "ukwest"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$dnsPrefix = "matebox-ukwest-0001"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa_azure.pub" -Raw
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ats_v2"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating a virtual network $virtualNetworkName and subnet $subnetName ..."
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork `
  -Name $virtualNetworkName `
  -ResourceGroupName $resourceGroupName -Location $location `
  -AddressPrefix $vnetAddressPrefix `
  -Subnet $subnet

Write-Host "Creating a public IP address $publicIpAddressName ..."
New-AzPublicIpAddress -Name $publicIpAddressName `
  -ResourceGroupName $resourceGroupName `
  -Sku Standard `
  -AllocationMethod Static `
  -DomainNameLabel $dnsPrefix `
  -Location $location

Write-Host "Creating a public SSH key $sshKeyName ..."
New-AzSshKey `
  -ResourceGroupName $resourceGroupName `
  -Name $sshKeyName `
  -PublicKey $sshKeyPublicKey

Write-Host "Creating a virtual machine $vmName ..."
New-AzVM `
  -Name $vmName `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -VirtualNetworkName $virtualNetworkName `
  -SubnetName $subnetName `
  -PublicIpAddressName $publicIpAddressName `
  -SecurityGroupName $networkSecurityGroupName `
  -SshKeyName $sshKeyName `
  -Image $vmImage `
  -Size $vmSize



