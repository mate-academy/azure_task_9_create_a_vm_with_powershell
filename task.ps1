[CmdletBinding()]
param(
  [string]$Location = "uksouth",
  [string]$Rg       = "mate-azure-task-9",
  [string]$Vnet     = "vnet",
  [string]$Subnet   = "default",
  [string]$Nsg      = "defaultnsg",
  [string]$Pip      = "linuxboxpip",
  [string]$DnsLabel = ("matebox-" + ([guid]::NewGuid().ToString("N").Substring(0,6))),
  [string]$SshRes   = "linuxboxsshkey",
  [string]$VmName   = "matebox",
  [string]$VmSize   = "Standard_B1s",
  [string]$Image    = "Ubuntu2204",
  [string]$PubKey   = "$HOME/.ssh/id_rsa.pub"
)

Write-Host "==> Deploy to $Location"

# RG
if (-not (Get-AzResourceGroup -Name $Rg -ErrorAction SilentlyContinue)) {
  New-AzResourceGroup -Name $Rg -Location $Location | Out-Null
}

# NSG + правила
$sshRule  = New-AzNetworkSecurityRuleConfig -Name "ssh"  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$httpRule = New-AzNetworkSecurityRuleConfig -Name "http" -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow
$nsgObj   = New-AzNetworkSecurityGroup -Name $Nsg -ResourceGroupName $Rg -Location $Location -SecurityRules $sshRule,$httpRule

# VNet + Subnet з NSG
$subnetCfg = New-AzVirtualNetworkSubnetConfig -Name $Subnet -AddressPrefix "10.10.1.0/24" -NetworkSecurityGroup $nsgObj
$vnetObj   = New-AzVirtualNetwork -Name $Vnet -ResourceGroupName $Rg -Location $Location -AddressPrefix "10.10.0.0/16" -Subnet $subnetCfg

# Public IP (Standard SKU!)
$pipObj = New-AzPublicIpAddress -Name $Pip -ResourceGroupName $Rg -Location $Location -Sku Standard -AllocationMethod Static -DomainNameLabel $DnsLabel

# SSH Key (без -Location для сумісності з твоїм модулем)
$pubKeyText = if (Test-Path $PubKey) { Get-Content -LiteralPath $PubKey -Raw } else { "" }
$sshKeyRes  = New-AzSshKey -ResourceGroupName $Rg -Name $SshRes -PublicKey $pubKeyText

# VM
New-AzVM `
  -ResourceGroupName $Rg `
  -Location $Location `
  -Name $VmName `
  -Image $Image `
  -Size $VmSize `
  -VirtualNetworkName $Vnet `
  -SubnetName $Subnet `
  -PublicIpAddressName $Pip `
  -DomainNameLabel $DnsLabel `
  -SecurityGroupName $Nsg `
  -SshKeyName $SshRes `
  -OpenPorts 22

# Вивід DNS та IP
$pipOut = Get-AzPublicIpAddress -Name $Pip -ResourceGroupName $Rg
Write-Host "==> FQDN: $($pipOut.DnsSettings.Fqdn)   IP: $($pipOut.IpAddress)"