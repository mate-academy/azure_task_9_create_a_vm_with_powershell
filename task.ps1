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
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating a virtual network $virtualNetworkName ..."
$subnet = New-AzVirtualNetworkSubnetConfig `
  -Name $subnetName `
  -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork `
  -Name $virtualNetworkName `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -AddressPrefix $vnetAddressPrefix `
  -Subnet $subnet

Write-Host "Creating a public IP address $publicIpAddressName ..."
New-AzPublicIpAddress `
  -Name $publicIpAddressName `
  -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Sku Standard `
  -AllocationMethod Static `
  -DomainNameLabel "matebox-$(Get-Random)"

Write-Host "Creating an SSH key resource $sshKeyName ..."
New-AzSshKey `
  -Name $sshKeyName `
  -ResourceGroupName $resourceGroupName `
  -PublicKey $sshKeyPublicKey

Write-Host "Creating a virtual machine $vmName ..."
New-AzVm `
  -ResourceGroupName $resourceGroupName `
  -Name $vmName `
  -Location $location `
  -Image $vmImage `
  -Size $vmSize `
  -VirtualNetworkName $virtualNetworkName `
  -SubnetName $subnetName `
  -PublicIpAddressName $publicIpAddressName `
  -SecurityGroupName $networkSecurityGroupName `
  -SshKeyName $sshKeyName

Write-Host "Deploying the web application to $vmName ..."
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
$vmUsername = $vm.OsProfile.AdminUsername
$repoUrl = "https://github.com/Anastasiia-Chikrizova/azure_task_9_create_a_vm_with_powershell.git"

$deploymentScript = @"
set -e
sudo mkdir -p /app
sudo chown ${vmUsername}:${vmUsername} /app
rm -rf /tmp/app-repo
git clone --depth 1 $repoUrl /tmp/app-repo
cp -r /tmp/app-repo/app/. /app/
rm -rf /tmp/app-repo
sudo apt-get update
sudo apt-get install -y python3-pip
sudo mv /app/todoapp.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start todoapp
sudo systemctl enable todoapp
systemctl status todoapp --no-pager
"@

Invoke-AzVMRunCommand `
  -ResourceGroupName $resourceGroupName `
  -VMName $vmName `
  -CommandId "RunShellScript" `
  -ScriptString $deploymentScript
