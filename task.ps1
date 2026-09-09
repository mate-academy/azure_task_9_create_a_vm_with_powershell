$location = "polandcentral"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"

# Перевірка та автоматичне створення SSH-ключа за потреби
$sshKeyPath = "$HOME/.ssh/id_rsa.pub"
if (-not (Test-Path $sshKeyPath)) {
    if (Test-Path "$HOME/.ssh/id_ed25519.pub") {
        $sshKeyPath = "$HOME/.ssh/id_ed25519.pub"
    } else {
        Write-Host "Створення нового SSH-ключа $sshKeyPath ..."
        New-Item -ItemType Directory -Path "$HOME/.ssh" -Force | Out-Null
        ssh-keygen -t rsa -b 2048 -f "$HOME/.ssh/id_rsa" -N '""'
    }
}
$sshKeyPublicKey = Get-Content $sshKeyPath -Raw

$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"
#$vmSize = "Standard_B2s_v2"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓

Write-Host "Creating virtual network $virtualNetworkName and subnet $subnetName ..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig

Write-Host "Creating public IP address $publicIpAddressName ..."
$dnsLabel = "mateboxdns$((Get-Random -Minimum 100000 -Maximum 999999))"
New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -Sku Standard -DomainNameLabel $dnsLabel

Write-Host "Creating SSH Key resource $sshKeyName ..."
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey -Location $location

Write-Host "Creating Virtual Machine $vmName ..."
$secPassword = ConvertTo-SecureString "P@ssw0rd123456!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $secPassword)

New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $vmName `
    -Size $vmSize `
    -Image $vmImage `
    -Credential $cred `
    -VirtualNetworkName $virtualNetworkName `
    -SubnetName $subnetName `
    -PublicIpAddressName $publicIpAddressName `
    -SecurityGroupName $networkSecurityGroupName `
    -SshKeyName $sshKeyName
