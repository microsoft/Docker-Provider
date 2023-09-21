$ErrorActionPreference = 'Stop'
$TempDir = "$PSScriptRoot\Temp"

$WindowsVersion = "ltsc2022"
$resourceGroupName = [Environment]::UserName + "scaletest"
$aksClusterName = $resourceGroupName + "aks"
$keyVaultName = $resourceGroupName + "kv"
$genevaEnvironment = "DiagnosticsProd"
$acrName = $resourceGroupName + "acr"
$acrUri = $acrName + ".azurecr.io"

if(!(Test-Path $TempDir)){
    New-Item -ItemType Directory -Force -Path $TempDir
}

function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [ValidateRange(4,72)]
        [int] $length,
        [int] $upper = 1,
        [int] $lower = 1,
        [int] $numeric = 1,
        [int] $special = 1
    )
    if($upper + $lower + $numeric + $special -gt $length) {
        throw "number of upper/lower/numeric/special char must be lower or equal to length"
    }
    $uCharSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lCharSet = "abcdefghijklmnopqrstuvwxyz"
    $nCharSet = "0123456789"
    $sCharSet = "{-)}^%(_!#$"
    $charSet = ""
    if($upper -gt 0) { $charSet += $uCharSet }
    if($lower -gt 0) { $charSet += $lCharSet }
    if($numeric -gt 0) { $charSet += $nCharSet }
    if($special -gt 0) { $charSet += $sCharSet }
    
    $charSet = $charSet.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rng.GetBytes($bytes)
 
    $result = New-Object char[]($length)
    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i] % $charSet.Length]
    }
    $password = (-join $result)
    $valid = $true
    if($upper   -gt ($password.ToCharArray() | Where-Object {$_ -cin $uCharSet.ToCharArray() }).Count) { $valid = $false }
    if($lower   -gt ($password.ToCharArray() | Where-Object {$_ -cin $lCharSet.ToCharArray() }).Count) { $valid = $false }
    if($numeric -gt ($password.ToCharArray() | Where-Object {$_ -cin $nCharSet.ToCharArray() }).Count) { $valid = $false }
    if($special -gt ($password.ToCharArray() | Where-Object {$_ -cin $sCharSet.ToCharArray() }).Count) { $valid = $false }
 
    if(!$valid) {
         $password = Get-RandomPassword $length $upper $lower $numeric $special
    }
    return $password
}

function SubstituteNameValuePairs {
    param(
        [string][Parameter(Mandatory=$true)] $InputFilePath,
        [string][Parameter(Mandatory=$true)] $OutputFilePath,
        [hashtable][Parameter(Mandatory=$true)] $Substitutions
    )

    # Ensure the input file exists
    if (-not (Test-Path -Path $InputFilePath)) {
        Write-Host "  Input File: '$InputFilePath' does not exist" -ForegroundColor Red
        exit
    }

    $content = Get-Content $InputFilePath;
    foreach($subItem in $Substitutions.GetEnumerator())
    {
        $content = $content.Replace($subItem.Name, $subItem.Value); 
    }
    $content | Set-Content $OutputFilePath;
}

<#
.SYNOPSIS
Start docker engine 
#>
function Start-Docker{
    $dockerServer = ((docker version -f json) | ConvertFrom-Json).server 2> $null

    #Use Windows Engine on Docker
    if($null -eq $dockerServer){
        Write-Host "Setting Docker to utilize Windows Engine"
        Start-Process -filePath "Docker Desktop.exe" -WorkingDirectory "C:\Program Files\Docker\Docker"
        Start-Sleep -Seconds 60
    }
    
    $dockerOs = ((docker version -f json) | ConvertFrom-Json).server.os 2> $null
    if($dockerOs -ne "windows"){
        Start-Process -filePath "DockerCli.exe" -WorkingDirectory "C:\Program Files\Docker\Docker" -ArgumentList "-SwitchWindowsEngine"
        Start-Sleep -Seconds 60
    }
}

<#
.SYNOPSIS
Builds the docker image for a log generator
.PARAMETER image
Full tag to use for the image in the format <uri>/<tag>:<version>
.PARAMETER windowsVersion
Windows server core image version to use
.PARAMETER buildDirectory
Docker context
.PARAMETER dockerfile
Path to dockerfile. Default is $buildDirectory/Dockerfile
.EXAMPLE
Build-DockerImage exampleacr.azurecr.io/generatelogs:latest ltsc2022 . 
#>
function Build-DockerImage {
    param(
        [Parameter(Mandatory = $true)]  [string] $imageTag,
        [Parameter(Mandatory = $true)]  [string] $windowsVersion,
        [Parameter(Mandatory = $true)]  [string] $buildDirectory,
        [Parameter(Mandatory = $false)] [string] $dockerfile
    )
    Write-Host "START:Triggering docker image build: $imageTag";
    if(![string]::IsNullOrWhiteSpace($dockerfile)){
        docker build --isolation=hyperv -t $imageTag --build-arg WINDOWS_VERSION=$windowsVersion -f $dockerfile $buildDirectory;
    } else {
        docker build --isolation=hyperv -t $imageTag --build-arg WINDOWS_VERSION=$windowsVersion $buildDirectory;
    }
    
    Write-Host "END:Triggering docker image build: $imageTag";
}

<#
.SYNOPSIS
Pushes a docker images to a container registry
.PARAMETER imageTag
Full tag of the image to push in the format <uri>/<tag>:<version>
.EXAMPLE
Push-DockerImage exampleacr.azurecr.io/generatelogs:latest
.NOTES
Must already be authenticated to the container registry or this will fail.
#>
function Push-DockerImage {
    param(
        [Parameter(Mandatory = $true)][string] $imageTag
    )
    Write-Host "START:pushing docker image: $imageTag";
    docker push $imageTag;
    Write-Host "END:pushing docker image: $imageTag";
}

<#
.SYNOPSIS
Deploy a log generator DaemonSet
.DESCRIPTION
Creates a deployment yaml from the deployment template to deploy a specific log generator. Then applies the yaml file to the cluster in the current kubeconfig context
.PARAMETER imageTag
Full tag of the image for the log generator in the format <uri>/<tag>:<version>
.PARAMETER name
Name to give the DaemonSet
.PARAMETER namespace
Kubernetes namespace where the DaemonSet should be deployed
.PARAMETER nodeSelector
String to match for selecting nodes where the DaemonSet should be deployed
.EXAMPLE
Deploy-LogGenerator exampleacr.azurecr.io/generatelogs:latest LogGenerator log-generation whl-logs
#>
function Deploy-LogGenerator {
    param(
        [Parameter(Mandatory = $true)][string] $imageTag,
        [Parameter(Mandatory = $true)][string] $name,
        [Parameter(Mandatory = $true)][string] $namespace,
        [Parameter(Mandatory = $true)][string] $nodeSelector
    )
    
    Write-Host "Configuring Log Generation Template for $name";
    $template = "$PSScriptRoot\deploy-log-generator.template.yaml";
    $file = Join-Path $TempDir "deploy-log-generator.$name.yaml";
    $substitutions = @{
        "<CONTAINER_IMAGE>" = $imageTag;
        "<DEPLOYMENT_NAME>" = $name;
        "<NODE_SELECTOR>"   = $nodeSelector
    }
    SubstituteNameValuePairs $template $file $substitutions;

    Write-Host "START:Deploying Log Generation Daemonset: $name";
    kubectl apply -f $file -n $namespace;
    Write-Host "End:Deploying Log Generation Daemonset: $name";
}