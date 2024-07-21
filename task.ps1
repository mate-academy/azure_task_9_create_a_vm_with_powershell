$location = "uksouth"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKey = Get-Content "~/.ssh/id_rsa.pub"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_B1s"

Write-Host "Creating a resource group $resourceGroupName ..."
New-AzResourceGroup -Name $resourceGroupName -Location $location

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

# ↓↓↓ Write your code here ↓↓↓
<#
  Read First:
  1)  to see documentation for the commands below use:
      Get-Help $Your_CmdLet -Full
  2)  to see available values for specific parameters below use:
      Get-Help $Your_CmdLet -Parameter $Your_Parameter
  3)  Set preferred settings below:
#>
# public Ip values:
$publicIpDnsprefix =        "task-9"
$publicIpSku =              "Basic"
$publicIpAllocation =       "Dynamic"

# Network Interface values:
$nicName =                  "NetInterface"
$ipConfigName =             "ipConfig1"

# VM values:
$vmSecurityType =           "Standard"

# OS values:
# manually configure Linux / Windows in "Set-AzVMOperatingSystem" section
$osUser =                   "yegor"
$osPublisherName =          "Canonical"
$osOffer =                  "0001-com-ubuntu-server-jammy"
$osSku =                    "22_04-lts-gen2"
$osVersion =                "latest"
$osDiskSizeGB =             64
$osDiskType =               "Premium_LRS"

Write-Host "Creating a virtual network $virtualNetworkName ..."
$networkSecurityGroupObj = Get-AzNetworkSecurityGroup `
  -Name                     $networkSecurityGroupName `
  -ResourceGroupName        $resourceGroupName
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
  -Name                     $subnetName `
  -AddressPrefix            $subnetAddressPrefix `
  -NetworkSecurityGroup     $networkSecurityGroupObj
New-AzVirtualNetwork `
  -Name                     $virtualNetworkName `
  -ResourceGroupName        $resourceGroupName `
  -Location                 $location `
  -AddressPrefix            $vnetAddressPrefix `
  -Subnet                   $subnetConfig
$vnetObj = Get-AzVirtualNetwork `
  -Name                     $virtualNetworkName `
  -ResourceGroupName        $resourceGroupName
$subnetId = $vnetObj.Subnets[0].Id

Write-Host "Creating a Public IP $publicIpAddressName ..."
New-AzPublicIpAddress `
  -Name                     $publicIpAddressName `
  -ResourceGroupName        $resourceGroupName `
  -Location                 $location `
  -Sku                      $publicIpSku `
  -AllocationMethod         $publicIpAllocation `
  -DomainNameLabel          $publicIpDnsprefix
$publicIpObj = Get-AzPublicIpAddress `
  -Name                     $publicIpAddressName `
  -ResourceGroupName        $resourceGroupName

Write-Host "Creating a Network Interface Configuration $nicName ..."
$ipConfig = New-AzNetworkInterfaceIpConfig `
  -Name                     $ipConfigName `
  -SubnetId                 $subnetId `
  -PublicIpAddressId        $publicIpObj.Id
New-AzNetworkInterface -Force `
  -Name                     $nicName `
  -ResourceGroupName        $resourceGroupName `
  -Location                 $location `
  -IpConfiguration          $ipConfig
$nicObj = Get-AzNetworkInterface `
  -Name                     $nicName `
  -ResourceGroupName        $resourceGroupName

Write-Host "Creating an SSH key resource $sshKeyName ..."
New-AzSshKey `
  -Name                     $sshKeyName `
  -ResourceGroupName        $resourceGroupName `
  -PublicKey                $sshKeyPublicKey

Write-Host "Creating Storage Account for boot diagnostic ..."
$bootStorageAccName =       "bootdiagnosstorageacc"
New-AzStorageAccount `
  -ResourceGroupName        $resourceGroupName `
  -Name                     $bootStorageAccName `
  -Location                 $location `
  -SkuName                  "Standard_LRS" `
  -Kind                     "StorageV2" `
  -AccessTier               "Hot" `
  -MinimumTlsVersion        "TLS1_0"


Write-Host "Creating a Virtual Machine ..."
$disabledPassword = ConvertTo-SecureString `
  "P@ssw0rd1234" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential `
  ($osUser, $disabledPassword)
$vmconfig = New-AzVMConfig `
  -VMName                   $vmName `
  -VMSize                   $vmSize `
  -SecurityType             $vmSecurityType
$vmconfig = Set-AzVMSourceImage `
  -VM                       $vmconfig `
  -PublisherName            $osPublisherName `
  -Offer                    $osOffer `
  -Skus                     $osSku `
  -Version                  $osVersion
$vmconfig = Set-AzVMOSDisk `
  -VM                       $vmconfig `
  -Name                     "${vmName}_OSDisk" `
  -CreateOption             FromImage `
  -DeleteOption             Delete `
  -DiskSizeInGB             $osDiskSizeGB `
  -Caching                  ReadWrite `
  -StorageAccountType       $osDiskType
$vmconfig = Set-AzVMOperatingSystem `
  -VM                       $vmconfig `
  -ComputerName             $vmName `
  -Linux                    `
  -Credential               $cred `
  -DisablePasswordAuthentication
$vmconfig = Add-AzVMNetworkInterface `
  -VM                       $vmconfig `
  -Id                       $nicObj.Id
$vmconfig = Set-AzVMBootDiagnostic `
  -VM                       $vmconfig `
  -Enable                   `
  -ResourceGroupName        $resourceGroupName `
  -StorageAccountName       $bootStorageAccName
New-AzVM `
  -ResourceGroupName        $resourceGroupName `
  -Location                 $location `
  -VM                       $vmconfig `
  -SshKeyName               $sshKeyName
