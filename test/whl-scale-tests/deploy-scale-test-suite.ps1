param(
    [guid] [Parameter(Mandatory = $true)] $SubscriptionId,
    [string] [Parameter(Mandatory = $true)] $Location,
    [string] [Parameter(Mandatory = $true)] $GenevaAccountName,
    [string] [Parameter(Mandatory = $true)] $GenevaLogAccountNamespace,
    [string] [Parameter(Mandatory = $true)] $CrashDumpConfigVersion,
    [string] [Parameter(Mandatory = $true)] $ETWConfigVersion,
    [string] [Parameter(Mandatory = $true)] $EventLogConfigVersion,
    [string] [Parameter(Mandatory = $true)] $TextLogConfigVersion
)

$orignalPath = Get-Location
Set-Location -Path $PSScriptRoot
. .\common.ps1

$genevaEnvironment = "DiagnosticsProd"
$resourceGroupName = [Environment]::UserName + "scaletest"
$aksClusterName = $resourceGroupName + "aks"
$acrName = $resourceGroupName + "acr"
$acrUri = $acrName + ".azurecr.io"

# Login using your microsoft accout
Write-Host "Login with your Microsoft account"
az login

# Set subscription
Write-Host "Setting az account to given Subscription"
az account set --subscription $SubscriptionId

#Use Windows Engine on Docker
Write-Host "Setting Docker to utilize Windows Engine"
Start-Process -filePath "Docker Desktop.exe" -WorkingDirectory "C:\Program Files\Docker\Docker"
Start-Sleep -Seconds 60
Start-Process -filePath "DockerCli.exe" -WorkingDirectory "C:\Program Files\Docker\Docker" -ArgumentList "-SwitchWindowsEngine"

#Login into ACR
Write-Host "Logining into ACR"
az acr login --name $acrName

#Create latest WHL Container Image
$imageName = $acrUri + "/latestwhl:$(Get-Date -Format MMdd)"
Write-Host "Moving working directory to ..\..\kubernetes\windows\hostlogs"
Set-Location "..\..\kubernetes\windows\hostlogs"

Write-Host "Creating latest WHL Container Image"
Invoke-Expression -Command ".\build-and-publish-docker-image.ps1 -image $imageName" 

# Get AKS credentials 
Write-Host "Gathering AKS credentials"
az aks get-credentials --resource-group $resourceGroupName --name $aksClusterName

# Wait for the Windows node to be available.
Write-Host "Waiting on node to become avaliable..."
kubectl wait node --all --for condition=Ready --timeout=60s

$imageName = $acrUri + "/latestwhl:win-$(Get-Date -Format MMdd)"
Write-Host "Using WHL Image: $imageName"

Write-Host "Moving working directory to ..\..\..\kubernetes"
Set-Location "..\..\..\kubernetes"
$containerYAMLFilePath = ".\host-logs-geneva.yaml"
$configmapFilePath = ".\container-azm-ms-agentconfig.yaml"

#Targeting WHL for Crash Dump Configuration
Write-Host "Configuring WHL for Crash Dump Log Collection"
$whlCrashDumpNamespace = "whl-crashd"
kubectl create namespace $whlCrashDumpNamespace

Write-Host "Updating WHL Container YAML and ConfigMap to deploy to evtlog agent pool"

$containerYAMLHashTable = @{    
    'kube-system' = $whlCrashDumpNamespace;
    'VALUE_CONTAINER_IMAGE' = $imageName;
    'VALUE_AKS_CLUSTER_NAME' = $aksClusterName;
    'VALUE_AKS_RESOURCE_REGION_VALUE' = $Location;
    'kubernetes.io/os' = 'kubernetes.azure.com/agentpool';
    '- windows' = '- crashd'
}

$configMapHashTable = @{
    'VALUE_ENVIRONMENT' = $genevaEnvironment;
    'VALUE_ACCOUNT_NAMESPACE' = $GenevaLogAccountNamespace;
    'VALUE_GENEVA_ACCOUNT' = $GenevaAccountName;
    'VALUE_CONFIG_VERSION' = $CrashDumpConfigVersion;
    'namespace: kube-system' = "namespace: $whlCrashDumpNamespace";
}

SubstituteNameValuePairs -InputFilePath $containerYAMLFilePath -OutputFilePath $containerYAMLFilePath -Substitutions $containerYAMLHashTable

SubstituteNameValuePairs -InputFilePath $configmapFilePath -OutputFilePath $configmapFilePath -Substitutions $configMapHashTable

