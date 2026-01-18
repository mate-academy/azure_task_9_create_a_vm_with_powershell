# Variables
$location = "canadacentral"
$resourceGroupName = "mate-azure-task-9"

$vnetName = "vnet"
$subnetName = "default"
$nsgName = "defaultnsg"

$publicIpName = "linuxboxpip"
$dnsLabel = "matebox$(Get-Random)"

$sshKeyName = "linuxboxsshkey"
$vmName = "matebox"
$vmSize = "Standard_B1s"

# --------------------------------------------------
# Resource Group
# --------------------------------------------------
New-AzResourceGroup `
    -Name $resourceGroupName `
    -Location $location

# --------------------------------------------------
# Network Security Group
# --------------------------------------------------
$nsg = New-AzNetworkSecurityGroup `
    -Name $nsgName `
    -ResourceGroupName $resourceGroupName `
    -Location $location

# --------------------------------------------------
# Virtual Network and Subnet
# --------------------------------------------------
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix "10.0.0.0/24"

$vnet = New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $subnetConfig

# --------------------------------------------------
# Public IP Address
# --------------------------------------------------
$publicIp = New-AzPublicIpAddress `
    -Name $publicIpName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AllocationMethod Static `
    -Sku Standard `
    -DomainNameLabel $dnsLabel

# --------------------------------------------------
# SSH Key
# --------------------------------------------------

$publicKey = Get-Content "$HOME\.ssh\id_ed25519.pub" -Raw

$sshKey = New-AzSshKey `
    -Name $sshKeyName `
    -ResourceGroupName $resourceGroupName `
    -PublicKey $publicKey

# --------------------------------------------------
# Virtual Machine
# --------------------------------------------------

New-AzVm `
    -Name $vmName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Image Ubuntu2204 `
    -Size $vmSize `
    -VirtualNetworkName $vnetName `
    -SubnetName $subnetName `
    -SecurityGroupName $nsgName `
    -PublicIpAddressName $publicIpName `
    -SshKeyName $sshKeyName
