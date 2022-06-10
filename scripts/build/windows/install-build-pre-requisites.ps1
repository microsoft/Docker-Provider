function Install-Go {
    $tempDir =  $env:TEMP
    if ($false -eq (Test-Path -Path $tempDir)) {
        Write-Host("Invalid TEMP dir PATH : " + $tempDir + " ") -ForegroundColor Red
        exit 1
    }

    $tempGo = Join-Path -Path $tempDir -ChildPath "gotemp"
    Write-Host("creating gotemp dir : " + $tempGo + " ")
    New-Item -Path $tempGo -ItemType "directory" -Force -ErrorAction Stop
    if ($false -eq (Test-Path -Path $tempGo)) {
        Write-Host("Invalid tempGo : " + $tempGo + " ") -ForegroundColor Red
        exit 1
    }

   $url = "https://go.dev/dl/go1.18.3.windows-amd64.msi"
   $output = Join-Path -Path $tempGo -ChildPath "go1.18.3.windows-amd64.msi"
   Write-Host("downloading go msi into directory path : " + $output + "  ...")
   Invoke-WebRequest -Uri $url -OutFile $output -ErrorAction Stop
   Write-Host("downloading of go msi into directory path : " + $output + "  completed")

   # install go lang
   Write-Host("installing go ...")
   Start-Process msiexec.exe -Wait -ArgumentList '/I ', $output, '/quiet'
   Write-Host("installing go completed")

   Write-Host "updating PATH variable"
   $GoPath = Join-Path -Path $env:SYSTEMDRIVE -ChildPath "GO"
   $path = $env:PATH + ";=" + $GoPath
   [System.Environment]::SetEnvironmentVariable("PATH", $path, "PROCESS")
   [System.Environment]::SetEnvironmentVariable("PATH", $path, "USER")
}

function Build-Dependencies {
    $tempDir =  $env:TEMP
    if ($false -eq (Test-Path -Path $tempDir)) {
        Write-Host("Invalid TEMP dir PATH : " + $tempDir + " ") -ForegroundColor Red
        exit 1
    }

    $tempDependencies = Join-Path -Path $tempDir -ChildPath "gcctemp"
    Write-Host("creating temp dir exist: " + $tempDependencies + " ")
    New-Item -Path $tempDependencies -ItemType "directory" -Force -ErrorAction Stop
    if ($false -eq (Test-Path -Path $tempDependencies)) {
        Write-Host("Invalid temp Dir : " + $tempDependencies + " ") -ForegroundColor Red
        exit 1
    }


    $destinationPath = Join-Path -Path $env:SYSTEMDRIVE -ChildPath "gcc"
    New-Item -Path $destinationPath -ItemType "directory" -Force -ErrorAction Stop

    Write-Host("downloading gcc : " + $destinationPath + "  ...")
    $gccDownLoadUrl = "https://ciwinagentbuildgcc.blob.core.windows.net/tdm-gcc-64/TDM-GCC-64.zip"
    $gccPath =  Join-Path -Path $destinationPath -ChildPath "gcc.zip"
    Invoke-WebRequest -UserAgent "BuildAgent" -Uri $gccDownLoadUrl -OutFile $gccPath
    Write-Host("downloading gcc zip  file completed")

    Write-Host("extracting gcc core zip  file ....")
    Expand-Archive -LiteralPath $gccPath -DestinationPath $destinationPath -Force
    Write-Host("extracting gcc core zip  completed....")

    # set gcc environment variable
    Write-Host("updating PATH environment variable with gcc path")
    $gccBinPath = Join-Path -Path $destinationPath -ChildPath "bin"

    $ProcessPathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "PROCESS")
    $ProcessPathEnv = $ProcessPathEnv + ";" + $gccBinPath

    $UserPathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "USER")
    $UserPathEnv = $UserPathEnv + ";" + $gccBinPath

    $MachinePathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $MachinePathEnv = $MachinePathEnv + ";" + $gccBinPath

    [System.Environment]::SetEnvironmentVariable("PATH", $ProcessPathEnv, "PROCESS")
    [System.Environment]::SetEnvironmentVariable("PATH", $UserPathEnv, "USER")
    [System.Environment]::SetEnvironmentVariable("PATH", $MachinePathEnv, "MACHINE")
}

