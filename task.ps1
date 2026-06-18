$location = "ukwest"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIfVhFZjYAhjVr+8an2+m98NzofTYHwe0M9rtezqgEAZ1qVHhJisVJXaS3u3Yq0O9/PK4fm/rA7qsL3A3OXOwE4Cihwvt340wbXC96NbcitJfykYDF8qrcYxzklXG/dvbZgPPyO0mwMHnlMKae8TqswEdmQ8l4cMFH1OQDkhwGI5PtCAFTDohqQoNZ3I4OLarD78O6lhX97DEBnQchPqp3IJwionPCIhM0kPsTj0dT43uJ4zAa6kMuTztDGknJlkREqtf11+g0UMiwsN1xS6Cp3u7jTid6Wn2RUNOgRfXhPDaTvlw3YVVQPTfgslD0CbSlxPTqfM/KVMtx6Vr1IJljXCsnUlrhPETkfQ/9IHGFzG+S7tdI7j482ANHltvH7+y0xMxR3zjm30SLAi03VVvMkvq8Gqqrlr4mfkRccx0vAamsMxlnjBtQDp/n42ihpJG6LlzeQg2kEMKVGA8kgdpfgaxdrY3KE91YzGRBPbl51Jp22EziL4q1BO3z5oqWdw0= generated-by-azure"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_D2s_v3"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓
$subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup (Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName)
New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet
$dnsLabel = "mateboxdnslabel"
New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -AllocationMethod Static -DomainNameLabel $dnsLabel -Location $location
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey -Location $location

New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -Image $vmImage `
    -Size $vmSize `
    -SubnetName $subnetName `
    -SecurityGroupName $networkSecurityGroupName `
    -PublicIpAddressName $publicIpAddressName `
    -VirtualNetworkName $virtualNetworkName `
    -SshKeyName $sshKeyName