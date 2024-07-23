# Create a Virtual Machine with PowerShell

Now, when you feel the power of PowerShell, you know that you can do basically anything with it in Azure, even create a VM! Having such a script would be very helpful because you are expecting your application to become even more popular, which means that you will need to deploy a lot of new VMs. 

In this task, you will implement a PowerShell script, which deploys an Azure Virtual Machine to your subscription. 

## Prerequisites

Before completing any task in the module, make sure that you followed all the steps described in the **Environment Setup** topic, in particular: 

1. Ensure you have an [Azure](https://azure.microsoft.com/en-us/free/) account and subscription.

2. Create a resource group called *"mate-resources"* in the Azure subscription.

3. In the *"mate-resources"* resource group, create a storage account (any name) and a `task-artifacts` container.

4. Install [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.4) on your computer. All tasks in this module use PowerShell 7. To run it in the terminal, execute the following command: 
    ```
    pwsh
    ```

5. Install [Azure module for PowerShell 7](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell?view=azps-11.3.0): 
    ```
    Install-Module -Name Az -Repository PSGallery -Force
    ```
If you are a Windows user, before running this command, please also run the following: 
    ```
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```

6. Log in to your Azure account using PowerShell:
    ```
    Connect-AzAccount -TenantId <your Microsoft Entra ID tenant id>
    ```

## Requirements

In this task, you will need to write and run a PowerShell script, which deploys a Virtual Machine and all required resources to Azure subscription: 

1. Write your script code to the file `task.ps1` in this repository:
    
    - In the script, you should assume that you are already logged in to Azure and using the correct subscription (don't use commands `Connect-AzAccount` and `Set-AzContext`, if needed - just run them on your computer before running the script). 

    - Use any region you want, for example `uksouth`. 

    - Script already has code, which uses commandlet [New-AzResourceGroup](https://learn.microsoft.com/en-us/powershell/module/az.resources/new-azresourcegroup?view=azps-11.5.0) to create a resource group `mate-azure-task-9`. Please make sure that all your resources are deployed to that resource group. 

    - The script already has code that uses the commandlet [New-AzNetworkSecurityGroup](https://learn.microsoft.com/en-us/powershell/module/az.network/new-aznetworksecuritygroup?view=azps-11.5.0) to create a network security group called `defaultnsg`. Please make sure that the VM has that network security group assigned to it.  

    - Use comandlet [New-AzVirtualNetwork](https://learn.microsoft.com/en-us/powershell/module/az.network/new-azvirtualnetwork?view=azps-11.5.0#example-1-create-a-virtual-network-with-two-subnets) to deploy a virtual network, called `vnet` and a subnet, called `default`. 

    - Use comandlet [New-AzPublicIpAddress](https://learn.microsoft.com/en-us/powershell/module/az.network/new-azpublicipaddress?view=azps-11.5.0) to create a public IP address, called `linuxboxpip` with a DNS label.

    - Use comandlet [New-AzSshKey](https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azsshkey?view=azps-11.5.0) to create an [SSH key resource](https://learn.microsoft.com/en-us/azure/virtual-machines/ssh-keys-portal), called `linuxboxsshkey`. It is recommended (but not required) to upload your existing public SSH key to that SSH key resource (for that, you can use comandlet Get-Content to load the content of your public SSH key to the variable, and then use that variable to set the parameter `-PublicKey` of the `-New-AzSshKey`).  

    - Use comandlet [New-AzVm](https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-11.5.0) to [create a linux virtual machine](https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-powershell#create-a-virtual-machine), called `matebox`.
    
    - VM should be deployed to the `default` subnet of the virtual network `vnet`, use public IP `linuxboxpip`, network security group `defaultnsg`, and ssh key `linuxboxsshkey` (check the documentation of [New-AzVm](https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-11.5.0) — it allows you to specify names of those resources as comandlet parameters). 

    - VM should use an image with the friendly name `Ubuntu2204` and size `Standard_B1s`.

2. When the script is ready, run it to deploy resources to your subscription. 

3. Deploy the web application to the virtual machine
    
    1. Connect to the VM using SSH, create a folder `/app`, and configure your user as an owned of the folder: 
        ```
            ssh <your-vm-username>@<your-public-ip-DNS-name>
            sudo mkdir /app 
            sudo chown <your-vm-username>:<your-vm-username> /app
        ```

    2. Form your computer, copy the content of the folder `app` to your virtual machine (run the command in the folder of this repository): 
        
        ```
            scp -r app/* <your-vm-username>@<your-public-ip-DNS-name>:/app
        ```

    3. Connect to the virtual machine again using SSH, install pre-requirements, and configure a service for the application
        
        ```
            sudo apt update
            sudo apt install python3-pip
            cd /app
            sudo mv todoapp.service /etc/systemd/system/
            sudo chmod +x start.sh
            sudo systemctl daemon-reload
            sudo systemctl start todoapp
            sudo systemctl enable todoapp
        ```
    
    4. Verify that the web app service is running; for that, run the following command on the VM: 
        
        ```
            systemctl status todoapp
        ```
 4. When the solution is validated, delete all resources you deployed with the script; they won't be used in the next tasks.  
## How To Complete Tasks in This Module 

Tasks in this module are relying on 2 PowerShell scripts: 

- `scripts/generate-artifacts.ps1` generates the task  “artifacts” and uploads them to cloud storage. An  “artifact” is evidence of a task completed by you. Each task will have its own script, which will gather the required artifacts. The script also adds a link to the generated artifact in the `artifacts.json` file in this repository — make sure to commit changes to this file after you run the script. 
- `scripts/validate-artifacts.ps1` validates the artifacts generated by the first script. It loads information about the task artifacts from the `artifacts.json` file.

Here is how to complete tasks in this module:

1. Clone task repository

2. Make sure you completed the steps described in the **Prerequisites** section

3. Complete the task described in the **Requirements** section 

4. Run `scripts/generate-artifacts.ps1` to generate task artifacts. The script will update the file `artifacts.json` in this repo. 

5. Run `scripts/validate-artifacts.ps1` to test yourself. If tests are failing — follow the recommendation from the test script error message to fix or re-deploy your infrastructure. When you are ready to test yourself again — **re-generate the artifacts** (step 4) and re-run tests again. 

6. Make sure that changes to both `task.ps1` and `result.json` are committed to the repo, and submit the solution for review.

Pro tip: If you are stuck with any of the implementation steps, run `scripts/generate-artifacts.ps1` and `scripts/validate-artifacts.ps1`. The validation script might give you a hint on what to do.  

7. When the solution is validated, delete all resources you deployed with the script; they won't be used in the next tasks.  
