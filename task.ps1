$location = "denmarkeast"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPath = "~/.ssh/id_ed25519_azure_voleger_mate"
$sshKeyPublicKey = Get-Content "$sshKeyPath.pub"
$vmAdminUser = "azureuser"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓

Write-Host "Creating a virtual network $virtualNetworkName ..."
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet

Write-Host "Creating a public IP address $publicIpAddressName ..."
$dnsLabel = "matebox-$(Get-Random -Maximum 99999)"
New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -Sku Standard -AllocationMethod Static -DomainNameLabel $dnsLabel

Write-Host "Creating an SSH key $sshKeyName ..."
New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -PublicKey $sshKeyPublicKey

Write-Host "Creating a VM $vmName ..."
# ponytail: throwaway password, login is by SSH key only
$credential = [pscredential]::new($vmAdminUser,(ConvertTo-SecureString "$(New-Guid)Aa1!" -AsPlainText -Force))
New-AzVm -ResourceGroupName $resourceGroupName -Name $vmName -Location $location -Image $vmImage -Size $vmSize `
    -VirtualNetworkName $virtualNetworkName -SubnetName $subnetName -SecurityGroupName $networkSecurityGroupName `
    -PublicIpAddressName $publicIpAddressName -SshKeyName $sshKeyName -Credential $credential

Write-Host "Deploying the web application ..."
$fqdn = (Get-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName).DnsSettings.Fqdn
$sshTarget = "$vmAdminUser@$fqdn"
$sshOptions = "-i", $sshKeyPath, "-o", "StrictHostKeyChecking=accept-new"

ssh @sshOptions $sshTarget "sudo mkdir -p /app && sudo chown ${vmAdminUser}:${vmAdminUser} /app"
scp @sshOptions -r app/. "${sshTarget}:/app"
ssh @sshOptions $sshTarget "sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip && chmod +x /app/start.sh && sudo mv /app/todoapp.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl start todoapp && sudo systemctl enable todoapp"
ssh @sshOptions $sshTarget "systemctl status todoapp --no-pager"

Write-Host "Web app: http://${fqdn}:8080/"
