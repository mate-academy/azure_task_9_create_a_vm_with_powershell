$location = "switzerlandnorth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ats_v2"

# 1. Створюємо чистий ключ без пароля прямо з PowerShell
$localKeyPath = "$HOME\.ssh\matebox_key"
if (-not (Test-Path "$localKeyPath.pub")) {
    Write-Host "Generating fresh SSH key without password..."
    ssh-keygen -t rsa -b 2048 -f $localKeyPath -N '""'
}
$sshKeyPublicKey = Get-Content "$localKeyPath.pub" -Raw

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP -Force

Write-Host "Creating a virtual network and subnet..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name $virtualNetworkName -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig -Force

Write-Host "Creating a public IP address (Standard SKU)..."
$dnsLabel = "matebox-todo-$((Get-Random -Minimum 1000 -Maximum 99999))"
$pip = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Location $location -Name $publicIpAddressName -AllocationMethod Static -DomainNameLabel $dnsLabel -Sku Standard -Force

Write-Host "Creating an SSH Key resource in Azure..."
New-AzSshKey -ResourceGroupName $resourceGroupName -Location $location -Name $sshKeyName -PublicKey $sshKeyPublicKey

Write-Host "Creating the Virtual Machine..."
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", (ConvertTo-SecureString "IgnoreThisPassword123!" -AsPlainText -Force))

New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -SecurityGroupName $networkSecurityGroupName `
    -PublicIpAddressName $publicIpAddressName `
    -SshKeyName $sshKeyName `
    -Credential $cred `
    -Image $vmImage `
    -Size $vmSize

Write-Host "=========================================="
Write-Host "Done! Your VM DNS is: $($pip.DnsSettings.Fqdn)"
Write-Host "=========================================="