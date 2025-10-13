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
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP -Force

# ↓↓↓ Write your code here ↓↓↓
Write-Host "Creating a virtual network $virtualNetworkName and subnet $subnetName ..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
  -Name $subnetName `
  -AddressPrefix $subnetAddressPrefix

New-AzVirtualNetwork `
  -Name $virtualNetworkName `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -AddressPrefix $vnetAddressPrefix `
  -Subnet $subnetConfig `
  -Force

Write-Host "Creating a public IP address $publicIpAddressName with DNS label ..."
New-AzPublicIpAddress `
  -Name $publicIpAddressName `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -AllocationMethod Static `
  -Sku Standard `
  -DomainNameLabel "matebox$((Get-Random -Maximum 9999))" `
  -Force

Write-Host "Creating an SSH key resource $sshKeyName ..."
New-AzSshKey `
  -Name $sshKeyName `
  -ResourceGroupName $resourceGroupName `
  -PublicKey $sshKeyPublicKey

Write-Host "Creating new Virtual Machine $vmName ..."
New-AzVM `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name $vmName `
  -VirtualNetworkName $virtualNetworkName `
  -SubnetName $subnetName `
  -PublicIpAddressName $publicIpAddressName `
  -SecurityGroupName $networkSecurityGroupName `
  -Image $vmImage `
  -Size $vmSize `
  -Credential (Get-Credential) `
  -SshKeyName $sshKeyName