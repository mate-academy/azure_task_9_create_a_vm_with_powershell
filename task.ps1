$location = "ukwest"
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
$vmImage = "Ubuntu2404"
$vmSize = "Standard_B2ats_v2"
$vmAdminUsername = "prostoponchik"

if (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue) {
  Write-Host "Resource group $resourceGroupName already exists. Deleting it..."
  Remove-AzResourceGroup -Name $resourceGroupName -Force
}

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓
Write-Host "Creating a new virtual network $virtualNetworkName with one subnet ..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig

Write-Host "Creating a new public IP address $publicIpAddressName..."
New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName -Location $location -AllocationMethod Static -DomainNameLabel "prostoponchik-matebox-9"

Write-Host "Creating a new SSH key $sshKeyName..."
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey

Write-Host "Creating a new virtual machine $vmName with image $vmImage and size $vmSize and admin username $vmAdminUsername..."
$vmCredential = New-Object System.Management.Automation.PSCredential($vmAdminUsername, (New-Object System.Security.SecureString))

New-AzVM `
  -ResourceGroupName $resourceGroupName `
  -Name $vmName `
  -Location $location `
  -image $vmImage `
  -size $vmSize `
  -PublicIpAddressName $publicIpAddressName `
  -VirtualNetworkName $virtualNetworkName `
  -SubnetName $subnetName `
  -SecurityGroupName $networkSecurityGroupName `
  -SshKeyName $sshKeyName `
  -Credential $vmCredential

Write-Host "Virtual machine $vmName created successfully."
