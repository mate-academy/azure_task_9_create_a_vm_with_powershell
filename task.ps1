$ErrorActionPreference = "Stop"

$location = "eastus"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"

$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"

$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = (Get-Content "$HOME/.ssh/id_rsa.pub" -Raw).Trim()

$vmName = "matebox"

$vmSize = "Standard_D2nls_v6"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup `
    -Name $resourceGroupName `
    -Location $location `
    -Force | Out-Null

Write-Host "Creating or updating network security group $networkSecurityGroupName ..."

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

$nsg = Get-AzNetworkSecurityGroup `
    -Name $networkSecurityGroupName `
    -ResourceGroupName $resourceGroupName `
    -ErrorAction SilentlyContinue

if ($nsg) {
    $nsg.SecurityRules.Clear()
    $nsg.SecurityRules.Add($nsgRuleSSH)
    $nsg.SecurityRules.Add($nsgRuleHTTP)
    $nsg = Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg
}
else {
    $nsg = New-AzNetworkSecurityGroup `
        -Name $networkSecurityGroupName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -SecurityRules $nsgRuleSSH, $nsgRuleHTTP
}

Write-Host "Checking whether VM $vmName already exists ..."

$existingVm = Get-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -ErrorAction SilentlyContinue

if ($existingVm) {
    Write-Host "VM $vmName already exists. Nothing to create."
    exit 0
}

Write-Host "Creating virtual network $virtualNetworkName ..."

$vnet = Get-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $vnet) {
    $subnetConfig = New-AzVirtualNetworkSubnetConfig `
        -Name $subnetName `
        -AddressPrefix $subnetAddressPrefix

    $vnet = New-AzVirtualNetwork `
        -Name $virtualNetworkName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -AddressPrefix $vnetAddressPrefix `
        -Subnet $subnetConfig
}

$subnet = Get-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -VirtualNetwork $vnet

if (-not $subnet) {
    throw "Subnet '$subnetName' was not found in VNet '$virtualNetworkName'."
}

Write-Host "Creating or reusing public IP address $publicIpAddressName ..."

$pip = Get-AzPublicIpAddress `
    -Name $publicIpAddressName `
    -ResourceGroupName $resourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $pip) {
    $pip = New-AzPublicIpAddress `
        -Name $publicIpAddressName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -AllocationMethod Static `
        -Sku Standard `
        -DomainNameLabel "matebox-$((Get-Random))"
}

Write-Host "Creating or reusing SSH key resource $sshKeyName ..."

$existingSshKey = Get-AzSshKey `
    -ResourceGroupName $resourceGroupName `
    -Name $sshKeyName `
    -ErrorAction SilentlyContinue

if (-not $existingSshKey) {
    New-AzSshKey `
        -ResourceGroupName $resourceGroupName `
        -Name $sshKeyName `
        -PublicKey $sshKeyPublicKey | Out-Null
}

Write-Host "Recreating network interface $nicName to match latest config..."

$nicName = "$vmName-nic"
$existingNic = Get-AzNetworkInterface `
    -ResourceGroupName $resourceGroupName `
    -Name $nicName `
    -ErrorAction SilentlyContinue

if ($existingNic) {
    Write-Host "Removing existing NIC..."
    $existingNic | Remove-AzNetworkInterface -Force -Confirm:$false
}

Write-Host "Creating network interface $nicName ..."
$nic = New-AzNetworkInterface `
    -Name $nicName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SubnetId $subnet.Id `
    -PublicIpAddressId $pip.Id `
    -NetworkSecurityGroupId $nsg.Id

Write-Host "Preparing virtual machine configuration ..."

$secPassword = ConvertTo-SecureString `
    "P@ssword12345!" `
    -AsPlainText `
    -Force

$credential = New-Object `
    System.Management.Automation.PSCredential `
    ("azureuser", $secPassword)

$vmConfig = New-AzVMConfig `
    -VMName $vmName `
    -VMSize $vmSize

$vmConfig = Add-AzVMNetworkInterface `
    -VM $vmConfig `
    -Id $nic.Id

$vmConfig = Set-AzVMOperatingSystem `
    -VM $vmConfig `
    -Linux `
    -ComputerName $vmName `
    -Credential $credential

$vmConfig = Set-AzVMSourceImage `
    -VM $vmConfig `
    -PublisherName "Canonical" `
    -Offer "0001-com-ubuntu-server-jammy" `
    -Skus "22_04-lts-gen2" `
    -Version "latest"

# Add-AzVMSshPublicKey is the cmdlet available in Az.Compute.
$vmConfig = Add-AzVMSshPublicKey `
    -VM $vmConfig `
    -KeyData $sshKeyPublicKey `
    -Path "/home/azureuser/.ssh/authorized_keys"

Write-Host "Creating virtual machine $vmName ..."

try {
    $vm = New-AzVM `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -VM $vmConfig `
        -ErrorAction Stop
}
catch {
    Write-Error "VM creation failed: $($_.Exception.Message)"
    exit 1
}

if (-not $vm) {
    Write-Error "VM creation did not return a VM object."
    exit 1
}

$pip = Get-AzPublicIpAddress `
    -Name $publicIpAddressName `
    -ResourceGroupName $resourceGroupName

Write-Host ""
Write-Host "VM $vmName was created successfully."
Write-Host "Public IP: $($pip.IpAddress)"
Write-Host "SSH command: ssh azureuser@$($pip.IpAddress)"
