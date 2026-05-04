$ErrorActionPreference = "Stop"

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

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓
Write-Host "Creating virtual network $virtualNetworkName and subnet $subnetName ..."
$nsg = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg
New-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnetConfig

Write-Host "Creating public IP $publicIpAddressName ..."
$dnsLabel = "matebox$(Get-Random -Maximum 999999)"
New-AzPublicIpAddress `
    -Name $publicIpAddressName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AllocationMethod Static `
    -DomainNameLabel $dnsLabel

Write-Host "Creating SSH key resource $sshKeyName ..."
$sshPublicKeyPath = "$HOME/.ssh/id_ed25519.pub"
if (-not (Test-Path $sshPublicKeyPath)) {
    $sshPublicKeyPath = "$HOME/.ssh/id_rsa.pub"
}
$sshKeyPublicKey = Get-Content -Path $sshPublicKeyPath -Raw
New-AzSshKey `
    -Name $sshKeyName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -PublicKey $sshKeyPublicKey

Write-Host "Creating VM $vmName ..."
New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $vmName `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -SecurityGroupName $networkSecurityGroupName `
    -PublicIpAddressName $publicIpAddressName `
    -Image $vmImage `
    -Size $vmSize `
    -SshKeyName $sshKeyName `
    -Credential (New-Object System.Management.Automation.PSCredential("azureuser", (ConvertTo-SecureString "N0tUsed!" -AsPlainText -Force)))
