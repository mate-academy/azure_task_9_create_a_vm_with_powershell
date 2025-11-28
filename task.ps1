# зміні для конфігурації віртуальнорї машини
$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPath = "C:/users/eldar/ssh/id_rsa.pub"
$sshKeyPublicKey = $null
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$dnsPrefix = "matebox$(Get-Random -Maximum 9999)"
$adminUsername = "mateadmin"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup (Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName)
$Vnet = New-AzVirtualnetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet
$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -DomainNameLabel $dnsPrefix

if(Test-Path -PAth $sshKeyPath) {
    Write-Host "SSH publik key found at $sshKeyPath"
    $sshKeyPublicKey = Get-Content -Path $sshKeyPath -Raw
} else {
    Write-Host "SSH public key not found at $sshKeyPath. Please create SSH keys and try again."
    $sshKeyPublicKey = $null
}

Write-Host "Creating SSH key resource $sshKeyName ..."
if($sshKeyPublicKey) {
    New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey -Location $location
} else {
    New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName
}

New-AzVm `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name $vmName `
  -Image $vmImage `
  -Size $vmSize `
  -VirtualNetworkName $virtualNetworkName `
  -SubnetName $subnetName `
  -SecurityGroupName $networkSecurityGroupName `
  -PublicIpAddressName $publicIpAddressName `
  -SshKeyName $sshKeyName `
  -AdminUsername $adminUsername
