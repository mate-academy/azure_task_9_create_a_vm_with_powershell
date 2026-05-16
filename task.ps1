# Location
$location = "polandcentral"
# Resource Group
$resourceGroupName = "mate-azure-task-9"

# Network
$dnsName = "matevm"
$nicName = "matenic"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"

# Key
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_ed25519.pub" -Raw

# VM
$vmName = "matebox"

$vmSecurityType = "Standard"

# VM OS
$publisher = "canonical"
$offer = "ubuntu-22_04-lts"
$sku = "server-gen1"
$version = "latest"

$vmSize = "Standard_B1s"

$user = "azureuser"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;

$securityGroup = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix

$virtualNetwork = New-AzVirtualNetwork -Name $virtualNetworkName -Subnet $subnet -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix

$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -Location $location -ResourceGroupName $resourceGroupName -AllocationMethod Static -DomainNameLabel $dnsName

$nic = New-AzNetworkInterface -PublicIpAddress $publicIp -NetworkSecurityGroup $securityGroup -ResourceGroupName $resourceGroupName -Location $location -Name $nicName -Subnet $virtualNetwork.Subnets[0]

$sshKey = New-AzSshKey -Name $sshKeyName -PublicKey $sshKeyPublicKey -ResourceGroupName $resourceGroupName -Location $location

$secPassword = ConvertTo-SecureString "P@ssw0rd123456789!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($user, $secPassword)


$vm = New-AzVMConfig -VMName $vmName -VMSize $vmSize -SecurityType $vmSecurityType
$vm = Set-AzVMOperatingSystem -VM $vm -Linux -ComputerName $vmName -Credential $cred -DisablePasswordAuthentication
$vm = Add-AzVMSshPublicKey -VM $vm -KeyData $sshKey.publicKey -Path "/home/$user/.ssh/authorized_keys"
$vm = Add-AzVMNetworkInterface -VM $vm -Id $nic.Id
$vm = Set-AzVMSourceImage -VM $vm -PublisherName $publisher -Offer $offer -Skus $sku -Version $version
$vm = Set-AzVMBootDiagnostic -VM $vm -Disable

New-AzVM -VM $vm -ResourceGroupName $resourceGroupName -Location $location