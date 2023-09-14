<#
.SYNOPSIS
Deploylog generators
.DESCRIPTION
Deploys one or more log generators for scale testing. Can specify CrashDumps, ETW, EventLogs, and/or TextLogs. If none specified all will be deployed
.PARAMETER ACR
Azure container registry to store the generator images
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
  [Parameter(Mandatory=$true)][string] $ACR,
  [Parameter()][switch]$CrashDumps,
  [Parameter()][switch]$ETW,
  [Parameter()][switch]$EventLogs,
  [Parameter()][switch]$TextLogs
)

$all = !$CrashDumps -and !$ETW -and !$EventLogs -and !$TextLogs

az acr login -n $acr

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