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
# Створення підмережі
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix

# Створення віртуальної мережі
New-AzVirtualNetwork `
  -Name $virtualNetworkName `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -AddressPrefix $vnetAddressPrefix `
  -Subnet $subnetConfig | Out-Null

# Створення публічної IP-адреси з унікальною DNS-міткою
$dnsLabel = ("{0}-{1}" -f $vmName.ToLower(), (Get-Random -Maximum 99999))
New-AzPublicIpAddress `
  -Name $publicIpAddressName `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -AllocationMethod Static `
  -Sku Standard `
  -DomainNameLabel $dnsLabel | Out-Null

# Перевірка наявності SSH ключа та зчитування його як один рядок
$sshPubKeyPath = "$HOME/.ssh/id_rsa.pub"
if (-not (Test-Path $sshPubKeyPath)) {
    throw "SSH public key file not found at $sshPubKeyPath"
}
$sshKeyPublicKey = Get-Content $sshPubKeyPath -Raw

# Створення ресурсу SSH-ключа
New-AzSshKey `
  -Name $sshKeyName `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -PublicKey $sshKeyPublicKey | Out-Null

# Створення віртуальної машини (без інтерактивного credential)
New-AzVm `
  -Name $vmName `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Image $vmImage `
  -Size $vmSize `
  -VirtualNetworkName $virtualNetworkName `
  -SubnetName $subnetName `
  -PublicIpAddressName $publicIpAddressName `
  -SecurityGroupName $networkSecurityGroupName `
  -SshKeyName $sshKeyName `
  -AdminUsername "azureuser" | Out-Null

# Вивід DNS-імені для підключення по SSH
$ip = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName
Write-Host "✅ Віртуальна машина створена. Підключення по SSH:"
Write-Host ("ssh azureuser@{0}" -f $ip.DnsSettings.Fqdn)