$location = "denmarkeast" # any region that is available in your Azure subscription
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = (Get-Content "$HOME\.ssh\mate_azure_task2.pub" -Raw).Trim()
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
if (-not (Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP
}

# ↓↓↓ Write your code here ↓↓↓
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix

New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet -ErrorAction Stop

$dnsLabel = "matebox-khrystyna3"

New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -Sku Standard -DomainNameLabel $dnsLabel -ErrorAction Stop

$sshKeyPath = "$HOME\.ssh\mate_azure_task2.pub"

if (-not (Get-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue)) {

    if (Test-Path $sshKeyPath) {
        $sshKeyPublicKey = (Get-Content $sshKeyPath -Raw).Trim()

        New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location -PublicKey $sshKeyPublicKey
    }
    else {
        New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location
    }
}

$credential = Get-Credential -UserName "azureuser" -Message "Enter VM credentials"

$vmParams = @{
    ResourceGroupName = $resourceGroupName
    Location = $location
    Name = $vmName
    VirtualNetworkName = $virtualNetworkName
    SubnetName = $subnetName
    PublicIpAddressName = $publicIpAddressName
    SecurityGroupName = $networkSecurityGroupName
    SshKeyName = $sshKeyName
    Image = $vmImage
    Size = $vmSize
    Credential = $credential
}

New-AzVM @vmParams -ErrorAction Stop
