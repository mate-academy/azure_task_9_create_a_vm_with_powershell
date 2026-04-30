$resourceGroup = "mate-azure-task-9"
$location = "westeurope"
$username = "azureuser"

New-AzResourceGroup -Name $resourceGroup -Location $location

New-AzNetworkSecurityGroup `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -Name "defaultnsg"

$subnet = New-AzVirtualNetworkSubnetConfig `
    -Name "default" `
    -AddressPrefix "10.0.0.0/24"

New-AzVirtualNetwork `
    -Name "vnet" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $subnet

New-AzPublicIpAddress `
    -Name "linuxboxpip" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -AllocationMethod Static `
    -DomainNameLabel "matebox$(Get-Random)"

$sshKey = Get-Content "$HOME\.ssh\id_rsa.pub"

New-AzSshKey `
    -Name "linuxboxsshkey" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -PublicKey $sshKey

$pass = ConvertTo-SecureString "DummyPassword123!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($username, $pass)

New-AzVm `
    -ResourceGroupName $resourceGroup `
    -Name "matebox" `
    -Location $location `
    -VirtualNetworkName "vnet" `
    -SubnetName "default" `
    -SecurityGroupName "defaultnsg" `
    -PublicIpAddressName "linuxboxpip" `
    -SshKeyName "linuxboxsshkey" `
    -ImageName "Ubuntu2204" `
    -Size "Standard_D2s_v3" `
    -Credential $cred `
    -OpenPorts 22 `
    -ErrorAction Stop



