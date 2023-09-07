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

# Login using your microsoft accout
Write-Host "Login with your Microsoft account"
az login

# Set subscription
Write-Host "Set az account to given Subscription"
az account set --subscription $SubscriptionId

# Get AKS credentials 
Write-Host "Gathering AKS credentials"
az aks get-credentials --resource-group $ResourceGroupName --name $AKSClusterName

# Wait for the Windows node to be available.
Write-Host "Waiting on node to become avaliable..."
kubectl get nodes -o wide

#Deploy windows host logs **Make sure to document container and configmap changes to setup properly** 
Write-Host "Deploy WHL to the AKS Cluster"
kubectl apply -f ..\..\kubernetes\host-logs-geneva.yaml
kubectl apply -f ..\..\kubernetes\container-azm-ms-agentconfig.yaml

Write-Host "Creating namespace for Text Log scale component"
kubectl create namespace txtlog-test

Write-Host "Creating namespace for Event Log scale component"
kubectl create namespace evtlog-test

Write-Host "Creating namespace for ETW Log scale component"
kubectl create namespace ewtlog-test

Write-Host "Creating namespace for Crash Dump scale component"
kubectl create namespace crashd-test

#Write-Host "Creating daemonset for X scale Component"
#kubectl apply -f .\
