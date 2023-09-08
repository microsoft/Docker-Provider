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
Start-Process -filePath "DockerCli.exe" -WorkingDirectory "C:\Program Files\Docker\Docker" -ArgumentList "-SwitchWindowsEngine"

#Login into ACR
Write-Host "Logining into ACR"
az acr login --name $acrName

#Create latest WHL Container Image
$imageName = $acrUri + "/latestwhl:$(Get-Date -Format MMdd)"
Write-Host "Moving working directory to ..\..\kubernetes\windows\hostlogs"
Set-Location "..\..\kubernetes\windows\hostlogs"

$filepath = ".\build-and-publish-docker-image.ps1"
$dockerCommandArguments = "imageTag  ."

$dockerCommandHashTable = @{
    $dockerCommandArguments = $dockerCommandArguments + " --network `"Default Switch`"";
}

Write-Host "Improving compatibility with running build script locally"
SubstituteNameValuePairs -InputFilePath $filePath -OutputFilePath $filePath -Substitutions $dockerCommandHashTable

Write-Host "Creating latest WHL Container Image"
Invoke-Expression -Command ".\build-and-publish-docker-image.ps1 -image $imageName -windowsBaseImageVersion `"ltsc2022`"" 

# Get AKS credentials 
Write-Host "Gathering AKS credentials"
az aks get-credentials --resource-group $resourceGroupName --name $aksClusterName

# Wait for the Windows node to be available.
Write-Host "Waiting on node to become avaliable..."
kubectl get nodes -o wide

$imageName = $acrUri + "/latestwhl:win-$(Get-Date -Format MMdd)"
Write-Host "Using WHL Image: $imageName"

#Setup Crash Dump Generation Container
Write-Host "Creating namespace for Crash Dump scale component"
kubectl create namespace crashd-test
#kubectl apply -f crash-dump-generation.yaml

#Targeting WHL for Crash Dump Configuration
Write-Host "Configuring WHL for Crash Dump Log Collection"
$whlCrashDumpNamespace = "whl-crashd"
kubectl create namespace $whlCrashDumpNamespace
$containerYAMLFilePath = "..\..\host-logs-geneva.yaml"
$configmapFilePath = "..\..\container-azm-ms-agentconfig.yaml"

Write-Host "Updating WHL Container YAML and ConfigMap files"

$containerYAMLHashTable = @{    
    'kube-system' = $whlCrashDumpNamespace;
    'VALUE_CONTAINER_IMAGE' = $imageName;
    'VALUE_AKS_CLUSTER_NAME' = $aksClusterName;
    'VALUE_AKS_RESOURCE_REGION_VALUE' = $Location;
    'kubernetes.io/os' = 'agentpool';
    '- windows' = '- crashd'
}

$configMapHashTable = @{
    'VALUE_ENVIRONMENT' = $genevaEnvironment;
    'VALUE_ACCOUNT' = $GenevaAccountName;
    'VALUE_ACCOUNT_NAMESPACE' = $GenevaLogAccountNamespace;
    'VALUE_CONFIG_VERSION' = $CrashDumpConfigVersion;
    'kube-system' = $whlCrashDumpNamespace;
}

SubstituteNameValuePairs -InputFilePath $containerYAMLFilePath -OutputFilePath $containerYAMLFilePath -Substitutions $containerYAMLHashTable

SubstituteNameValuePairs -InputFilePath $configmapFilePath -OutputFilePath $configmapFilePath -Substitutions $configMapHashTable

Write-Host "Deploying WHL to the crashd node pool"
kubectl apply -f ..\..\kubernetes\container-azm-ms-agentconfig.yaml
kubectl apply -f ..\..\kubernetes\host-logs-geneva.yaml

#Setup Event Log Environment Generation Container
Write-Host "Creating namespace for Event Log scale component"
kubectl create namespace evtlog-test
#kubectl apply -f event-log-generation.yaml

#Targeting WHL for Event Log Configuration
Write-Host "Configuring WHL for Crash Dump Log Collection"
$whlEventLogNamespace = "whl-evtlog"
kubectl create namespace $whlEventLogNamespace
$containerYAMLFilePath = "..\..\host-logs-geneva.yaml"
$configmapFilePath = "..\..\container-azm-ms-agentconfig.yaml"

Write-Host "Updating WHL Container YAML and ConfigMap files"

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
kubectl apply -f ..\..\kubernetes\container-azm-ms-agentconfig.yaml
kubectl apply -f ..\..\kubernetes\host-logs-geneva.yaml

#Setup Text Log Environment Generation Container
Write-Host "Creating namespace for Text Log scale component"
kubectl create namespace txtlog-test
#kubectl apply -f text-log-generation.yaml

#Targeting WHL for Event Log Configuration
Write-Host "Configuring WHL for Event Log Collection"
$whlEventLogNamespace = "whl-evtlog"
kubectl create namespace $whlEventLogNamespace

Write-Host "Updating WHL Container YAML and ConfigMap files"

$containerYAMLHashTable = @{    
    $whlCrashDumpNamespace = $whlEventLogNamespace;
    '- crashd' = '- evtlog';
}

$configMapHashTable = @{
    $CrashDumpConfigVersion = $EventLogConfigVersion;
    $whlCrashDumpNamespace = $whlEventLogNamespace;
}

SubstituteNameValuePairs -InputFilePath $containerYAMLFilePath -OutputFilePath $containerYAMLFilePath -Substitutions $containerYAMLHashTable

SubstituteNameValuePairs -InputFilePath $configmapFilePath -OutputFilePath $configmapFilePath -Substitutions $configMapHashTable

Write-Host "Deploying WHL to the evtlog node pool"
kubectl apply -f ..\..\kubernetes\container-azm-ms-agentconfig.yaml
kubectl apply -f ..\..\kubernetes\host-logs-geneva.yaml

#Setup ETW Log Environment Generation Container
Write-Host "Creating namespace for ETW Log scale component"
kubectl create namespace ewtlog-test
#kubectl apply -f ewt-log-generation.yaml

#Targeting WHL for ETW Log Configuration
Write-Host "Configuring WHL for ETW Log Collection"
$whlETWLogNamespace = "whl-etwlog"
kubectl create namespace $whlETWLogNamespace

Write-Host "Updating WHL Container YAML and ConfigMap files"

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
kubectl apply -f ..\..\kubernetes\container-azm-ms-agentconfig.yaml
kubectl apply -f ..\..\kubernetes\host-logs-geneva.yaml

#Setup Text Log Environment Generation Container
Write-Host "Creating namespace for Text Log scale component"
kubectl create namespace txtlog-test
#kubectl apply -f txt-log-generation.yaml

#Targeting WHL for Text Log Configuration
Write-Host "Configuring WHL for Text Log Collection"
$whlTextLogNamespace = "whl-txtlog"
kubectl create namespace $whlTextLogNamespace

Write-Host "Updating WHL Container YAML and ConfigMap files"

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
kubectl apply -f ..\..\kubernetes\container-azm-ms-agentconfig.yaml
kubectl apply -f ..\..\kubernetes\host-logs-geneva.yaml

Write-Host "Windows Host Log Scale Test is now Live"