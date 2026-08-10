$location = "denmarkeast"
$resourceGroupName = "mate-azure-task-9"

$networkSecurityGroupName = "defaultnsg"

$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"

$publicIpAddressName = "linuxboxpip"
$dnsLabel = "rodops-matebox-task-9"

$sshKeyName = "linuxboxsshkey"
$sshKeyPrivateKey = "~/.ssh/id_ed25519"
$sshKeyPublicKey = Get-Content "~/.ssh/id_ed25519.pub"

$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

$appWorkDir = "/app"
$userName = "azureuser"


# Resource Group
$resourceGroup = Get-AzResourceGroup `
    -Name $resourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $resourceGroup) {

    Write-Host "Creating resource group $resourceGroupName ..."

    New-AzResourceGroup `
        -Name $resourceGroupName `
        -Location $location
}


# Network Security Group
$nsg = Get-AzNetworkSecurityGroup `
    -Name $networkSecurityGroupName `
    -ResourceGroupName $resourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $nsg) {

    Write-Host "Creating NSG $networkSecurityGroupName ..."

    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
        -Name "SSH" `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 1001 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 22 `
        -Access Allow

    $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig `
        -Name "HTTP" `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 1002 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 8080 `
        -Access Allow

    $nsg = New-AzNetworkSecurityGroup `
        -Name $networkSecurityGroupName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -SecurityRules $nsgRuleSSH, $nsgRuleHTTP
}


# Virtual Network + Subnet
$virtualNetwork = Get-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $virtualNetwork) {

    Write-Host "Creating VNet $virtualNetworkName ..."

    $subnetConfig = New-AzVirtualNetworkSubnetConfig `
        -Name $subnetName `
        -AddressPrefix $subnetAddressPrefix

    $virtualNetwork = New-AzVirtualNetwork `
        -Name $virtualNetworkName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -AddressPrefix $vnetAddressPrefix `
        -Subnet $subnetConfig
}


# Public IP
$publicIp = Get-AzPublicIpAddress `
    -Name $publicIpAddressName `
    -ResourceGroupName $resourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $publicIp) {

    Write-Host "Creating Public IP $publicIpAddressName ..."

    $publicIp = New-AzPublicIpAddress `
        -Name $publicIpAddressName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -AllocationMethod Static `
        -Sku Standard `
        -DomainNameLabel $dnsLabel
}


# SSH Key resource
$sshKey = Get-AzSshKey `
    -Name $sshKeyName `
    -ResourceGroupName $resourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $sshKey) {

    Write-Host "Creating SSH key $sshKeyName ..."

    $sshKey = New-AzSshKey `
        -Name $sshKeyName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -PublicKey $sshKeyPublicKey
}


# VM
$vm = Get-AzVM `
    -Name $vmName `
    -ResourceGroupName $resourceGroupName `
    -ErrorAction SilentlyContinue

if (-not $vm) {

    Write-Host "Creating VM $vmName ..."

    New-AzVM `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -Name $vmName `
        -VirtualNetworkName $virtualNetworkName `
        -SubnetName $subnetName `
        -PublicIpAddressName $publicIpAddressName `
        -SecurityGroupName $networkSecurityGroupName `
        -SshKeyName $sshKeyName `
        -Image $vmImage `
        -Size $vmSize `
        -Credential (New-Object PSCredential($userName, (ConvertTo-SecureString "unused" -AsPlainText -Force)))
}


$dnsName = $publicIp.DnsSettings.Fqdn

Write-Host "Preparing $appWorkDir on VM..."
ssh `
    -i $sshKeyPrivateKey `
    -o StrictHostKeyChecking=no `
    "$userName@$dnsName" `
    "sudo mkdir -p $appWorkDir && sudo chown ${userName}:${userName} $appWorkDir "


Write-Host "Copying application..."

scp `
    -i $sshKeyPrivateKey `
    -o StrictHostKeyChecking=no `
    -r app/* `
    "${userName}@${dnsName}:$appWorkDir/"


Write-Host "Installing and starting application..."

ssh `
    -i $sshKeyPrivateKey `
    -o StrictHostKeyChecking=no `
    "$userName@$dnsName" `
    @"
sudo apt-get update &&
sudo apt-get install -y python3-pip &&
sudo chmod +x $appWorkDir/start.sh &&
sudo mv /app/todoapp.service /etc/systemd/system/ &&
sudo systemctl daemon-reload &&
sudo systemctl start todoapp &&
sudo systemctl enable todoapp
"@

Write-Host "Checking application status..."

ssh `
    -i $sshKeyPrivateKey `
    -o StrictHostKeyChecking=no `
    "$userName@$dnsName" `
    "systemctl status todoapp --no-pager"