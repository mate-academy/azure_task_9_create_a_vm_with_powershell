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
# $vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

$securityType = "Standard"
$user = "azureuser"
$password = ConvertTo-SecureString -String "********" -AsPlainText -Force
$publisherName = "Canonical"
$offer = "0001-com-ubuntu-server-jammy"
$skus = "22_04-lts"
$version = "latest"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig `
  -Name $subnetName `
  -AddressPrefix $subnetAddressPrefix `

$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $virtualNetworkName `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnet

$pipaddr = New-AzPublicIpAddress -Name $publicIpAddressName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -DomainNameLabel $vmName `
    -Sku Basic `
    -AllocationMethod Dynamic

New-AzSshKey -Name $sshKeyName `
    -ResourceGroupName $resourceGroupName `
    -PublicKey $sshKeyPublicKey

$subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }

$nic = New-AzNetworkInterface `
    -Name "${vmName}Nic" `
    -ResourceGroupName $resourceGroupName `
    -NetworkSecurityGroupId $nsg.Id `
    -Location $location `
    -SubnetId $subnet.Id `
    -PublicIpAddressId $pipaddr.Id

$Credential = New-Object System.Management.Automation.PSCredential ($user, $password);

$VirtualMachine = New-AzVMConfig -VMName $vmName -VMSize $vmSize -SecurityType $securiTytype
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -Credential $Credential -ComputerName $vmName
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $publisherName -Offer $offer -Skus $skus -Version $version

New-AzVm -ResourceGroupName  $resourceGroupName -Location $location -VM $VirtualMachine -SshKeyName $sshKeyName
