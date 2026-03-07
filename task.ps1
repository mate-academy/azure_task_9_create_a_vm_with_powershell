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
$vmAdminUsername = "azureuser"
$dnsLabel = "linuxboxpip$((Get-Random -Minimum 10000 -Maximum 99999))"

$publicKeyPathCandidates = @(
    "~/.ssh/id_rsa.pub",
    "~/.ssh/id_ed25519.pub"
)

$sshKeyPublicKey = $null
foreach ($path in $publicKeyPathCandidates) {
    $resolvedPath = [Environment]::ExpandEnvironmentVariables($path.Replace("~", $HOME))
    if (Test-Path $resolvedPath) {
        $sshKeyPublicKey = (Get-Content -Path $resolvedPath -Raw).Trim()
        break
    }
}

if (-not $sshKeyPublicKey) {
    throw "Unable to find a public SSH key file. Please create ~/.ssh/id_rsa.pub or ~/.ssh/id_ed25519.pub and re-run the script."
}

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating virtual network $virtualNetworkName and subnet $subnetName ..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig

Write-Host "Creating public IP $publicIpAddressName with DNS label $dnsLabel ..."
New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic -Sku Basic -DomainNameLabel $dnsLabel

Write-Host "Creating SSH key resource $sshKeyName ..."
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -Location $location -PublicKey $sshKeyPublicKey

Write-Host "Creating virtual machine $vmName ..."
New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -Image $vmImage `
    -Size $vmSize `
    -Credential (Get-Credential -UserName $vmAdminUsername -Message "Enter any password (it will not be used because we disable password auth)") `
    -DisablePasswordAuthentication `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -PublicIpAddressName $publicIpAddressName `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName
