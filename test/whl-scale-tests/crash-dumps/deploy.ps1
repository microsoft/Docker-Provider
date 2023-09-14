<#
.SYNOPSIS
Deploy a crash dumps DaemonSet
.DESCRIPTION
Build and deploy a DaemonSet to generate crash dumps
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
param(
  [Parameter(Mandatory = $true)][string] $ImageTag,
  [Parameter(Mandatory = $true)][string] $WindowsVersion,
  [Parameter(Mandatory = $true)][string] $namespace,
  [Parameter(Mandatory = $true)][string] $nodeSelector
)

. (Join-Path $PSScriptRoot "../common.ps1")

$NUGET_SOURCE = "https://msazure.pkgs.visualstudio.com/One/_packaging/OneBranch-Consumption/nuget/v3/index.json"
$PACKAGE_NAME = "AzwHugeDump-retail-amd64"
$PACKAGE_VERSION = "1.0.97"
$DownloadName = "$PACKAGE_NAME.$PACKAGE_VERSION" # Expected folder/file name of the downloaded nuget package
$TmpDir = Get-TempDir
$DownloadPath = Join-Path $TmpDir "$DownloadName\$DownloadName.nupkg"
$TmpZipFile="$PSScriptRoot\crashdumpgenerator.zip" # Can't go in temp directory since dockerfile won't have access

function DownloadPackage{
  Write-Host "START:Downloading Nuget Package: $PACKAGE_NAME"
  nuget install $PACKAGE_NAME -version $PACKAGE_VERSION -source $NUGET_SOURCE -DirectDownload -OutputDirectory $TmpDir -PackageSaveMode nupkg -NonInteractive
  Move-Item $DownloadPath $TmpZipFile -Force # rename
  Write-Host "End:Downloading Nuget Package: $PACKAGE_NAME"
}

function Cleanup{
  # We can leave items in the temp folder since those will be cleaned up by the infrastructure. But should clean up anything else
  Remove-Item $TmpZipFile -Force
}

DownloadPackage
Build-DockerImage $ImageTag $WindowsVersion $PSScriptRoot
Push-DockerImage $ImageTag
Deploy-LogGenerator $ImageTag "whl-crash-dump-generator" $namespace $nodeSelector
Cleanup
