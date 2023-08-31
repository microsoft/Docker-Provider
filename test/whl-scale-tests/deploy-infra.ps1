param(
    [guid] [Parameter(Mandatory = $true)] $SubscriptionId,
    [string] [Parameter(Mandatory = $true)] $Location,
    [string] [Parameter(Mandatory = $false)] $ResourceGroupName = "whl-scale-test$(Get-Date -Format MMdd)",
    [string] [Parameter(Mandatory = $false)] $AKSClusterName = $ResourceGroupName + "-aks",
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
 
    return (-join $result)
}

# Login using your microsoft accout
Write-Host "Login in using your Microsoft account"
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
    --kubernetes-version 1.26.3 `
    --node-count 1 `
    --windows-admin-username azuureadmin `
    --windows-admin-password $password

# Create a Windows node pool
Write-Host "Creating Windows Node Pool"
az aks nodepool add `
    --resource-group $ResourceGroupName `
    --cluster-name $AKSClusterName `
    --os-type Windows `
    --name scale `
    --node-vm-size Standard_D2s_v3 `
    --node-count 5

# Wait for the Windows node to be available.
Write-Host "Waiting on node to become avaliable..."
kubectl get nodes -o wide

# Create a Key Vault
Write-Host "Creating a key vault"
az keyvault create --name $KeyVaultName --resource-group $ResourceGroupName --location $Location

# Add password to as secret in the key vault
Write-Host "Adding Windows Node Pool passwrod to Key Vault"
az keyvault secret set --vault-name $KeyVaultName --name "Windows Scale Test" --value $password

# Get AKS credentials 
Write-Host "Gathering AKS credentials"
az aks get-credentials --resource-group $ResourceGroupName --name $AKSClusterName

#Deploy windows host logs
Write-Host "Deploy WHL to the AKS Cluster"
kubectl apply -f ..\..\kubernetes\host-logs-geneva.ymal

Write-Host "Creating namespace for scaling components"
kubectl create namespace scale-test

Write-Host "Creating daemonset for X Scale Component"
kubectl apply -f .\
