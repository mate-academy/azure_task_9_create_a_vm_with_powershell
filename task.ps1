$location = "centralus"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$dnsPrefix = "mateip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "$HOME\.ssh\id_ed25519.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_D2als_v7"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓
$frontendSubnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $frontendSubnet
$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -AllocationMethod Static -DomainNameLabel $dnsPrefix -Location $location
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey

$userName = "nook17"
$securePassword = ConvertTo-SecureString "TempPassword123!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($userName, $securePassword)

New-AzVm -ResourceGroupName $resourceGroupName `
  -Name $vmName `
  -VirtualNetworkName $virtualNetworkName `
  -SubnetName $subnetName `
  -PublicIpAddressName $publicIpAddressName `
  -SecurityGroupName $networkSecurityGroupName `
  -ImageName $vmImage `
  -Size $vmSize `
  -SshKeyName $sshKeyName `
  -Credential $credential

# --SSH command--
# SSH nook17@20.12.206.171
# sudo mkdir /app
# sudo chown nook17:nook17 /app
# scp -r app/* nook17@20.12.206.171:/app
# sudo apt-get update && sudo apt-get upgrade
# sudo apt install python3-pip
# cd /app
# sudo mv todoapp.service /etc/systemd/system/
# sudo systemctl daemon-reload
# sudo systemctl start todoapp
# sudo systemctl enable todoapp