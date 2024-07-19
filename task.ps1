# Variables
$resourceGroupName = "mate-azure-task-9"
$location = "uksouth"
$vnetName = "vnet"
$subnetName = "default"
$publicIpName = "linuxboxpip"
$dnsLabel = "mateboxdns" # DNS label
$sshKeyName = "linuxboxsshkey"
$sshKeyPath = "C:\Users\shche\.ssh\id_ed25519.pub" # Path to your public SSH key
$vmName = "matebox"
$vmImagePublisher = "Canonical"
$vmImageOffer = "0001-com-ubuntu-server-jammy"
$vmImageSku = "22_04-lts-gen2"
$vmImageVersion = "latest"
$vmSize = "Standard_B1s"
$adminUsername = "vr89"
$adminPassword = ConvertTo-SecureString "1111" -AsPlainText -Force
$osDiskType = "Premium_LRS" # OS disk type

# Create the resource group
Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

# Create the network security group and rules
Write-Host "Creating a network security group ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
$nsg = New-AzNetworkSecurityGroup -Name "defaultnsg" -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# Create the virtual network and subnet
Write-Host "Creating a virtual network $vnetName ..."
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $vnetName -AddressPrefix "10.0.0.0/16"
$subnet = Add-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.1.0/24" -VirtualNetwork $vnet
$vnet | Set-AzVirtualNetwork

# Retrieve the virtual network to get the subnet ID
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName

# Ensure the subnet exists
if ($vnet.Subnets.Count -eq 0) {
    throw "No subnets found in the virtual network."
}

$subnetId = $vnet.Subnets[0].Id

# Create a public IP address with DNS label
Write-Host "Creating a public IP address $publicIpName ..."
$publicIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -Name $publicIpName -AllocationMethod Static -DomainNameLabel $dnsLabel

# Create an SSH key resource
Write-Host "Creating an SSH key resource $sshKeyName ..."
$sshKeyContent = Get-Content -Path $sshKeyPath -Raw
$sshKey = New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyContent

# Create a network interface
Write-Host "Creating a network interface ..."
$nic = New-AzNetworkInterface -ResourceGroupName $resourceGroupName -Location $location -Name "$vmName-nic" -SubnetId $subnetId -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

# Define the VM configuration
Write-Host "Defining the VM configuration ..."
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize

# Set OS profile and Linux configuration with fixed password
Write-Host "Setting the OS profile and Linux configuration ..."
$cred = New-Object -TypeName PSCredential -ArgumentList $adminUsername, $adminPassword
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName -Credential $cred -DisablePasswordAuthentication $false

# Attach the SSH key to the VM
Write-Host "Attaching the SSH key to the VM ..."
$vmConfig = Add-AzVMSshPublicKey -VM $vmConfig -KeyData $sshKeyContent -Path "/home/$adminUsername/.ssh/authorized_keys"

# Set the VM image
Write-Host "Setting the VM image ..."
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $vmImagePublisher -Offer $vmImageOffer -Skus $vmImageSku -Version $vmImageVersion

# Configure the OS disk
Write-Host "Configuring the OS disk ..."
$vmConfig = Set-AzVMOSDisk -VM $vmConfig -CreateOption FromImage -StorageAccountType $osDiskType

# Attach the network interface
Write-Host "Attaching the network interface ..."
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Create the VM
Write-Host "Creating the virtual machine ..."
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig

Write-Output "Resources have been successfully deployed to the resource group $resourceGroupName in $location."
