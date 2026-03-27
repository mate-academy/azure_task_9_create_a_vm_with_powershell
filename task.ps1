$location = "ukwest"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshPublicKeyPath = "$HOME/.ssh/id_rsa.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ats_v2"
$adminUserName = "azureuser"
$dnsLabel = "matebox" + (Get-Random -Minimum 10000 -Maximum 99999)

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix

Write-Host "Creating a virtual network $virtualNetworkName ..."
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig

Write-Host "Creating a public IP address $publicIpAddressName ..."
New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -Sku Standard -DomainNameLabel $dnsLabel

Write-Host "Creating an SSH key resource $sshKeyName ..."
if (-not (Get-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -ErrorAction SilentlyContinue)) {
    if (Test-Path $sshPublicKeyPath) {
        $sshKeyPublicKey = Get-Content $sshPublicKeyPath -Raw
        New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location -PublicKey $sshKeyPublicKey
    }
    else {
        New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location
    }
}

Write-Host "Creating a virtual machine $vmName ..."
New-AzVm -ResourceGroupName $resourceGroupName -Location $location -Name $vmName -AdminUsername $adminUserName -Image $vmImage -Size $vmSize -VirtualNetworkName $virtualNetworkName -SubnetName $subnetName -PublicIpAddressName $publicIpAddressName -SecurityGroupName $networkSecurityGroupName -SshKeyName $sshKeyName
