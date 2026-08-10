$location = "swedencentral"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "mateboxpip"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ats_v2"

New-AzResourceGroup -Name $resourceGroupName -Location $location

$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
$vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -DomainNameLabel ("matebox" + (Get-Random -Maximum 9999))

$vm = New-AzVm -ResourceGroupName $resourceGroupName -Name $vmName -Location $location -Image $vmImage -Size $vmSize -Credential (Get-Credential -UserName azureuser -Message "Enter password for azureuser") -VirtualNetworkName $virtualNetworkName -SubnetName $subnetName -PublicIpAddressName $publicIpAddressName -SecurityGroupName $networkSecurityGroupName

$pip = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName
Write-Host "VM IP: $($pip.IpAddress)"
Write-Host "DNS: $($pip.DomainNameLabel).$location.cloudapp.azure.com"