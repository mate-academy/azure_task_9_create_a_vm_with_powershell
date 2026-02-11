$location = "norwayeast"
$vmSize = "Standard_B2ats_v2"
$resourceGroupName = "mate-azure-task-9-norway"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$dnsLabel = "mate-task9-danylopovar-v5"

$sshKeyPublicKey = Get-Content "$HOME/.ssh/id_ed25519.pub"


Write-Host "Creating Resource Group in $location..." -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Write-Host "Creating SSH Key Resource..." -ForegroundColor Cyan
if (Get-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -ErrorAction SilentlyContinue) {
    Write-Host "SSH Key already exists." -ForegroundColor Yellow
} else {
    New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey
}

Write-Host "Creating NSG..." -ForegroundColor Cyan
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP -Force

Write-Host "Creating VNet..." -ForegroundColor Cyan
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.0.0/24" -NetworkSecurityGroup $nsg
New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $virtualNetworkName -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig -Force

Write-Host "Creating Public IP..." -ForegroundColor Cyan
New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -Name $publicIpAddressName -AllocationMethod Static -DomainNameLabel $dnsLabel -Sku Standard -Force

Write-Host "Creating VM ($vmSize)..." -ForegroundColor Cyan

$secPass = ConvertTo-SecureString "M@teAcademy2026!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $secPass)

New-AzVM -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -SecurityGroupName $networkSecurityGroupName `
    -PublicIpAddressName $publicIpAddressName `
    -SshKeyName $sshKeyName `
    -Credential $cred `
    -Image $vmImage `
    -Size $vmSize `
    -OpenPorts 22, 8080

Write-Host "Deployment Completed!" -ForegroundColor Green
Write-Host "Connect command: ssh azureuser@$dnsLabel.$location.cloudapp.azure.com" -ForegroundColor Yellow