<#
    .DESCRIPTION
     Builds the Docker Image locally for the server core ltsc base and installs dependencies 

#>

$currentdir =  $PSScriptRoot
Write-Host("current script dir : " + $currentdir + " ")

if ($false -eq (Test-Path -Path $currentdir)) {
    Write-Host("Invalid current dir : " + $currentdir + " ") -ForegroundColor Red
    exit
}

Write-Host "start:Building the cert generator and out oms code via Makefile.ps1"
..\..\..\build\windows\Makefile.ps1
Write-Host "end:Building the cert generator and out oms code via Makefile.ps1"

$dockerFileDir = Split-Path -Path $currentdir
Write-Host("builddir dir : " + $dockerFileDir + " ")
if ($false -eq (Test-Path -Path $dockerFileDir)) {
    Write-Host("Invalid dockerFile Dir : " + $dockerFileDir + " ") -ForegroundColor Red
    exit
}

Write-Host "changing directory to DockerFile dir: $dockerFileDir"
Set-Location -Path $dockerFileDir

$updateImage = "omsagent-win-base"
Write-Host "STAT:Triggering base docker image build: $updateImage"
docker build -t $updateImage -f Dockerfile-dev-base-image .
Write-Host "END:Triggering docker image build: $updateImage"