param(
    [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
    [bool]$DownloadArtifacts=$true
)


# default script values 
$taskName = "task9"

$artifactsConfigPath = "$PWD/artifacts.json"
$resourcesTemplateName = "exported-template.json"
$tempFolderPath = "$PWD/temp"

if ($DownloadArtifacts) { 
    Write-Output "Reading config" 
    $artifactsConfig = Get-Content -Path $artifactsConfigPath | ConvertFrom-Json 

    Write-Output "Checking if temp folder exists"
    if (-not (Test-Path "$tempFolderPath")) { 
        Write-Output "Temp folder does not exist, creating..."
        New-Item -ItemType Directory -Path $tempFolderPath
    }

    Write-Output "Downloading artifacts"

    if (-not $artifactsConfig.resourcesTemplate) { 
        throw "Artifact config value 'resourcesTemplate' is empty! Please make sure that you executed the script 'scripts/generate-artifacts.ps1', and commited your changes"
    } 
    Invoke-WebRequest -Uri $artifactsConfig.resourcesTemplate -OutFile "$tempFolderPath/$resourcesTemplateName" -UseBasicParsing

}

Write-Output "Validating artifacts"
$TemplateFileText = [System.IO.File]::ReadAllText("$tempFolderPath/$resourcesTemplateName")
$TemplateObject = ConvertFrom-Json $TemplateFileText -AsHashtable

$nsg = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Network/networkSecurityGroups")
if ($nsg) {
    if ($nsg.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the Network Security Group resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Network Security Group resource was found in the task resource group. Please make sure that your script creates only one network security group (check if script attaches the NSG you are creating to the subnet) and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Network Security Group resouce. Please re-deploy the VM and try again."
}

$virtualNetwork = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Network/virtualNetworks" )
if ($virtualNetwork ) {
    if ($virtualNetwork.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if virtual network exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one virtual network resource was found in the task resource group. Please make sure that your script deploys only 1 virtual network, and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find virtual network in the task resource group. Please make sure that your script creates a virtual network and try again."
}

$virtualNetworkName = $virtualNetwork.name.Replace("[parameters('virtualNetworks_", "").Replace("_name')]", "")
if ($virtualNetworkName -eq "vnet") { 
    Write-Output "`u{2705} Checked the virtual network name - OK."
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the virtual network name. Please make sure that your script creates a virtual network called 'vnet' and try again."
}

$subnet = $virtualNetwork.properties.subnets
if ($subnet) {
    if ($subnet.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if subnet exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one subnet was found in the virtual network. Please make sure that your script deploys only 1 subnet, and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find subnet in the virtual network. Please make sure that your script creates a subnet and try again."
}

if ($subnet.name -eq "default") { 
    Write-Output "`u{2705} Checked the subnet name - OK."
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the subnet name. Please make sure that your script creates a subnet called 'default' and try again."
}

$pip = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Network/publicIPAddresses")
if ($pip) {
    if ($pip.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the Public IP resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Public IP resource was found in the VM resource group. Please make sure that your script creates only one public IP resource and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Public IP address resouce. Please make sure that your script creates a Public IP resouce (Basic SKU, dynamic IP allocation) and try again."
}

if ($pip.properties.dnsSettings.domainNameLabel) { 
    Write-Output "`u{2705} Checked the Public IP DNS label - OK"
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the Public IP DNS label. Please create the DNS label for your public IP and try again."
}

$pipName = $pip.name.Replace("[parameters('publicIPAddresses_", "").Replace("_name')]", "")
if ($pipName -eq "linuxboxpip") { 
    Write-Output "`u{2705} Checked the Public IP name - OK"
} { 
    Write-Output `u{1F914}
    throw "Unable to verify the Public IP name. Please make sure that your script creates a public IP called 'linuxboxpip' and try again."
}

$sshKey = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Compute/sshPublicKeys")
if ($sshKey) {
    if ($sshKey.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the public SSH key resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one public SSH key resource was found in the VM resource group. Please make sure that your script creates only one public SSH key resource and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find public SSH key resouce. Please make sure that your script creates a public SSH key resouce and try again."
}

$sshKeyName = $sshKey.name.Replace("[parameters('sshPublicKeys_", "").Replace("_name')]", "")
if ($sshKeyName -eq "linuxboxsshkey") { 
    Write-Output "`u{2705} Checked the public ssh key name - OK"
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify the public ssh key name. Please make sure that your script creates a public ssh key called 'linuxboxsshkey' and try again."
}

$virtualMachine = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Compute/virtualMachines" )
if ($virtualMachine) {
    if ($virtualMachine.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if Virtual Machine exists - OK."
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Virtual Machine resource was found in the VM resource group. Please make sure that your script creates only 1 VM and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Virtual Machine in the task resource group. Please make sure that your script creates a virtual machine and try again."
}

$nic = ( $TemplateObject.resources | Where-Object -Property type -EQ "Microsoft.Network/networkInterfaces")
if ($nic) {
    if ($nic.name.Count -eq 1) { 
        Write-Output "`u{2705} Checked if the Network Interface resource exists - OK"
    }  else { 
        Write-Output `u{1F914}
        throw "More than one Network Interface resource was found in the VM resource group. Please delete all un-used Network Interface resources and try again."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to find Network Interface resouce. Please re-deploy the VM and try again."
}

if ($nic.properties.ipConfigurations.Count -eq 1) { 
    if ($nic.properties.ipConfigurations.properties.publicIPAddress -and $nic.properties.ipConfigurations.properties.publicIPAddress.id) {  
        Write-Output "`u{2705} Checked if the Public IP assigned to the VM - OK"
    } else { 
        Write-Output `u{1F914}
        throw "Unable to verify Public IP configuratio for the VM. Please make sure that your script assignes the public IP address to the VM and try agian."
    }
} else {
    Write-Output `u{1F914}
    throw "Unable to verify IP configuration of the Network Interface. Please make sure that your script creates only 1 IP configuration of the VM network interface and try again."
}

if ($virtualMachine.properties.osProfile.linuxConfiguration.ssh.publicKeys.keyData -eq $sshKey.properties.publicKey) { 
    Write-Output "`u{2705} Checked if virtual machine uses the public ssh key 'linuxboxsshkey' - OK"
} else { 
    Write-Output `u{1F914}
    throw "Unable to verify, that VM uses the public ssh key 'linuxboxsshkey'. Please make sure that in New-AzVm comandled, parameter '-SshKeyName' is set to the name of the public SSH key you created earlier, and that you are not setting the parameter '-GenerateSshKey'."
}

if ($virtualMachine.properties.storageProfile.imageReference.publisher -eq "canonical") { 
    Write-Output "`u{2705} Checked Virtual Machine OS image publisher - OK" 
} else { 
    Write-Output `u{1F914}
    throw "Virtual Machine uses OS image from unknown published. Please make sure that your script creates a VM from image with friendly name 'Ubuntu2204' and try again."
}
if ($virtualMachine.properties.storageProfile.imageReference.offer.Contains('ubuntu-server') -and $virtualMachine.properties.storageProfile.imageReference.sku.Contains('22_04')) { 
    Write-Output "`u{2705} Checked Virtual Machine OS image offer - OK"
} else { 
    Write-Output `u{1F914}
    throw "Virtual Machine uses wrong OS image. Please make sure that your script creates a VM from image with friendly name 'Ubuntu2204' and try again." 
}

if ($virtualMachine.properties.hardwareProfile.vmSize -eq "Standard_B1s") { 
    Write-Output "`u{2705} Checked Virtual Machine size - OK"
} else { 
    Write-Output `u{1F914}
    throw "Virtual Machine size is not set to B1s. Please make sure that your script creates a VM with size B1s and try again."
}

$response = (Invoke-WebRequest -Uri "http://$($pip.properties.dnsSettings.fqdn):8080/api/" -ErrorAction SilentlyContinue) 
if ($response) { 
    Write-Output "`u{2705} Checked if the web application is running - OK"
} else {
    throw "Unable to get a reponse from the web app. Please make sure that the VM and web application are running and try again."
}


Write-Output ""
Write-Output "`u{1F973} Congratulations! All tests passed!"