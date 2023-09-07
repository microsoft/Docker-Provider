param(
    [string] [Parameter(Mandatory = $true)] $GenevaAccountName,
    [string] [Parameter(Mandatory = $true)] $GenevaLogAccountNamespace,
    [string] [Parameter(Mandatory = $true)] $GenevaMetricAccountName,
    [guid] [Parameter(Mandatory = $true)] $AKSClusterMSIObjectId,
    [string] [Parameter(Mandatory = $true)] $CIRepoRoot
)

$ReplaceGenevaAccountNameString = "<geneva-account-name>"
$ReplaceGenevaLogsAccountNamespaceString = "<geneva-log-account-namespace>"
$ReplaceGenevaMetricAccountNameString = "<geneva-metric-account>"
$ReplaceAKSClusterMSIObjectIdString = "<cluster-managed-identity-object-id>"
$ReplaceGenevaStorageDiagString = "<geneva-storage-diag>"
$ReplaceGenevaStorageSecurityString = "<geneva-storage-security>"
$ReplaceGenevaStorageLogsAuditString = "<geneva-storage-logsaudit>"

if(-not(Test-Path -Path $CIRepoRoot))
{
    Throw "$CIRepoRoot does not exist. Please provide the path of root of your local CI git repo."
    exit
}

#loop through all files under geneva-examples then update each
$folderPath = $CIRepoRoot + "\test\whl-scale-tests\geneva-examples" 
$listOfFiles = dir $folderPath -Recurse | % { 
    $_.fullname -replace [regex]::escape($folderPath), (split-path $folderPath -leaf)
}

foreach ($filePath in $listOfFiles)
{
    Write-Host "Updating $filePath with your Geneva Account"
    (Get-Content $filePath).Replace($ReplaceGenevaAccountNameString, $GenevaAccountName) | Set-Content $filePath

    (Get-Content $filePath).Replace($ReplaceGenevaLogsAccountNamespaceString, $GenevaLogAccountNamespace) | Set-Content $filePath

    (Get-Content $filePath).Replace($ReplaceGenevaMetricAccountNameString, $GenevaMetricAccountName) | Set-Content $filePath

    (Get-Content $filePath).Replace($ReplaceAKSClusterMSIObjectIdString, $AKSClusterMSIObjectId) | Set-Content $filePath

    (Get-Content $filePath).Replace($ReplaceGenevaStorageDiagString, $GenevaLogAccountNamespace.ToLower()+"diag") | Set-Content $filePath

    (Get-Content $filePath).Replace($ReplaceGenevaStorageSecurityString, $GenevaLogAccountNamespace.ToLower()+"security") | Set-Content $filePath

    (Get-Content $filePath).Replace($ReplaceGenevaStorageLogsAuditString, $GenevaLogAccountNamespace.ToLower()+"logsaudit") | Set-Content $filePath

    Write-Host "$filePath is ready to be uploaded to Geneva"
}

Start-Process "https://portal.microsoftgeneva.com/manage-logs-config?endpoint=Diagnostics%2520PROD&gwpAccount=$GenevaAccountName&gcsEnabled=true&gsmEnabled=true&hotpathAccount=$GenevaMetricAccountName"