Write-Host "Deploying WHL to the crashd node pool"
kubectl apply -f .\host-logs-geneva.yaml

Write-Host "Waiting for pod to be ready..."

Start-Sleep -Seconds 180
kubectl get pods -n $whlCrashDumpNamespace

kubectl apply -f .\container-azm-ms-agentconfig.yaml
Start-Sleep -Seconds 180
kubectl get pods -n $whlCrashDumpNamespace

#Targeting WHL for Event Log Configuration
Write-Host "Configuring WHL for Event Log Collection"
$whlEventLogNamespace = "whl-evtlog"
kubectl create namespace $whlEventLogNamespace

Write-Host "Updating WHL Container YAML and ConfigMap to deploy to evtlog agent pool"

$containerYAMLHashTable = @{    
    $whlCrashDumpNamespace = $whlEventLogNamespace;
    '- crashd' = '- evtlog'
}

$configMapHashTable = @{
    $CrashDumpConfigVersion = $EventLogConfigVersion;
    $whlCrashDumpNamespace = $whlEventLogNamespace;
}

SubstituteNameValuePairs -InputFilePath $containerYAMLFilePath -OutputFilePath $containerYAMLFilePath -Substitutions $containerYAMLHashTable

SubstituteNameValuePairs -InputFilePath $configmapFilePath -OutputFilePath $configmapFilePath -Substitutions $configMapHashTable

Write-Host "Deploying WHL to the evtlog node pool"
kubectl apply -f .\host-logs-geneva.yaml

Write-Host "Waiting..."

Start-Sleep -Seconds 180
kubectl get pods -n $whlEventLogNamespace

kubectl apply -f .\container-azm-ms-agentconfig.yaml
Start-Sleep -Seconds 180
kubectl get pods -n $whlEventLogNamespace

#Targeting WHL for ETW Log Configuration
Write-Host "Configuring WHL for ETW Log Collection"
$whlETWLogNamespace = "whl-etwlog"
kubectl create namespace $whlETWLogNamespace

Write-Host "Updating WHL Container YAML and ConfigMap to deploy to etwlog agent pool"

$containerYAMLHashTable = @{    
    $whlEventLogNamespace = $whlETWLogNamespace;
    '- evtlog' = '- etwlog';
}

$configMapHashTable = @{
    $EventLogConfigVersion = $ETWConfigVersion;
    $whlEventLogNamespace = $whlETWLogNamespace;
}

SubstituteNameValuePairs -InputFilePath $containerYAMLFilePath -OutputFilePath $containerYAMLFilePath -Substitutions $containerYAMLHashTable

SubstituteNameValuePairs -InputFilePath $configmapFilePath -OutputFilePath $configmapFilePath -Substitutions $configMapHashTable

Write-Host "Deploying WHL to the etwlog node pool"
kubectl apply -f .\host-logs-geneva.yaml

Write-Host "Waiting..."

Start-Sleep -Seconds 180
kubectl get pods -n $whlETWLogNamespace

kubectl apply -f .\container-azm-ms-agentconfig.yaml
Start-Sleep -Seconds 180
kubectl get pods -n $whlETWLogNamespace

#Targeting WHL for Text Log Configuration
Write-Host "Configuring WHL for Text Log Collection"
$whlTextLogNamespace = "whl-txtlog"
kubectl create namespace $whlTextLogNamespace

Write-Host "Updating WHL Container YAML and ConfigMap to deploy to txtlog agent pool"

$containerYAMLHashTable = @{    
    $whlETWLogNamespace = $whlTextLogNamespace;
    '- etwlog' = '- txtlog';
}

$configMapHashTable = @{
    $ETWConfigVersion = $TextLogConfigVersion;
    $whlETWLogNamespace = $whlTextLogNamespace;
}

SubstituteNameValuePairs -InputFilePath $containerYAMLFilePath -OutputFilePath $containerYAMLFilePath -Substitutions $containerYAMLHashTable

SubstituteNameValuePairs -InputFilePath $configmapFilePath -OutputFilePath $configmapFilePath -Substitutions $configMapHashTable

Write-Host "Deploying WHL to the txtlog node pool"
kubectl apply -f .\host-logs-geneva.yaml

Write-Host "Waiting..."

Start-Sleep -Seconds 180
kubectl get pods -n $whlTextLogNamespace

kubectl apply -f .\container-azm-ms-agentconfig.yaml
Start-Sleep -Seconds 180
kubectl get pods -n $whlTextLogNamespace

Set-Location -Path $orignalPath.path
Write-Host "Windows Host Log Scale Test is now Live"