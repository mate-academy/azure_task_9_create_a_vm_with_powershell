$ErrorActionPreference = "Stop"

$location = "indiasouthcentral"
$resourceGroupName = "mate-azure-task-9"

$networkSecurityGroupName = "defaultnsg"

$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"

$publicIpAddressName = "linuxboxpip"
$dnsLabel = "mate-task9-aleksandrmajlo-20261016"

$sshKeyName = "linuxboxsshkey"
$sshPrivateKeyPath = Join-Path $HOME ".ssh/vm-demo-key"
$sshPublicKeyPath = "$sshPrivateKeyPath.pub"

$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$adminUsername = "azureuser"

if (-not (Test-Path $sshPublicKeyPath)) {
    throw "SSH public key was not found: $sshPublicKeyPath"
}

$sshKeyPublicKey = (Get-Content $sshPublicKeyPath -Raw).Trim()

Write-Host "Creating resource group $resourceGroupName ..."
$resourceGroup = New-AzResourceGroup `
    -Name $resourceGroupName `
    -Location $location

Write-Host "Creating network security group $networkSecurityGroupName ..."

$nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
    -Name "SSH" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1001 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 22 `
    -Access Allow

$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig `
    -Name "HTTP" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1002 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 8080 `
    -Access Allow

$nsg = New-AzNetworkSecurityGroup `
    -Name $networkSecurityGroupName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating subnet $subnetName ..."

$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetAddressPrefix `
    -NetworkSecurityGroup $nsg

Write-Host "Creating virtual network $virtualNetworkName ..."

$vnet = New-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnetConfig

Write-Host "Creating public IP $publicIpAddressName ..."

$publicIp = New-AzPublicIpAddress `
    -Name $publicIpAddressName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Sku Standard `
    -AllocationMethod Static `
    -DomainNameLabel $dnsLabel

Write-Host "Creating Azure SSH key resource $sshKeyName ..."

$sshKey = New-AzSshKey `
    -ResourceGroupName $resourceGroupName `
    -Name $sshKeyName `
    -Location $location `
    -PublicKey $sshKeyPublicKey

# New-AzVM requires a PSCredential object even though SSH authentication
# will use linuxboxsshkey. A random password avoids storing a real password.
$randomPassword = "$([guid]::NewGuid().ToString())aA1!"
$securePassword = ConvertTo-SecureString `
    -String $randomPassword `
    -AsPlainText `
    -Force

$credential = [PSCredential]::new(
    $adminUsername,
    $securePassword
)

Write-Host "Creating virtual machine $vmName ..."

$vm = New-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $vmName `
    -Credential $credential `
    -VirtualNetworkName $virtualNetworkName `
    -AddressPrefix $vnetAddressPrefix `
    -SubnetName $subnetName `
    -SubnetAddressPrefix $subnetAddressPrefix `
    -PublicIpAddressName $publicIpAddressName `
    -DomainNameLabel $dnsLabel `
    -AllocationMethod Static `
    -PublicIpSku Standard `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName `
    -Image $vmImage `
    -Size $vmSize `
    -SecurityType Standard `
    -OSDiskDeleteOption Delete `
    -NetworkInterfaceDeleteOption Delete

Write-Host "Deployment completed."

Get-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Status |
    Select-Object Name, Location, PowerState

Get-AzPublicIpAddress `
    -ResourceGroupName $resourceGroupName `
    -Name $publicIpAddressName |
    Select-Object Name, IpAddress, @{
        Name = "Fqdn"
        Expression = { $_.DnsSettings.Fqdn }
    }