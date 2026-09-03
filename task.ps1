$location = "denmarkeast"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub" 
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg

$vnet = New-AzVirtualNetwork `
 -ResourceGroupName $resourceGroupName `
 -Location $location `
 -Name $virtualNetworkName `
 -AddressPrefix $vnetAddressPrefix `
 -Subnet $subnetConfig 

$dnsLabel = "matebox-" + (Get-Random -Minimum 10000 -Maximum 99999)

$pip = New-AzPublicIpAddress `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name $publicIpAddressName `
  -AllocationMethod Static `
  -Sku Standard `
  -DomainNameLabel $dnsLabel

$sshKey = New-AzSshKey `
  -ResourceGroupName $resourceGroupName `
  -Name $sshKeyName `
  -PublicKey $sshKeyPublicKey

New-AzVm `
  -ResourceGroupName $resourceGroupName `
  -Name $vmName `
  -Location $location `
  -image $vmImage `
  -Size $vmSize `
  -VirtualNetworkName $virtualNetworkName `
  -SubnetName $subnetName `
  -PublicIpAddressName $publicIpAddressName `
  -SecurityGroupName $networkSecurityGroupName `
  -SshKeyName $sshKeyName `
  -GenerateSshKey:$false

$domenName = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName).DnsSettings.Fqdn

ssh -o StrictHostKeyChecking=no azureuser@$domenName "sudo mkdir -p /app; sudo chown azureuser:azureuser /app"

scp -o StrictHostKeyChecking=no -r app/* azureuser@${domenName}:/app

ssh -o StrictHostKeyChecking=no azureuser@$domenName "sudo apt update; sudo apt install -y python3-pip"

ssh -o StrictHostKeyChecking=no azureuser@$domenName "cd /app; sudo mv todoapp.service /etc/systemd/system/; sudo systemctl daemon-reload; sudo systemctl start todoapp; sudo systemctl enable todoapp"

ssh -o StrictHostKeyChecking=no azureuser@$domenName "systemctl status todoapp --no-pager"

Remove-AzResourceGroup -Name $resourceGroupName -Force