$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$domainNameLabel = "task-9-domain"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓
Write-Host "Creating a virtual network $virtualNetworkName and a subnet $subnetName ..."
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet @(New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix)

Write-Host "Creating a public IP address $publicIpAddressName with DNS label ..."
New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -Name $publicIpAddressName -AllocationMethod Static -Sku Basic -DomainNameLabel $domainNameLabel

Write-Host "Creating a SSH key resource $sshKeyName ..."
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey "$sshKeyPublicKey"

Write-Host "Creating a virtual machine $vmName ..."
$credential = Get-Credential

New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -image $vmImage `
    -size $vmSize `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -SecurityGroupName $networkSecurityGroupName `
    -PublicIpAddressName $publicIpAddressName `
    -OpenPorts 22,8080 `
    -SshKeyName $sshKeyName `
    -Credential $credential
