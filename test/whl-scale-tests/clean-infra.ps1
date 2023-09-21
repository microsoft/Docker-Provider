param(
    [guid] [Parameter(Mandatory = $true)] $SubscriptionId
)

. "$PSScriptRoot\common.ps1"

# Login using your microsoft accout
Write-Host "Login with your Microsoft account"
az login

# Set subscription
Write-Host "Set az account to given Subscription"
az account set --subscription $SubscriptionId

# Delete Resource Group
Write-Host "Deleting resource group and all resources within it"
az group delete --name $resourceGroupName

#Remove Temporary Files
Remove-Item $TempDir -R -Force
