param(
    [guid] [Parameter(Mandatory = $true)] $SubscriptionId,
    [string] [Parameter(Mandatory = $true)] $Location,
    [string] [Parameter(Mandatory = $false)] $WindowsOSVersion = "Windows2022",
    [string] [Parameter(Mandatory = $false)] $WindowsVMSize = "Standard_D2s_v3",
    [string] [Parameter(Mandatory = $false)]
             [ValidateSet("node-image", "none", "patch", "rapid", "stable")] $AKSAutoUpgradeChannel = "none",
    [string]    [Parameter(Mandatory = $false)] $AKSVersion = "1.26.3",
    
    [int]    [Parameter(Mandatory = $false)] $AKSWindowsNodeCount = 1
)

. $PSScriptRoot\common.ps1

$resourceGroupName = [Environment]::UserName + "scaletest"
$acrName = $resourceGroupName + "acr"
$aksClusterName = $resourceGroupName + "aks"
$keyVaultName = $resourceGroupName + "kv"

# Login using your microsoft accout
Write-Host "Login with your Microsoft account"
az login

# Set subscription
Write-Host "Setting Azure CLI to given Subscription"
az account set --subscription $SubscriptionId

# Required for Windows node pool and could be used to troubleshoot any issues
Write-Host "Creating random password for Host login"
$password = Get-RandomPassword 16 1 1 1 1

$password = $password.ToString()

# Create resource group
Write-Host "Creating Azure Resource Group"
az group create --name $resourceGroupName --location $Location

# Create Azure Container Registery
Write-Host "Creating Azure Container Registery"
az acr create --resource-group $resourceGroupName --name $acrName --sku Standard

# Create an AKS cluster with a Linux node pool
Write-Host "Creating AKS Cluster with System node pool"
az aks create `
    --resource-group $resourceGroupName `
    --name $aksClusterName `
    --network-plugin azure `
    --node-vm-size Standard_D2s_v3 `
    --attach-acr $acrName `
    --auto-upgrade-channel $AKSAutoUpgradeChannel `
    --kubernetes-version $AKSVersion `
    --enable-managed-identity `
    --enable-addons monitoring `
    --generate-ssh-keys `
    --node-count 1 `
    --windows-admin-username azuureadmin `
    --windows-admin-password $password

# Create a Windows node pool for Text Log scale test
Write-Host "Creating Windows Node Pool for Text Log scale test"
az aks nodepool add `
    --resource-group $resourceGroupName `
    --cluster-name $aksClusterName `
    --os-type Windows `
    --os-sku $WindowsOSVersion `
    --name  txtlog `
    --node-vm-size $WindowsVMSize `
    --node-count $AKSWindowsNodeCount

# Create a Windows node pool for ETW Log scale test"
Write-Host "Creating Windows Node Pool for ETW Log scale test"
az aks nodepool add `
    --resource-group $resourceGroupName `
    --cluster-name $aksClusterName `
    --os-type Windows `
    --os-sku $WindowsOSVersion `
    --name  etwlog `
    --node-vm-size $WindowsVMSize `
    --node-count $AKSWindowsNodeCount

# Create a Windows node pool for Event Log scale test
Write-Host "Creating Windows Node Pool for Event Log scale test"
az aks nodepool add `
    --resource-group $resourceGroupName `
    --cluster-name $aksClusterName `
    --os-type Windows `
    --os-sku $WindowsOSVersion `
    --name  evtlog `
    --node-vm-size $WindowsVMSize `
    --node-count $AKSWindowsNodeCount

# Create a Windows node pool for Crash Dump scale test
Write-Host "Creating Windows Node Pool for Crash Dump scale test"
az aks nodepool add `
    --resource-group $resourceGroupName `
    --cluster-name $aksClusterName `
    --os-type Windows `
    --os-sku $WindowsOSVersion `
    --name  crashd `
    --node-vm-size $WindowsVMSize `
    --node-count $AKSWindowsNodeCount

# Create a Key Vault
Write-Host "Creating a key vault"
az keyvault create --name $keyVaultName --resource-group $resourceGroupName --location $Location

# Add password to as secret in the key vault
Write-Host "Adding Windows Node Pool passwrod to Key Vault"
az keyvault secret set --vault-name $keyVaultName --name "WindowsScaleTest" --value $password

Write-Host "Windows Host Log Scale Test Infrastructure deployed"