<#
.SYNOPSIS
Deploylog generators
.DESCRIPTION
Deploys one or more log generators for scale testing. Can specify CrashDumps, ETW, EventLogs, and/or TextLogs. If none specified all will be deployed
.PARAMETER CrashDumps
Deploy the crash dumps generator
.PARAMETER ETW
Deploy the ETW generator
.PARAMETER EventLogs
Deploy the Event Logs generator
.PARAMETER TextLogs
Deploy the Text Logs generator
.EXAMPLE
deploy-log-generators.ps1

Deploy all Generators.
.EXAMPLE
deploy-log-generators.ps1 -TextLogs

Deploy just the text logs generator
.EXAMPLE
deploy-log-generators.ps1 -ETW -EventLogs

Deploy the ETW and Event Log generators
#>
param(
  [Parameter()][switch]$CrashDumps,
  [Parameter()][switch]$ETW,
  [Parameter()][switch]$EventLogs,
  [Parameter()][switch]$TextLogs
)

. "$PSScriptRoot\common.ps1"

$all = !$CrashDumps -and !$ETW -and !$EventLogs -and !$TextLogs

<#
.SYNOPSIS
Deploy a log generation DaemonSet
.DESCRIPTION
Build and deploy a DaemonSet to generate logs
.PARAMETER ImageTag
Full tag to use for the container image in the format <uri>/<tag>:<version>
.PARAMETER name
Name to give the DaemonSet
.PARAMETER namespace
Kubernetes namespace where the DaemonSet should be deployed
.PARAMETER nodeSelector
String to match for selecting nodes where the DaemonSet should be deployed
.EXAMPLE
Deploy-LogGenerator exampleacr.azurecr.io/generatelogs:latest LogGenerator log-generation whl-logs
#>
function buildAndDeploy {
  param(
  [Parameter(Mandatory = $true)][string] $ImageTag,
  [Parameter(Mandatory = $true)][string] $name,
  [Parameter(Mandatory = $true)][string] $namespace,
  [Parameter(Mandatory = $true)][string] $nodeSelector,
  [Parameter(Mandatory = $true)][string] $BuildPath
)
  Write-Host "Applying settings config map to $namespace"
  kubectl apply -f "$PSScriptRoot\log-generation-config.yaml" -n $namespace

  if(![string]::IsNullOrWhiteSpace((kubectl get ds -n $namespace $name -o name --ignore-not-found))){
    Write-Host "Daemonset $name already exists. Restarting with new configuration."
    kubectl rollout restart daemonset/$name -n $namespace
  } else {
    Build-DockerImage $ImageTag $WindowsVersion $BuildPath
    Push-DockerImage $ImageTag
    Deploy-LogGenerator $ImageTag $name $namespace $nodeSelector
  }
  
}

az login
az acr login -n $acrName

if($CrashDumps -or $all){
  Write-Host "START:Deploying Crash Dump Generator"
  # TODO: Deploy crash dump generator here
  Write-Host "END:Deploying Crash Dump Generator"
}

if($ETW -or $all){
  Write-Host "START:Deploying ETW Generator"
  # TODO: Deploy ETW generator here
  Write-Host "END:Deploying ETW Generator"
}

if($EventLogs -or $all){
  Write-Host "START:Deploying Event Log Generator"
  # TODO: Deploy event log generator here
  Write-Host "END:Deploying Event Log Generator"
}

if($TextLogs -or $all){
  Write-Host "START:Deploying Text Log Generator"
  # TODO: Deploy text log generator here
  Write-Host "END:Deploying Text Log Generator"
}