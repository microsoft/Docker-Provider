. (Join-Path $PSScriptRoot "../common.ps1")

$NUGET_SOURCE = "https://msazure.pkgs.visualstudio.com/One/_packaging/OneBranch-Consumption/nuget/v3/index.json"
$PACKAGE_NAME = "AzwHugeDump-retail-amd64"
$PACKAGE_VERSION = "1.0.97"
$DownloadName = "$PACKAGE_NAME.$PACKAGE_VERSION" # Expected folder/file name of the downloaded nuget package
$DownloadPath = Join-Path $TempDir "$DownloadName\$DownloadName.nupkg"
$TmpZipFile="$PSScriptRoot\crashdumpgenerator.zip" # Can't go in temp directory since dockerfile won't have access

function DownloadCrashDumpsPackage{
  Write-Host "START:Downloading Nuget Package: $PACKAGE_NAME"
  nuget install $PACKAGE_NAME -version $PACKAGE_VERSION -source $NUGET_SOURCE -DirectDownload -OutputDirectory $TempDir -PackageSaveMode nupkg -NonInteractive
  Move-Item $DownloadPath $TmpZipFile -Force # rename
  Write-Host "End:Downloading Nuget Package: $PACKAGE_NAME"
}

function CleanupCrashDumps{
  # We can leave items in the temp folder since those will be cleaned up by the infrastructure. 
  # But should clean up anything else used for building the docker image
  Remove-Item $TmpZipFile -Force
}