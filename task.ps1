$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"

# SSH key handling
$sshKeyPath = Join-Path $HOME ".ssh/id_ed25519.pub"
$sshKeyPublicKey = $null
if (Test-Path $sshKeyPath) {
    $sshKeyPublicKey = (Get-Content -Raw $sshKeyPath).Trim()
}

$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$adminUsername = "azureuser"   # non-interactive user setup

# adding unique dns label
$dnsPrefix = ("matebox{0}" -f (Get-Random -Maximum 9999)).ToLower()

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Network + IP setup ↓↓↓
$subnet  = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
$Vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet
$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -AllocationMethod Static -DomainNameLabel $dnsPrefix -Location $location

# SSH key resource (conditionally with/without public key)
if ($sshKeyPublicKey) {
    New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -Location $location -PublicKey $sshKeyPublicKey
} else {
    Write-Host "⚠️ Public SSH key not found at $sshKeyPath. Creating SSH key resource without uploaded key."
    New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -Location $location
}

# Create VM (non-interactive, clean backticks)
New-AzVm `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name $vmName `
  -Image $vmImage `
  -Size $vmSize `
  -VirtualNetworkName $virtualNetworkName `
  -SubnetName $subnetName `
  -SecurityGroupName $networkSecurityGroupName `
  -PublicIpAddressName $publicIpAddressName `
  -SshKeyName $sshKeyName `
  -AdminUsername $adminUsername

# Show public IP DNS for easy SSH access
$publicIpFqdn = (Get-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName).DnsSettings.Fqdn
Write-Host "✅ VM created successfully. You can SSH using: ssh $adminUsername@$publicIpFqdn"