$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub" -Raw
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$vmUser = "azureuser"  # заміни на бажане ім'я користувача

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating virtual network $virtualNetworkName and subnet $subnetName ..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig

$dnsLabel = "$vmName-dns-$((Get-Random) -as [string])"
Write-Host "Creating public IP address $publicIpAddressName with DNS label $dnsLabel ..."
New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -DomainNameLabel $dnsLabel

Write-Host "Creating SSH public key $sshKeyName ..."
New-AzSshPublicKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location -PublicKey $sshKeyPublicKey

# Отримуємо ресурси
$vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName
$subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }
$nsg = Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName
$publicIp = Get-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName
$sshKey = Get-AzSshPublicKey -Name $sshKeyName -ResourceGroupName $resourceGroupName

Write-Host "Creating network interface mateboxNic ..."
$nic = New-AzNetworkInterface -Name "mateboxNic" -ResourceGroupName $resourceGroupName -Location $location `
    -SubnetId $subnet.Id -NetworkSecurityGroupId $nsg.Id -PublicIpAddressId $publicIp.Id

Write-Host "Creating virtual machine $vmName ..."
New-AzVm -ResourceGroupName $resourceGroupName -Name $vmName -Location $location `
    -VirtualNetworkName $virtualNetworkName -SubnetName $subnetName -NetworkInterfaceName $nic.Name `
    -PublicIpAddressName $publicIpAddressName -NetworkSecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName -Image $vmImage -Size $vmSize -Credential (Get-Credential -UserName $vmUser -Message "Enter password (won't be used, SSH key auth)")

Write-Host "VM creation script finished."
