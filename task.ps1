$ErrorActionPreference = "Stop"

# -------------------------
# Variables
# -------------------------
$rg           = "mate-azure-task-9"
$location     = "westeurope"
$vnetName     = "vnet"
$subnetName   = "default"
$nsgName      = "defaultnsg"          # ← оставляем lowercase
$nicName      = "matebox-nic"
$pipName      = "linuxboxpip"
$vmName       = "matebox"
$vnetPrefix   = "10.0.0.0/16"
$subnetPrefix = "10.0.0.0/24"
$vmSize       = "Standard_D2s_v5"     # ← более стабильный размер

# -------------------------
# Cleanup (улучшенная)
# -------------------------
Write-Host "Выполняется очистка предыдущих ресурсов..." -ForegroundColor Yellow

Remove-AzVM -Name $vmName -ResourceGroupName $rg -Force -ErrorAction SilentlyContinue
Remove-AzNetworkInterface -Name $nicName -ResourceGroupName $rg -Force -ErrorAction SilentlyContinue
Remove-AzPublicIpAddress -Name $pipName -ResourceGroupName $rg -Force -ErrorAction SilentlyContinue
Remove-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rg -Force -ErrorAction SilentlyContinue
Remove-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rg -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 5   # небольшая пауза

Write-Host "Очистка завершена." -ForegroundColor Green

# -------------------------
# Resource Group
# -------------------------
if (-not (Get-AzResourceGroup -Name $rg -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $rg -Location $location | Out-Null
    Write-Host "Resource Group создан" -ForegroundColor Green
}

# -------------------------
# NSG
# -------------------------
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rg -ErrorAction SilentlyContinue
if (-not $nsg) {
    $nsg = New-AzNetworkSecurityGroup -Name $nsgName `
                                      -ResourceGroupName $rg `
                                      -Location $location
    Write-Host "NSG $nsgName создан" -ForegroundColor Green
}

# -------------------------
# VNet + Subnet
# -------------------------
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rg -ErrorAction SilentlyContinue
if ($vnet) { 
    Remove-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rg -Force 
}

$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetPrefix `
    -NetworkSecurityGroup $nsg

$vnet = New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $rg `
    -Location $location `
    -AddressPrefix $vnetPrefix `
    -Subnet $subnetConfig

$subnetId = ($vnet.Subnets | Where-Object Name -eq $subnetName).Id
Write-Host "VNet и Subnet созданы" -ForegroundColor Green

# -------------------------
# Public IP
# -------------------------
$pip = Get-AzPublicIpAddress -Name $pipName -ResourceGroupName $rg -ErrorAction SilentlyContinue
if (-not $pip) {
    $pip = New-AzPublicIpAddress `
        -Name $pipName `
        -ResourceGroupName $rg `
        -Location $location `
        -AllocationMethod Static `
        -Sku Standard `
        -DomainNameLabel ("mateboxdns" + (Get-Random -Maximum 99999))
    Write-Host "Public IP создан" -ForegroundColor Green
}

# -------------------------
# NIC
# -------------------------
$nic = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $rg -ErrorAction SilentlyContinue
if (-not $nic) {
    $nic = New-AzNetworkInterface `
        -Name $nicName `
        -ResourceGroupName $rg `
        -Location $location `
        -SubnetId $subnetId `
        -PublicIpAddressId $pip.Id `
        -NetworkSecurityGroupId $nsg.Id
    Write-Host "NIC создан" -ForegroundColor Green
}

# -------------------------
# Virtual Machine
# -------------------------
if (-not (Get-AzVM -Name $vmName -ResourceGroupName $rg -ErrorAction SilentlyContinue)) {
    
    $pubKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub" -Raw -ErrorAction Stop

    $cred = Get-Credential -Message "Enter username for VM (password will be ignored)"

    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize

    $vmConfig = Set-AzVMOperatingSystem `
        -VM $vmConfig `
        -Linux `
        -ComputerName $vmName `
        -Credential $cred `
        -DisablePasswordAuthentication

    $vmConfig = Set-AzVMSourceImage `
        -VM $vmConfig `
        -PublisherName "Canonical" `
        -Offer "0001-com-ubuntu-server-jammy" `
        -Skus "22_04-lts" `
        -Version "latest"

    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

    $vmConfig = Add-AzVMSshPublicKey `
        -VM $vmConfig `
        -KeyData $pubKey `
        -Path "/home/$($cred.UserName)/.ssh/authorized_keys"

    New-AzVM -ResourceGroupName $rg -Location $location -VM $vmConfig -ErrorAction Stop
   
    Write-Host "VM $vmName успешно создана!" -ForegroundColor Green
}
else {
    Write-Host "VM уже существует" -ForegroundColor Yellow
}