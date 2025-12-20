    $location = "centralus"
    $resourceGroupName = "mate-azure-task-9"
    $networkSecurityGroupName = "defaultnsg"
    $virtualNetworkName = "vnet"
    $subnetName = "default"
    $vnetAddressPrefix = "10.0.0.0/16"
    $subnetAddressPrefix = "10.0.0.0/24"
    $publicIpAddressName = "linuxboxpip"
    $sshKeyName = "linuxboxsshkey"
    $sshKeyPublicKey = Get-Content "$HOME/.ssh/id_ed25519.pub"
    $vmName = "matebox"
    $vmImage = "Ubuntu2204"
    $vmSize = "Standard_DC1ds_v3"

    Write-Host "Creating a resource group $resourceGroupName ..."
    New-AzResourceGroup -Name $resourceGroupName -Location $location

    Write-Host "Creating a network security group $networkSecurityGroupName ..."
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
    $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
    New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

    # ↓↓↓ Write your code here ↓↓↓

$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetAddressPrefix

$vnet = New-AzVirtualNetwork `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $virtualNetworkName `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnetConfig

$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet

Write-Host "Creating public IP address $publicIpAddressName ..."
$publicIp = New-AzPublicIpAddress `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $publicIpAddressName `
    -AllocationMethod Static `
    -Sku Standard `
    -DomainNameLabel "matebox-$(Get-Random -Maximum 99999)"

Write-Host "Creating SSH key $sshKeyName ..."
$sshKey = New-AzSshKey `
    -ResourceGroupName $resourceGroupName `
    -Name $sshKeyName `
    -PublicKey $sshKeyPublicKey

Write-Host "Creating virtual machine $vmName ..."
$vm = New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $vmName `
    -Size $vmSize `
    -Image $vmImage `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -PublicIpAddressName $publicIpAddressName `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName

if ($vm) {
    Write-Host ""
    Write-Host "VM deployment completed successfully!" -ForegroundColor Green
    Write-Host "VM Name: $vmName"
    Write-Host "Public IP DNS: $($publicIp.DnsSettings.Fqdn)"
    Write-Host ""
    Write-Host "To connect to the VM, use:" -ForegroundColor Yellow
    Write-Host "ssh azureuser@$($publicIp.DnsSettings.Fqdn)" -ForegroundColor Cyan
} else {
    Write-Host "VM deployment failed!" -ForegroundColor Red
}
