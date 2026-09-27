$location = "denmarkeast"
$resourceGroupName = "mate-azure-task-9"

$networkSecurityGroupName = "defaultnsg"

$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"

$publicIpAddressName = "linuxboxpip"

$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "$HOME\.ssh\id_rsa.pub"

$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2s_v2"
$ErrorActionPreference = "Stop"


# ============================================
# RESOURCE GROUP
# ============================================

Write-Host "Creating resource group $resourceGroupName ..."

New-AzResourceGroup `
    -Name $resourceGroupName `
    -Location $location


# ============================================
# NETWORK SECURITY GROUP
# ============================================

Write-Host "Creating network security group $networkSecurityGroupName ..."

$nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
    -Name SSH `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1001 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 22 `
    -Access Allow

$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig `
    -Name HTTP `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1002 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 8080 `
    -Access Allow

$nsg = New-AzNetworkSecurityGroup `
    -Name $networkSecurityGroupName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SecurityRules $nsgRuleSSH, $nsgRuleHTTP


# ============================================
# VIRTUAL NETWORK
# ============================================

Write-Host "Creating virtual network $virtualNetworkName ..."

$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetAddressPrefix `
    -NetworkSecurityGroupId $nsg.Id

$vnet = New-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnetConfig


# ============================================
# PUBLIC IP
# ============================================

Write-Host "Creating public IP address $publicIpAddressName ..."

$dnsLabel = "matebox-$([guid]::NewGuid().ToString().Substring(0,8))"

$publicIp = New-AzPublicIpAddress `
    -Name $publicIpAddressName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AllocationMethod Static `
    -Sku Standard `
    -DomainNameLabel $dnsLabel


# ============================================
# SSH KEY
# ============================================

Write-Host "Creating SSH key $sshKeyName ..."

$sshKey = New-AzSshKey `
    -Name $sshKeyName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -PublicKey $sshKeyPublicKey


# ============================================
# NETWORK INTERFACE
# ============================================

Write-Host "Creating network interface ..."




# ============================================
# VIRTUAL MACHINE
# ============================================

Write-Host "Creating virtual machine $vmName ..."

$securePassword = ConvertTo-SecureString `
    "TempPassword123!" `
    -AsPlainText `
    -Force

$credential = New-Object `
    System.Management.Automation.PSCredential `
    ("azureuser", $securePassword)

New-AzVM `
    -Name $vmName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Credential $credential `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -PublicIpAddressName $publicIpAddressName `
    -SecurityGroupName $networkSecurityGroupName `
    -Image $vmImage `
    -Size $vmSize `
    -SshKeyName $sshKeyName

# ============================================
# OUTPUT
# ============================================

Write-Host ""
Write-Host "========================================"
Write-Host "VM deployment completed!"
Write-Host "========================================"
Write-Host "Resource Group: $resourceGroupName"
Write-Host "VM Name:        $vmName"
Write-Host "Location:       $location"
Write-Host "VM Size:        $vmSize"
Write-Host "Public IP:      $($publicIp.IpAddress)"
Write-Host "DNS Name:       $($publicIp.DnsSettings.Fqdn)"
Write-Host "SSH User:       azureuser"
Write-Host "========================================"