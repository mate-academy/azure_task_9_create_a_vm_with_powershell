$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub"

Write-Host "Creating a resource group $resourceGroupName ..."
Try {
    $resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location -ErrorAction Stop
    $resourceGroup
} Catch {
    Write-Warning "Resource group $resourceGroupName might already exist or there was an error creating it: $($_.Exception.Message)"
}

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP
$nsg

Write-Host "Creating a virtual network $virtualNetworkName with subnet $subnetName ..."
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg
$vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet
$vnet

Write-Host "Creating a public IP address $publicIpAddressName with DNS label..."
$pip = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -DomainNameLabel "lnxbxpp" -Sku Standard
$pip

Write-Host "Creating a network interface for VM..."
$nic = New-AzNetworkInterface -Name "$vmName-nic" -ResourceGroupName $resourceGroupName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id
$nic

Write-Host "Creating an SSH key resource $sshKeyName ..."
$sshkey = New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey
$sshkey

Write-Host "Creating a virtual machine $vmName ..."
$cred = Get-Credential -UserName azureuser

$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize

$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest"

$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName -Credential $cred

$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

$vmConfig = Add-AzVMSshPublicKey -VM $vmConfig -Path "/home/azureuser/.ssh/authorized_keys" -KeyData $sshKeyPublicKey

$vmConfig = Set-AzVMOSDisk -VM $vmConfig -CreateOption FromImage -Caching ReadWrite

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig