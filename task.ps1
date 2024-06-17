$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "C:\Users\admin\.ssh\id_rsa.pub" -Raw
$vmName = "matebox"
$vmImage = "Canonical:UbuntuServer:22.04-LTS:latest"
$vmSize = "Standard_B1s"
$dnsPrefix = "matebox"
$adminUsername = "azureuser"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "Creating a virtual network $virtualNetworkName ..."
$defaultSubnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
$vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $defaultSubnet

Write-Host "Creating a public IP address $publicIpAddressName ..."
$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -AllocationMethod Static -DomainNameLabel $dnsPrefix -Location $location

Write-Host "Creating an SSH key resource $sshKeyName ..."
New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -PublicKey $sshKeyPublicKey

Write-Host "Creating a network interface ..."
$nic = New-AzNetworkInterface -Name "${vmName}-nic" -ResourceGroupName $resourceGroupName -Location $location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

Write-Host "Creating a virtual machine $vmName ..."
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize

$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName -Credential (New-Object System.Management.Automation.PSCredential($adminUsername, (ConvertTo-SecureString "DummyPassword123!" -AsPlainText -Force))) -DisablePasswordAuthentication

$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest"

$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

$sshConfig = New-Object -TypeName Microsoft.Azure.Management.Compute.Models.SshConfiguration
$sshPublicKey = New-Object -TypeName Microsoft.Azure.Management.Compute.Models.SshPublicKey -Property @{
    Path = "/home/$adminUsername/.ssh/authorized_keys"
    KeyData = $sshKeyPublicKey
}
$sshConfig.PublicKeys = [System.Collections.Generic.List[Microsoft.Azure.Management.Compute.Models.SshPublicKey]]@($sshPublicKey)

$linuxConfig = New-Object -TypeName Microsoft.Azure.Management.Compute.Models.LinuxConfiguration -Property @{
    DisablePasswordAuthentication = $true
    Ssh = $sshConfig
}

$vmConfig.OSProfile.LinuxConfiguration = $linuxConfig

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig

Write-Host "Deployment complete."

