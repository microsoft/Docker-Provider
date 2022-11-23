#  Build script to build the .NET and Go lang code for the Windows agent.
#  It does following  tasks
#  1. Builds the certificate generator code in .NET and copy the binaries in zip file to ..\..\kubernetes\windows\amalogswindows
#  2. Builds the out_oms plugin code in go lang  into the shared object(.so) file and copy the out_oms.so file  to ..\..\kubernetes\windows\amalogswindows
#  3. copy the files under installer directory to ..\..\kubernetes\windows\amalogswindows
#  4. Builds the livenessprobe cpp and copy the executable to the under directory ..\..\kubernetes\windows\amalogswindows

$dotnetcoreframework = "netcoreapp3.1"

Write-Host("Building Certificate generator code...")
$currentdir =  $PSScriptRoot
Write-Host("current script dir : " + $currentdir + " ")

if ($false -eq (Test-Path -Path $currentdir)) {
    Write-Host("Invalid current dir : " + $currentdir + " ") -ForegroundColor Red
    exit 1
}

$builddir = Split-Path -Path $currentdir
Write-Host("builddir dir : " + $builddir + " ")
if ($false -eq (Test-Path -Path $builddir)) {
    Write-Host("Invalid build dir : " + $builddir + " ") -ForegroundColor Red
    exit 1
}

$versionFilePath = Join-Path -Path $builddir -child "version"
Write-Host("versionFilePath  : " + $versionFilePath + " ")
if ($false -eq (Test-Path -Path $versionFilePath)) {
    Write-Host("Version file path incorrect or doesnt exist : " + $versionFilePath + " ") -ForegroundColor Red
    exit 1
}

# read the version info
foreach($line in Get-Content -Path $versionFilePath) {
    if ([string]$line.startswith("CONTAINER_BUILDVERSION_") -eq $true) {
         $parts =  $line.split("=")
         if ($parts.length -lt 2 ) {
            Write-Host("Invalid content in version file : " + $versionFilePath + " ") -ForegroundColor Red
            exit 1
         }
         switch ($parts[0]) {
            "CONTAINER_BUILDVERSION_MAJOR" { $BuildVersionMajor = $parts[1] }
            "CONTAINER_BUILDVERSION_MINOR" { $BuildVersionMinor = $parts[1] }
            "CONTAINER_BUILDVERSION_PATCH" { $BuildVersionPatch = $parts[1] }
            "CONTAINER_BUILDVERSION_BUILDNR" { $BuildVersionBuildNR = $parts[1] }
            "CONTAINER_BUILDVERSION_DATE" { $BuildVersionDate = $parts[1] }
            "CONTAINER_BUILDVERSION_STATUS" { $BuildVersionStatus = $parts[1] }
            default { Write-Host("This field is not expected in the version file : $line") -ForegroundColor Yellow }
        }
    }
}

if ([string]::IsNullOrEmpty($BuildVersionMajor) -or
    [string]::IsNullOrEmpty($BuildVersionMinor) -or
    [string]::IsNullOrEmpty($BuildVersionPatch) -or
    [string]::IsNullOrEmpty($BuildVersionBuildNR) -or
    [string]::IsNullOrEmpty($BuildVersionDate) -or
    [string]::IsNullOrEmpty($BuildVersionStatus)) {
    Write-Host("Expected version info doesnt exist in this version file : " + $versionFilePath + " ") -ForegroundColor Red
    exit 1
}
# build version format will be [major].[minior].[patch]-[revision]
$buildVersionString = $BuildVersionMajor + "." + $BuildVersionMinor + "." + $BuildVersionPatch + "-" + $BuildVersionBuildNR
$buildVersionDate = $BuildVersionDate


$certsrcdir = Join-Path -Path $builddir -ChildPath "windows\installer\certificategenerator"
Write-Host("certsrc dir : " + $certsrcdir + " ")
if ($false -eq (Test-Path -Path $certsrcdir)) {
    Write-Host("Invalid certificate generator source dir : " + $certsrcdir + " ") -ForegroundColor Red
    exit 1
}
Write-Host("set the cerificate generator source code directory : " + $certsrcdir + " ...")
Set-Location -Path $certsrcdir

