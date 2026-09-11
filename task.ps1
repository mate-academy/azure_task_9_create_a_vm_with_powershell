$location = "denmarkeast"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPath = Join-Path $HOME ".ssh/id_rsa.pub"
$sshKeyPublicKey = Get-Content -Path $sshKeyPath -Raw
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
$dnsLabel = "matebox$((Get-Random -Minimum 10000 -Maximum 99999))"
$vmAdminUsername = "azureuser"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓

Write-Host "Creating a virtual network $virtualNetworkName with subnet $subnetName ..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork `
    -Name $virtualNetworkName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $vnetAddressPrefix `
    -Subnet $subnetConfig

Write-Host "Creating a public IP address $publicIpAddressName with DNS label $dnsLabel ..."
# Basic public IP SKU was retired; Standard + Static is required for new deployments.
New-AzPublicIpAddress `
    -Name $publicIpAddressName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Sku Standard `
    -AllocationMethod Static `
    -DomainNameLabel $dnsLabel

Write-Host "Creating an SSH key resource $sshKeyName ..."
New-AzSshKey `
    -ResourceGroupName $resourceGroupName `
    -Name $sshKeyName `
    -PublicKey $sshKeyPublicKey.Trim()

Write-Host "Creating a virtual machine $vmName ..."
$securePassword = ConvertTo-SecureString "UnusedPassw0rd!" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($vmAdminUsername, $securePassword)

New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -Image $vmImage `
    -Size $vmSize `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -SecurityGroupName $networkSecurityGroupName `
    -PublicIpAddressName $publicIpAddressName `
    -Credential $credential `
    -SshKeyName $sshKeyName

Write-Host "Deployment completed. VM admin username: $vmAdminUsername"
$publicIp = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpAddressName
Write-Host "Public IP FQDN: $($publicIp.DnsSettings.Fqdn)"
