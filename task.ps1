$location = "polandcentral"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshUserName = "azureuser"
$sshPublicKey = Get-Content "~/.ssh/id_rsa.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B2ats_v2"

try{
    Write-Host "Creating '$resourceGroupName' resource group ..."
    New-AzResourceGroup `
        -Name $resourceGroupName `
        -Location $location
}catch{
    Write-Error "Failed creating '$resourceGroupName' resource group."
}

try{
    Write-Host "Creating '$networkSecurityGroupName' network security group ..."
    $nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
        -Name SSH `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 1001 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 22 `
        -Access Allow;

    $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig `
        -Name HTTP `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 1002 `
        -SourceAddressPrefix * `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 8080 `
        -Access Allow;

    $networkSecurityGroup = New-AzNetworkSecurityGroup `
        -Name $networkSecurityGroupName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -SecurityRules $nsgRuleSSH, $nsgRuleHTTP
}catch{
    Write-Error "Failed creating '$networkSecurityGroupName' network security group."
}

try{
    Write-Host "Deploying '$virtualNetworkName' virtual network and '$subnetName' subnet ..."
    $defaultSubnet = New-AzVirtualNetworkSubnetConfig `
        -Name $subnetName `
        -AddressPrefix $subnetAddressPrefix `
        -NetworkSecurityGroup $networkSecurityGroup

    New-AzVirtualNetwork `
        -Name $virtualNetworkName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -AddressPrefix $vnetAddressPrefix `
        -Subnet $defaultSubnet `
}catch{
     Write-Error "Failed deploying '$virtualNetworkName' virtual network and '$subnetName' subnet."
}

try{
    Write-Host "Creating '$publicIpAddressName' public IP address with '$dnsLabel' DNS label ..."
    $dnsLabel = "$vmName-$([guid]::NewGuid().ToString().Substring(0,8))"
    $publicIp = New-AzPublicIpAddress `
        -Name $publicIpAddressName `
        -ResourceGroupName $resourceGroupName `
        -AllocationMethod Static `
        -DomainNameLabel $dnsLabel `
        -Location $location `
        -Sku Standard
}catch{
    Write-Error "Failed creating '$publicIpAddressName' public IP address with '$dnsLabel' DNS label."
}

try{
    Write-Host "Creating a SSH Public Key '$sshKeyName' name ..."
    $sshKey = New-AzSshKey `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -Name $sshKeyName `
        -PublicKey $sshPublicKey
}catch{
    Write-Error "Failed creating a SSH Public Key '$sshKeyName' name."
}

try{
    Write-Host "Creating a Linux VM '$vmName' name ..."
    $securePassword = ConvertTo-SecureString `
        "OctoberFest2026!" `
        -AsPlainText `
        -Force

    $credential = New-Object `
        System.Management.Automation.PSCredential `
        ($sshUserName, $securePassword)

    New-AzVM `
        -Name $vmName `
        -ResourceGroupName $resourceGroupName `
        -Location $location `
        -Credential $credential `
        -VirtualNetworkName $virtualNetworkName `
        -SubnetName $subnetName `
        -PublicIpAddressName $publicIpAddressName `
        -SecurityGroupName $networkSecurityGroupName `
        -Image $vmImage `
        -Size $vmSize `
        -SshKeyName $sshKeyName
}catch{
    Write-Error "Failed creating a Linux VM '$vmName' name."
}

Write-Host "VM '$vmName' name successfully created."
Write-Host "VM Name:        $vmName"
Write-Host "VM Size:        $vmSize"
Write-Host "VM Image Name:  $vmImage"
Write-Host "Public IP:      $($publicIp.IpAddress)"
Write-Host "DNS Name:       $($publicIp.DnsSettings.Fqdn)"
Write-Host "Resource Group: $resourceGroupName"
Write-Host "Location:       $location"
Write-Host "SSH User Name:  $sshUserName"

# When VM deployed, execute those steps:
ssh azureuser@matebox-e2846cc5.polandcentral.cloudapp.azure.com
sudo mkdir /app
sudo chown azureuser:azureuser /app
scp -r app/* azureuser@matebox-e2846cc5.polandcentral.cloudapp.azure.com:/app

sudo apt-get update
sudo apt-get install python3-pip
cd /app
sudo mv todoapp.service /etc/systemd/system/
sudo chmod +x /app/start.sh
sudo systemctl daemon-reload
sudo systemctl start todoapp
sudo systemctl enable todoapp

# Make sure, application is working:
http://matebox-e2846cc5.polandcentral.cloudapp.azure.com:8080/