$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub" -Raw
$vmName = "matebox"
$vmSize = "Standard_B1s"
$vmUser = "azureuser"

# Resource Group
if (-not (Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating resource group $resourceGroupName ..."
    New-AzResourceGroup -Name $resourceGroupName -Location $location
} else {
    Write-Host "Resource group $resourceGroupName already exists."
}

# Network Security Group
$nsg = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $nsg) {
    Write-Host "Creating network security group $networkSecurityGroupName ..."
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 `
        -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
    $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 `
        -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
    $nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName `
        -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP
} else {
    Write-Host "Network security group $networkSecurityGroupName already exists."
}

# Virtual Network and Subnet
$vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $vnet) {
    Write-Host "Creating virtual network $virtualNetworkName and subnet $subnetName ..."
    $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg
    $vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location `
        -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig
} else {
    Write-Host "Virtual network $virtualNetworkName already exists."
}

# Public IP Address
$publicIp = Get-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $publicIp) {
    $dnsLabel = "$vmName-dns-$((Get-Random) -as [string])"
    Write-Host "Creating public IP address $publicIpAddressName with DNS label $dnsLabel ..."
    $publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location `
        -AllocationMethod Static -DomainNameLabel $dnsLabel
} else {
    Write-Host "Public IP $publicIpAddressName already exists."
    if (-not $publicIp.DnsSettings.DomainNameLabel) {
        $dnsLabel = "$vmName-dns-$((Get-Random) -as [string])"
        Write-Host "Updating DNS label for existing public IP to $dnsLabel ..."
        $publicIp | Set-AzPublicIpAddress -DomainNameLabel $dnsLabel
    }
}

# SSH Public Key Resource
$sshKey = Get-AzSshPublicKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $sshKey) {
    Write-Host "Creating SSH public key $sshKeyName ..."
    $sshKey = New-AzSshPublicKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location -PublicKey $sshKeyPublicKey
} else {
    Write-Host "SSH public key $sshKeyName already exists."
}

# Network Interface
$nicName = "${vmName}Nic"
$nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $nic) {
    Write-Host "Creating network interface $nicName ..."
    $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }
    $nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $resourceGroupName -Location $location `
        -SubnetId $subnet.Id -NetworkSecurityGroupId $nsg.Id -PublicIpAddressId $publicIp.Id
} else {
    Write-Host "Network interface $nicName already exists."
}

# Virtual Machine
$vm = Get-AzVm -Name $vmName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
if (-not $vm) {
    Write-Host "Creating virtual machine $vmName ..."
    $vmConfig = New-AzVmConfig -VMName $vmName -VMSize $vmSize |
        Set-AzVMOperatingSystem -Linux -ComputerName $vmName -DisablePasswordAuthentication |
        Set-AzVMSourceImage -PublisherName Canonical -Offer UbuntuServer -Skus 22_04-lts -Version latest |
        Add-AzVMNetworkInterface -Id $nic.Id |
        Set-AzVMSshPublicKey -KeyData $sshKeyPublicKey -Path "/home/$vmUser/.ssh/authorized_keys"

    New-AzVm -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig
} else {
    Write-Host "Virtual machine $vmName already exists."
}