Write-Host("Adding dotnet packages Newtonsoft.json and BouncyCastle ...")
dotnet add package Newtonsoft.json
dotnet add package BouncyCastle
Write-Host("Successfully added dotnet packages") -ForegroundColor Green
dotnet build  -f $dotnetcoreframework
Write-Host("Building Certificate generator code and ...") -ForegroundColor Green

Write-Host("Publish release and win10-x64 binaries of certificate generator code  ...")
$isCDPxEnvironment = $false
if (![string]::IsNullOrEmpty([System.Environment]::GetEnvironmentVariable("IsCDPXBuildMachine", "PROCESS")) -or
![string]::IsNullOrEmpty([System.Environment]::GetEnvironmentVariable("IsCDPXBuildMachine", "USER")) -or
![string]::IsNullOrEmpty([System.Environment]::GetEnvironmentVariable("IsCDPXBuildMachine", "Machine") )) {
    $isCDPxEnvironment = $true

}
if ($isCDPxEnvironment) {
    Write-Host("running on CDPX build machine so setting --no-restore since there is no n/w connectivity during build")
    dotnet publish -c Release -r win10-x64 --no-restore
} else {
  dotnet publish -c Release -r win10-x64
}

Write-Host("Successfully published certificate generator code binaries") -ForegroundColor Green

$certreleasebinpath =  Join-Path -PATH $certsrcdir -ChildPath "bin\Release\$dotnetcoreframework\win10-x64\publish\*.*"
if ($false -eq (Test-Path -Path $certreleasebinpath)) {
    Write-Host("certificate release bin path doesnt exist : " + $certreleasebinpath + " ") -ForegroundColor Red
    exit 1
}

$rootdir = Split-Path -Path $builddir
if ($false -eq (Test-Path -Path $rootdir)) {
    Write-Host("Invalid docker provider root source dir : " + $rootdir + " ") -ForegroundColor Red
    exit 1
}

$publishdir = Join-Path -Path $rootdir -ChildPath "kubernetes\windows\amalogswindows"
if ($true -eq (Test-Path -Path $publishdir)) {
    Write-Host("publish dir exist hence deleting: " + $publishdir + " ")
    Remove-Item -Path $publishdir  -Recurse -Force
}
Write-Host("creating publish dir exist: " + $publishdir + " ")
New-Item -Path $publishdir -ItemType "directory" -Force

$certreleasepublishpath = Join-Path  -Path $publishdir -ChildPath "certificategenerator.zip"

Write-Host("Compressing and copying the certificate generator release binaries ...")
Compress-Archive -Path  $certreleasebinpath -DestinationPath $certreleasepublishpath  -Force
Write-Host("Successfully copied compressed certificate generator release binaries") -ForegroundColor Green

# build  the shared object (.so) for out oms go plugin code
$outomsgoplugindir = Join-Path -Path $rootdir -ChildPath "source\plugins\go\src"
Write-Host("Building Out_OMS go plugin code...")
if ($false -eq (Test-Path -Path $outomsgoplugindir)) {
    Write-Host("Invalid Out oms go plugin code dir : " + $outomsgoplugindir + " ") -ForegroundColor Red
    exit 1
}
Set-Location -Path $outomsgoplugindir

Write-Host("cleanup existing .so and .h file ...")
Remove-Item -Path $outomsgoplugindir\* -Include *.so,*.h -Force -ErrorAction Stop
Write-Host("cleanup existing .so and .h file")

