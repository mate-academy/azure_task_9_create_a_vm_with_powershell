$ErrorActionPreference = "Stop"

$location = if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { "westeurope" }
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$sshKeyPublicKeyPath = "~/.ssh/id_rsa.pub"
if (-not (Test-Path $sshKeyPublicKeyPath)) {
    $sshKeyPublicKeyPath = "~/.ssh/id_ed25519.pub"
}
if (-not (Test-Path $sshKeyPublicKeyPath)) {
    throw "Unable to find a public SSH key at '~/.ssh/id_rsa.pub' or '~/.ssh/id_ed25519.pub'. Please create an SSH key pair and try again."
}
$sshKeyPublicKey = (Get-Content $sshKeyPublicKeyPath -Raw).Trim()
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = if ($env:AZURE_VM_SIZE) { $env:AZURE_VM_SIZE } else { "Standard_B1s" }
$vmAdminUsername = "azureuser"

function Wait-ForResource {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$Probe,
        [int]$TimeoutSeconds = 120,
        [int]$DelaySeconds = 5,
        [string]$Description = "resource"
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $result = & $Probe
            if ($result) { return $result }
        } catch {
            # ignore transient ARM propagation errors
        }
        Start-Sleep -Seconds $DelaySeconds
    }
    throw "Timed out waiting for $Description to become available."
}

Write-Host "Creating a resource group $resourceGroupName ..."
$existingRg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if ($existingRg) {
    if ($existingRg.Location -ne $location) {
        throw "Resource group '$resourceGroupName' already exists in location '$($existingRg.Location)'. Delete it first or set AZURE_LOCATION='$($existingRg.Location)'."
    }
} else {
    New-AzResourceGroup -Name $resourceGroupName -Location $location -ErrorAction Stop | Out-Null
}

Write-Host "Creating a network security group $networkSecurityGroupName ..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH  -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow;
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP  -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow;
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP -ErrorAction Stop

# ↓↓↓ Write your code here ↓↓↓

Write-Host "Creating a virtual network $virtualNetworkName and subnet $subnetName ..."
$null = Wait-ForResource -Description "NSG '$networkSecurityGroupName'" -Probe { Get-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -ErrorAction Stop }
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix -NetworkSecurityGroup $nsg
$vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig -ErrorAction Stop

Write-Host "Creating a public IP $publicIpAddressName with DNS label ..."
$dnsLabel = ("matebox-" + (Get-Random -Maximum 999999)).ToLowerInvariant()
try {
    New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -Sku Basic -AllocationMethod Dynamic -DomainNameLabel $dnsLabel -ErrorAction Stop | Out-Null
} catch {
    $message = "$($_.Exception.Message)"
    if ($message -match "IPv4BasicSkuPublicIpCountLimitReached" -or $message -match "Basic SKU public IP") {
        Write-Host "Basic Public IP is not allowed in '$location' for this subscription. Falling back to Standard SKU (Static) ..."
        New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -Sku Standard -AllocationMethod Static -DomainNameLabel $dnsLabel -ErrorAction Stop | Out-Null
    } else {
        throw
    }
}

Write-Host "Creating an SSH key resource $sshKeyName ..."
New-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -Location $location -PublicKey $sshKeyPublicKey -ErrorAction Stop | Out-Null
$null = Wait-ForResource -Description "Public IP '$publicIpAddressName'" -Probe { Get-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -ErrorAction Stop }
$null = Wait-ForResource -Description "SSH key '$sshKeyName'" -Probe { Get-AzSshKey -Name $sshKeyName -ResourceGroupName $resourceGroupName -ErrorAction Stop }

Write-Host "Creating a virtual machine $vmName ..."
if ($vmSize -ne "Standard_B1s") {
    Write-Warning "VM size is set to '$vmSize' (expected by course validator: 'Standard_B1s'). Use this only if 'Standard_B1s' cannot be deployed due to subscription capacity/region restrictions."
}
$securePassword = ConvertTo-SecureString -String ([Guid]::NewGuid().ToString() + "aA1!") -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($vmAdminUsername, $securePassword)

$vmParams = @{
    ResourceGroupName      = $resourceGroupName
    Location               = $location
    Name                   = $vmName
    Image                  = $vmImage
    Size                   = $vmSize
    VirtualNetworkName     = $virtualNetworkName
    SubnetName             = $subnetName
    PublicIpAddressName    = $publicIpAddressName
    SecurityGroupName      = $networkSecurityGroupName
    SshKeyName             = $sshKeyName
    Credential             = $credential
}

$newAzVmCommand = Get-Command New-AzVm -ErrorAction Stop
if ($newAzVmCommand.Parameters.ContainsKey("DisablePasswordAuthentication")) {
    $vmParams.DisablePasswordAuthentication = $true
}

try {
    New-AzVm @vmParams -ErrorAction Stop | Out-Null
} catch {
    # ARM propagation can be eventual; one retry helps for transient "not found" of dependent resources.
    Start-Sleep -Seconds 10
    New-AzVm @vmParams -ErrorAction Stop | Out-Null
}

Write-Host "Done. VM username: $vmAdminUsername. Public DNS label: $dnsLabel"
