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

# ---- Resource Group ----
if (-not (Get-AzResourceGroup -Name $Rg -ErrorAction SilentlyContinue)) {
  New-AzResourceGroup -Name $Rg -Location $Location | Out-Null
}

# ---- NSG + rules (idempotent) ----
$nsgObj = Get-AzNetworkSecurityGroup -Name $Nsg -ResourceGroupName $Rg -ErrorAction SilentlyContinue
if (-not $nsgObj) {
  $sshRule  = New-AzNetworkSecurityRuleConfig -Name "ssh"  -Protocol Tcp -Direction Inbound -Priority 1000 `
             -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
  $httpRule = New-AzNetworkSecurityRuleConfig -Name "http" -Protocol Tcp -Direction Inbound -Priority 1001 `
             -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow
  $nsgObj   = New-AzNetworkSecurityGroup -Name $Nsg -ResourceGroupName $Rg -Location $Location -SecurityRules $sshRule,$httpRule
} else {
  $needSsh  = -not ($nsgObj.SecurityRules | Where-Object Name -eq 'ssh')
  $needHttp = -not ($nsgObj.SecurityRules | Where-Object Name -eq 'http')
  if ($needSsh) {
    $nsgObj.SecurityRules.Add( (New-AzNetworkSecurityRuleConfig -Name "ssh" -Protocol Tcp -Direction Inbound -Priority 1000 `
                                -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow) )
  }
  if ($needHttp) {
    $nsgObj.SecurityRules.Add( (New-AzNetworkSecurityRuleConfig -Name "http" -Protocol Tcp -Direction Inbound -Priority 1001 `
                                -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80 -Access Allow) )
  }
  if ($needSsh -or $needHttp) { $nsgObj | Set-AzNetworkSecurityGroup | Out-Null }
}

# ---- VNet + Subnet with NSG (idempotent) ----
$vnetObj = Get-AzVirtualNetwork -Name $Vnet -ResourceGroupName $Rg -ErrorAction SilentlyContinue
if (-not $vnetObj) {
  $subnetCfg = New-AzVirtualNetworkSubnetConfig -Name $Subnet -AddressPrefix "10.10.1.0/24" -NetworkSecurityGroup $nsgObj
  $vnetObj   = New-AzVirtualNetwork -Name $Vnet -ResourceGroupName $Rg -Location $Location -AddressPrefix "10.10.0.0/16" -Subnet $subnetCfg
} else {
  $sn = $vnetObj.Subnets | Where-Object Name -eq $Subnet
  if (-not $sn) {
    $sn = Add-AzVirtualNetworkSubnetConfig -Name $Subnet -AddressPrefix "10.10.1.0/24" -VirtualNetwork $vnetObj -NetworkSecurityGroup $nsgObj
    $vnetObj | Set-AzVirtualNetwork | Out-Null
  } elseif (-not $sn.NetworkSecurityGroup) {
    $sn.NetworkSecurityGroup = $nsgObj
    $vnetObj | Set-AzVirtualNetwork | Out-Null
  }
}

# ---- Public IP (Standard, Static, DNS label) ----
$pipObj = Get-AzPublicIpAddress -Name $Pip -ResourceGroupName $Rg -ErrorAction SilentlyContinue
if (-not $pipObj) {
  $pipObj = New-AzPublicIpAddress -Name $Pip -ResourceGroupName $Rg -Location $Location `
           -Sku Standard -AllocationMethod Static -DomainNameLabel $DnsLabel
}

# ---- SSH Key (robust: don't pass empty -PublicKey) ----
$pubKeyText = $null
if (Test-Path -LiteralPath $PubKey) {
  $pubKeyText = (Get-Content -LiteralPath $PubKey -Raw).Trim()
}

$sshKeyRes = Get-AzSshKey -ResourceGroupName $Rg -Name $SshRes -ErrorAction SilentlyContinue
if (-not $sshKeyRes) {
  if ([string]::IsNullOrWhiteSpace($pubKeyText)) {
    $sshKeyRes = New-AzSshKey -ResourceGroupName $Rg -Name $SshRes -Location $Location
    Write-Host "⚠️  Public key not found at '$PubKey'. SSH Key resource created WITHOUT a key."
    Write-Host "   You can upload a public key to the resource later if needed."
  } else {
    $sshKeyRes = New-AzSshKey -ResourceGroupName $Rg -Name $SshRes -Location $Location -PublicKey $pubKeyText
  }
}

# ---- VM (create only if missing) ----
$vmExist = Get-AzVM -Name $VmName -ResourceGroupName $Rg -ErrorAction SilentlyContinue
if (-not $vmExist) {
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
    -OpenPorts 22,80 | Out-Null
} else {
  Write-Host "ℹ️  VM '$VmName' already exists — skipping creation."
}

# ---- Output DNS & IP ----
$pipOut = Get-AzPublicIpAddress -Name $Pip -ResourceGroupName $Rg
Write-Host ("==> FQDN: {0}   IP: {1}" -f $pipOut.DnsSettings.Fqdn, $pipOut.IpAddress)
