# task.ps1
$ErrorActionPreference = "Stop"
$ConfirmPreference = "None"
$ProgressPreference = "SilentlyContinue"

# ===== SETTINGS =====
$location = "westeurope"                 # можно менять
$resourceGroupName = "mate-azure-task-9"

$networkSecurityGroupName = "defaultnsg"

$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"

$publicIpAddressName = "linuxboxpip"
$dnsLabel = ("matebox-" + (Get-Random -Minimum 10000 -Maximum 99999))  # должен быть уникален

$sshKeyName = "linuxboxsshkey"
# ВАЖНО: у тебя ключ лежит в /root/.ssh/
$sshKeyPublicKey = Get-Content -Raw "/root/.ssh/mate_azure_vm.pub"

$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$vmUser = "azureuser"

# ===== 1) Resource group =====
Write-Host "Creating / updating resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force | Out-Null

# ===== 2) NSG + rules (SSH 22, HTTP 80) =====
Write-Host "Creating / updating network security group $networkSecurityGroupName ..."

# Создаём правила
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name "SSH" -Protocol Tcp -Direction Inbound -Priority 1001 `
  -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow

$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name "HTTP-8080" -Protocol Tcp -Direction Inbound -Priority 1002 `
  -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow

# Создаём/пересоздаём NSG (если уже есть — Azure перезапишет правила)
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName `
  -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP -Force

# ===== 3) VNet + Subnet =====
Write-Host "Creating / updating VNet $virtualNetworkName and subnet $subnetName ..."
$vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName -ErrorAction SilentlyContinue

if (-not $vnet) {
  $subnetCfg = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
  $vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location `
    -AddressPrefix $vnetAddressPrefix -Subnet $subnetCfg -Force
} else {
  # гарантируем, что subnet есть
  $sub = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }
  if (-not $sub) {
    Add-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet -AddressPrefix $subnetAddressPrefix | Out-Null
    $vnet | Set-AzVirtualNetwork | Out-Null
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $virtualNetworkName
  }
}

# ===== 4) Public IP + DNS label =====
Write-Host "Creating / updating Public IP $publicIpAddressName with DNS label ..."
$pip = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName -ErrorAction SilentlyContinue
if (-not $pip) {
  $pip = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location `
    -AllocationMethod Static -Sku Standard -DomainNameLabel $dnsLabel -Force
}

# ===== 5) SSH key resource =====
Write-Host "Creating / updating SSH key resource $sshKeyName ..."
# В твоей версии New-AzSshKey НЕ принимает -Location/-Force, поэтому только эти параметры:
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey | Out-Null

# ===== 6) VM =====
Write-Host "Creating VM $vmName ..."

# New-AzVM требует Credential (даже если зайдёшь по SSH ключу)
$secure = ConvertTo-SecureString "TempPassword12345!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($vmUser, $secure)

# КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: создаём TrustedLaunch, чтобы не упираться в securityType=Standard (feature not registered)
New-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Location $location `
  -Image $vmImage -Size $vmSize `
  -VirtualNetworkName $virtualNetworkName -SubnetName $subnetName `
  -SecurityGroupName $networkSecurityGroupName `
  -PublicIpAddressName $publicIpAddressName `
  -SshKeyName $sshKeyName `
  -Credential $cred `
  -SecurityType "TrustedLaunch" | Out-Null

# ===== OUTPUT =====
$pip2 = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName
Write-Host ""
Write-Host "Public IP: $($pip2.IpAddress)"
Write-Host "FQDN:      $($pip2.DnsSettings.Fqdn)"
Write-Host "SSH:       ssh -i /root/.ssh/mate_azure_vm $vmUser@$($pip2.DnsSettings.Fqdn)"
