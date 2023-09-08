param(
    [string] [Parameter(Mandatory = $true)] $GenevaAccountName,
    [string] [Parameter(Mandatory = $true)] $GenevaLogAccountNamespace,
    [string] [Parameter(Mandatory = $true)] $GenevaMetricAccountName,
    [guid] [Parameter(Mandatory = $true)] $AKSClusterMSIObjectId
)

. .\common.ps1

$genevaXmlConfigurationHashTable = @{
    'GENEVA_ACCOUNT_NAME' = $GenevaAccountName;
    'GENEVA_LOG_ACCOUNT_NAMESPACE' = $GenevaLogAccountNamespace;
    'GENEVA_METRIC_ACCOUNT' = $GenevaMetricAccountName;
    'CLUSTER_MANAGED_IDENTITY_OBJECT_ID' = $AKSClusterMSIObjectId;
    'GENEVA_STORAGE_DIAG' = $GenevaLogAccountNamespace.ToLower()+"diag";
    'GENEVA_STORAGE_SECURITY' = $GenevaLogAccountNamespace.ToLower()+"security";
    'GENEVA_STORAGE_LOGSAUDIT' = $GenevaLogAccountNamespace.ToLower()+"logsaudit";
}

#loop through all files under geneva-config-files then update each
$folderPath = ".\geneva-config-files" 
$listOfFiles = dir $folderPath -Recurse | % { 
    $_.fullname -replace [regex]::escape($folderPath), (split-path $folderPath -leaf)
}

foreach ($filePath in $listOfFiles)
{
    Write-Host "Updating $filePath with your Geneva Account"

    SubstituteNameValuePairs -InputFilePath $filePath -OutputFilePath $filePath -Substitutions $genevaXmlConfigurationHashTable

    Write-Host "$filePath is ready to be uploaded to Geneva"
}

#Once done open page to your Geneva Account to upload the new configurations
Start-Process "https://portal.microsoftgeneva.com/manage-logs-config?endpoint=Diagnostics%2520PROD&gwpAccount=$GenevaAccountName&gcsEnabled=true&gsmEnabled=true&hotpathAccount=$GenevaMetricAccountName"