if ($isCDPxEnvironment) {
     go build -ldflags "-X 'main.revision=$buildVersionString' -X 'main.builddate=$buildVersionDate'" -buildmode=c-shared -o out_oms.so .
}  else {
   $platform = "windows"
   if (![string]::IsNullOrEmpty($PSVersionTable) -and ![string]::IsNullOrEmpty($PSVersionTable.Platform)) {
      $platform = $PSVersionTable.Platform.ToLower()
   }
   Write-Host("Running non CDPX environment, Platform:$platform")
   if ($platform -eq "unix") {
    Write-Host("Using cross-platform compiler since detected running on UNIX style platform")
    Write-Host("Setting Windows Platform specific go envs at process level")
    [System.Environment]::SetEnvironmentVariable("GOOS",  "windows", [System.EnvironmentVariableTarget]::PROCESS)
    [System.Environment]::SetEnvironmentVariable("GOARCH", "amd64", [System.EnvironmentVariableTarget]::PROCESS)
    [System.Environment]::SetEnvironmentVariable("CGO_ENABLED", "1", [System.EnvironmentVariableTarget]::PROCESS)
    [System.Environment]::SetEnvironmentVariable("CC", "x86_64-w64-mingw32-gcc", [System.EnvironmentVariableTarget]::PROCESS)
    [System.Environment]::SetEnvironmentVariable("CXX", "x86_64-w64-mingw32-g++", [System.EnvironmentVariableTarget]::PROCESS)
    # unset GOBIN env var for cross platform build just process level not impact the linux go build
    [System.Environment]::SetEnvironmentVariable("GOBIN", "", [System.EnvironmentVariableTarget]::PROCESS)
  }

  Write-Host("getting latest go modules ...")
  go  get
  Write-Host("successfully got latest go modules") -ForegroundColor Green

  go build -ldflags "-X 'main.revision=$buildVersionString' -X 'main.builddate=$buildVersionDate'" -buildmode=c-shared -o out_oms.so .
}


Write-Host("copying out_oms.so file to : $publishdir")
Copy-Item -Path (Join-path -Path $outomsgoplugindir -ChildPath "out_oms.so")  -Destination $publishdir -Force
Write-Host("successfully copied out_oms.so file to : $publishdir") -ForegroundColor Green

# compile and build the liveness probe cpp code
Write-Host("Start:build livenessprobe cpp code")
$livenessprobesrcpath = Join-Path -Path $builddir  -ChildPath "windows\installer\livenessprobe\livenessprobe.cpp"
$livenessprobeexepath = Join-Path -Path $builddir  -ChildPath "windows\installer\livenessprobe\livenessprobe.exe"
g++ $livenessprobesrcpath -o $livenessprobeexepath -municode
Write-Host("End:build livenessprobe cpp code")
if (Test-Path -Path $livenessprobeexepath){
    Write-Host("livenessprobe.exe exists which indicates cpp build step succeeded") -ForegroundColor Green
} else {
    Write-Host("livenessprobe.exe doesnt exist which indicates cpp build step failed") -ForegroundColor Red
    exit 1
}

$installerdir = Join-Path -Path $builddir -ChildPath "common\installer"
Write-Host("copying common installer files conf and scripts from :" + $installerdir + "  to  :" + $publishdir + " ...")
$exclude = @('*.cs','*.csproj', '*.cpp')
Copy-Item  -Path $installerdir  -Destination $publishdir -Recurse -Force -Exclude $exclude
Write-Host("successfully copied installer files conf and scripts from :" + $installerdir + "  to  :" + $publishdir + " ") -ForegroundColor Green

$installerdir = Join-Path -Path $builddir -ChildPath "windows\installer"
Write-Host("copying installer files conf and scripts from :" + $installerdir + "  to  :" + $publishdir + " ...")
$exclude = @('*.cs','*.csproj', '*.cpp')
Copy-Item  -Path $installerdir  -Destination $publishdir -Recurse -Force -Exclude $exclude
Write-Host("successfully copied installer files conf and scripts from :" + $installerdir + "  to  :" + $publishdir + " ") -ForegroundColor Green

$rubyplugindir = Join-Path -Path $rootdir -ChildPath "source\plugins\ruby"
Write-Host("copying ruby source files from :" + $rubyplugindir + "  to  :" + $publishdir + " ...")
Copy-Item -Path $rubyplugindir -Destination $publishdir -Recurse -Force
Get-ChildItem $Path | Where{$_.Name -Match ".*_test\.rb"} | Remove-Item
Write-Host("successfully copied ruby source files from :" + $rubyplugindir + "  to  :" + $publishdir + " ") -ForegroundColor Green

Set-Location $currentdir
