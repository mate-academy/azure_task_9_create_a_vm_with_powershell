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

# Creating a virtual network and subnet
Write-Host "Creating virtual network $virtualNetworkName with subnet $subnetName ..."
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location `
    -Name $virtualNetworkName -AddressPrefix $vnetAddressPrefix

$subnet = Add-AzVirtualNetworkSubnetConfig -Name $subnetName `
    -VirtualNetwork $vnet -AddressPrefix $subnetAddressPrefix

Set-AzVirtualNetwork -VirtualNetwork $vnet

# Creating a public IP address
Write-Host "Creating public IP address $publicIpAddressName ..."
$publicIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location `
    -Name $publicIpAddressName -AllocationMethod Static -Sku Basic -DnsName "matebox-dns"

# Creating an SSH key resource
Write-Host "Creating SSH key resource $sshKeyName ..."
$sshKey = New-AzSshKey -ResourceGroupName $resourceGroupName -Location $location `
    -Name $sshKeyName -PublicKey $sshKeyPublicKey

# Retrieving resources to create a network interface
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName
$subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $subnetName
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $networkSecurityGroupName
$publicIp = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName

# Creating a network interface for the VM
Write-Host "Creating network interface for VM ..."
$nic = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location `
    -Name "$vmName-nic" -SubnetId $subnet.Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

# Creating a virtual machine
Write-Host "Creating virtual machine $vmName ..."
New-AzVm -ResourceGroupName $resourceGroupName -Location $location `
    -Name $vmName -Size $vmSize -Image $vmImage `
    -NetworkInterfaceId $nic.Id `
    -SshKeyName $sshKeyName

Write-Host "Deployment completed successfully."


