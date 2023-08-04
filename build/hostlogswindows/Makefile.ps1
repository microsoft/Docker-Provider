#  Build script to build the liveness probe and copy installers for host logs
#  1. copy the files under installer directory to ..\..\kubernetes\windows\hostlogs\hostlogswindows
#  2. Builds the livenessprobe cpp and copy the executable to the under directory ..\..\kubernetes\windows\hostlogs\hostlogswindows

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

$rootdir = Split-Path -Path $builddir
if ($false -eq (Test-Path -Path $rootdir)) {
    Write-Host("Invalid docker provider root source dir : " + $rootdir + " ") -ForegroundColor Red
    exit 1
}

$publishdir = Join-Path -Path $rootdir -ChildPath "kubernetes\windows\hostlogs\hostlogswindows"
if ($true -eq (Test-Path -Path $publishdir)) {
    Write-Host("publish dir exist hence deleting: " + $publishdir + " ")
    Remove-Item -Path $publishdir  -Recurse -Force
}
Write-Host("creating publish dir exist: " + $publishdir + " ")
New-Item -Path $publishdir -ItemType "directory" -Force


# compile and build the liveness probe cpp code
Write-Host("Start:build livenessprobe cpp code")
$livenessprobesrcpath = Join-Path -Path $builddir  -ChildPath "hostlogswindows\installer\livenessprobe\livenessprobe.cpp"
$livenessprobeexepath = Join-Path -Path $builddir  -ChildPath "hostlogswindows\installer\livenessprobe\livenessprobe.exe"
g++ $livenessprobesrcpath -o $livenessprobeexepath -municode -l shlwapi
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

$installerdir = Join-Path -Path $builddir -ChildPath "hostlogswindows\installer"
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
