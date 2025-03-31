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
$vmSize = "Standard_B1s"
$adminUsername = "linuxboxsshkey"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating a virtual network $virtualNetworkName ..."
$vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix

Write-Host "Adding a subnet to the virtual network ..."
Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -VirtualNetwork $vnet
$vnet = Set-AzVirtualNetwork -VirtualNetwork $vnet

Write-Host "Creating a public IP $publicIpAddressName ..."
$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod "Static" -DomainNameLabel "vmtest123"

Write-Host "Creating a ssh key $sshKeyName ..."
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey

Write-Host "Creating a network interface (NIC) ..."
$nic = New-AzNetworkInterface -Name "$vmName-nic" -ResourceGroupName $resourceGroupName -Location $location `
    -SubnetId $vnet.Subnets[0].Id -NetworkSecurityGroupId $nsg.Id -PublicIpAddressId $publicIp.Id

Write-Host "Creating a virtual machine configuration ..."
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize | `
    Set-AzVMOperatingSystem -Linux -ComputerName $vmName -Credential (Get-Credential -UserName $adminUsername -Message "Enter the password for the VM.") | `
    Set-AzVMSourceImage -PublisherName "Canonical" -Offer "UbuntuServer" -Sku "22_04-lts-gen2" -Version "latest" | `  # Задание образа Ubuntu 22.04
    Add-AzVMNetworkInterface -Id $nic.Id

Write-Host "Creating a virtual machine $vmName ..."
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig