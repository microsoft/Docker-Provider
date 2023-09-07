param(
    [guid] [Parameter(Mandatory = $true)] $SubscriptionId,
    [string] [Parameter(Mandatory = $true)] $Location,
    [string] [Parameter(Mandatory = $false)] $ResourceGroupName = [Environment]::UserName + "scaletest",
    [string] [Parameter(Mandatory = $false)] $AKSClusterName = $ResourceGroupName + "aks",
    [string] [Parameter(Mandatory = $false)]
             [ValidateSet("node-image", "none", "patch", "rapid", "stable")] $AKSAutoUpgradeChannel = "stable",
    [int]    [Parameter(Mandatory = $false)] $AKSVersion = 1.26.3,
    [int]    [Parameter(Mandatory = $false)] $AKSWindowsNodeCount = 5,
    [string] [Parameter(Mandatory = $false)] $KeyVaultName = $ResourceGroupName + "-kv"
)

function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length
    )
    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789{]+-[*=@:)}$^%;(_!&amp;#?>/|.'.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
 
    $rng.GetBytes($bytes)
 
    $result = New-Object char[]($length)
 
    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i]%$charSet.Length]
    }
 
    return (-join $result).ToString()
}

# Login using your microsoft accout
Write-Host "Login with your Microsoft account"
az login

# Set subscription
Write-Host "Set az account to given Subscription"
az account set --subscription $SubscriptionId

# Required for Windows node pool and could be used to troubleshoot any issues
Write-Host "Creating random password for Host login"
$password = Get-RandomPassword 16

# Create resource group
Write-Host "Creating resource group"
az group create --name $ResourceGroupName --location $Location

# Create an AKS cluster with a Linux node pool
Write-Host "Creating AKS Cluster with Linux node pool"
az aks create `
    --resource-group $ResourceGroupName `
    --name $AKSClusterName `
    --network-plugin azure `
    --node-vm-size Standard_D2s_v3 `
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
    --resource-group $ResourceGroupName `
    --cluster-name $AKSClusterName `
    --os-sku Windows2022 `
    --name  txtlog `
    --node-vm-size Standard_D2s_v3 `
    --node-count $AKSWindowsNodeCount

# Create a Windows node pool for ETW Log scale test"
Write-Host "Creating Windows Node Pool for ETW Log scale test"
az aks nodepool add `
    --resource-group $ResourceGroupName `
    --cluster-name $AKSClusterName `
    --os-sku Windows2022 `
    --name  etwlog `
    --node-vm-size Standard_D2s_v3 `
    --node-count $AKSWindowsNodeCount

# Create a Windows node pool for Event Log scale test
Write-Host "Creating Windows Node Pool for Event Log scale test"
az aks nodepool add `
    --resource-group $ResourceGroupName `
    --cluster-name $AKSClusterName `
    --os-sku Windows2022 `
    --name  evtlog `
    --node-vm-size Standard_D2s_v3 `
    --node-count $AKSWindowsNodeCount

# Create a Windows node pool for Crash Dump scale test
Write-Host "Creating Windows Node Pool for Crash Dump scale test"
az aks nodepool add `
    --resource-group $ResourceGroupName `
    --cluster-name $AKSClusterName `
    --os-sku Windows2022 `
    --name  crashd `
    --node-vm-size Standard_D2s_v3 `
    --node-count $AKSWindowsNodeCount

# Create a Key Vault
Write-Host "Creating a key vault"
az keyvault create --name $KeyVaultName --resource-group $ResourceGroupName --location $Location

# Add password to as secret in the key vault
Write-Host "Adding Windows Node Pool passwrod to Key Vault"
az keyvault secret set --vault-name $KeyVaultName --name "WindowsScaleTest" --value $password

Write-Host "Windows Host Log Scale Test Infrastructure deployed"