function Install-DotNetCoreSDK() {
    $tempDir =  $env:TEMP
    if ($false -eq (Test-Path -Path $tempDir)) {
        Write-Host("Invalid TEMP dir : " + $tempDir + " ") -ForegroundColor Red
        exit 1
    }

    $dotNetSdkTemp = Join-Path -Path $tempDir -ChildPath "dotNetSdk"
    Write-Host("creating dotNetSdkTemp dir : " + $dotNetSdkTemp + " ")
    New-Item -Path $dotNetSdkTemp -ItemType "directory" -Force -ErrorAction Stop
    if ($false -eq (Test-Path -Path $dotNetSdkTemp)) {
        Write-Host("Invalid dotNetSdkTemp : " + $tempDir + " ") -ForegroundColor Red
        exit 1
    }

   $url = "https://download.visualstudio.microsoft.com/download/pr/4e88f517-196e-4b17-a40c-2692c689661d/eed3f5fca28262f764d8b650585a7278/dotnet-sdk-3.1.301-win-x64.exe"
   $output = Join-Path -Path $dotNetSdkTemp -ChildPath "dotnet-sdk-3.1.301-win-x64.exe"

   Write-Host("downloading .net core sdk 3.1: " + $dotNetSdkTemp + "  ...")
   Invoke-WebRequest -Uri $url -OutFile $output -ErrorAction Stop
   Write-Host("downloading .net core sdk 3.1: " + $dotNetSdkTemp + " completed")

   # install dotNet core sdk
   Write-Host("installing .net core sdk 3.1 ...")
   Start-Process -Wait $output -ArgumentList " /q /norestart"
   Write-Host("installing .net core sdk 3.1 completed")
}

function Install-Docker() {
    $tempDir =  $env:TEMP
    if ($false -eq (Test-Path -Path $tempDir)) {
        Write-Host("Invalid TEMP dir PATH : " + $tempDir + " ") -ForegroundColor Red
        exit 1
    }

    $dockerTemp = Join-Path -Path $tempDir -ChildPath "docker"
    Write-Host("creating docker temp dir : " + $dockerTemp + " ")
    New-Item -Path $dockerTemp -ItemType "directory" -Force -ErrorAction Stop
    if ($false -eq (Test-Path -Path $dockerTemp)) {
        Write-Host("Invalid dockerTemp : " + $tempDir + " ") -ForegroundColor Red
        exit 1
    }

   $url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
   $output = Join-Path -Path $dockerTemp -ChildPath "docker-desktop-installer.exe"
   Write-Host("downloading docker-desktop-installer: " + $dockerTemp + "  ...")
   Invoke-WebRequest -Uri $url -OutFile $output -ErrorAction Stop
   Write-Host("downloading docker-desktop-installer: " + $dockerTemp + "  completed")

   # install docker
   Write-Host("installing docker for desktop ...")
   Start-Process $output -Wait -ArgumentList 'install --quiet'
   Write-Host("installing docker for desktop completed")
}

# speed up Invoke-WebRequest 
# https://stackoverflow.com/questions/28682642/powershell-why-is-using-invoke-webrequest-much-slower-than-a-browser-download
$ProgressPreference = 'SilentlyContinue'

Write-Host "Install GO 1.18.3 version"
Install-Go
Write-Host "Install Build dependencies"
Build-Dependencies

Write-Host "Install .NET core sdk 3.1"
Install-DotNetCoreSDK

Write-Host "Install Docker"
Install-Docker

Write-Host "successfully installed required pre-requisites" -ForegroundColor Green
