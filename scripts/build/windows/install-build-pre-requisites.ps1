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

   $url = "https://go.dev/dl/go1.23.8.windows-amd64.msi"
   $output = Join-Path -Path $tempGo -ChildPath "go1.23.8.windows-amd64.msi"
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
    $gccDownLoadUrl = "https://github.com/microsoft/Docker-Provider/releases/download/tdm-gcc/TDM-GCC-64.zip"
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

    Set-Location -Path $dotNetSdkTemp

    Write-Host("Downloading Microsoft's official .NET installation script...")
    # Use the official Microsoft .NET installation script
    Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile "dotnet-install.ps1" -ErrorAction Stop
    Write-Host("Downloaded .NET installation script successfully")

    Write-Host("Installing .NET 6.0 SDK...")
    # Install .NET 6.0 SDK which is required by the Makefile.ps1
    .\dotnet-install.ps1 -Channel 6.0 -InstallDir "C:\dotnet"
    Write-Host("Successfully installed .NET 6.0 SDK") -ForegroundColor Green
    
    # Add .NET to PATH at Machine level for persistence across processes
    Write-Host("Adding .NET to PATH...")
    $dotnetPath = "C:\dotnet"
    
    # Update PATH at all levels to ensure persistence
    $ProcessPathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "PROCESS")
    $UserPathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "USER")
    $MachinePathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "MACHINE")
    
    # Add to Machine level PATH for system-wide persistence
    $MachinePathEnv = $MachinePathEnv + ";" + $dotnetPath
    [System.Environment]::SetEnvironmentVariable("PATH", $MachinePathEnv, "MACHINE")
    
    # Update current process PATH
    $ProcessPathEnv = $ProcessPathEnv + ";" + $dotnetPath
    [System.Environment]::SetEnvironmentVariable("PATH", $ProcessPathEnv, "PROCESS")
    
    # Refresh environment variables to make dotnet available immediately
    $env:Path = $MachinePathEnv + ";" + $UserPathEnv
}

function Install-Docker() {
    Write-Host "Installing Docker for Windows 2025 build agents..." -ForegroundColor Cyan
    
    # $dockerFound = $false
    # try {
    #     $dockerVersion = & docker --version 2>&1
    #     if ($LASTEXITCODE -eq 0) {
    #         Write-Host "SUCCESS: Docker already installed: $dockerVersion" -ForegroundColor Green
    #         $dockerFound = $true
    #     }
    # } catch {
    #     Write-Host "Docker not found in PATH, proceeding with installation..." -ForegroundColor Yellow
    # }
    
    # if (-not $dockerFound) {
    #     $tempDir = $env:TEMP
    #     if ($false -eq (Test-Path -Path $tempDir)) {
    #         Write-Host "Invalid TEMP dir PATH: $tempDir" -ForegroundColor Red
    #         exit 1
    #     }

    #     $dockerTemp = Join-Path -Path $tempDir -ChildPath "docker"
    #     Write-Host "Creating docker temp dir: $dockerTemp"
    #     New-Item -Path $dockerTemp -ItemType "directory" -Force -ErrorAction Stop
    #     if ($false -eq (Test-Path -Path $dockerTemp)) {
    #         Write-Host "Invalid dockerTemp: $tempDir" -ForegroundColor Red
    #         exit 1
    #     }

    #     $url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    #     $output = Join-Path -Path $dockerTemp -ChildPath "docker-desktop-installer.exe"
    #     Write-Host "Downloading Docker Desktop installer..."
    #     Invoke-WebRequest -Uri $url -OutFile $output -ErrorAction Stop
    #     Write-Host "Download completed"

    #     Write-Host "Installing Docker Desktop..."
    #     Start-Process $output -Wait -ArgumentList 'install', '--quiet', '--accept-license'
    #     Write-Host "Docker Desktop installation completed"
    # }
    
    # Write-Host "Configuring Docker PATH and verifying installation..."
    
    # $dockerPaths = @(
    #     "C:\Program Files\Docker\Docker\resources\bin",
    #     "C:\ProgramData\DockerDesktop\version-bin",
    #     "C:\Program Files\Docker\Docker\Resources\bin"
    # )
    
    # $dockerPathToAdd = $null
    # foreach ($path in $dockerPaths) {
    #     $dockerExe = Join-Path $path "docker.exe"
    #     if (Test-Path $dockerExe) {
    #         $dockerPathToAdd = $path
    #         Write-Host "SUCCESS: Found Docker at: $path" -ForegroundColor Green
    #         break
    #     }
    # }
    
    # if ($dockerPathToAdd) {
    #     $ProcessPathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "PROCESS")
    #     $UserPathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "USER")
    #     $MachinePathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "MACHINE")
        
    #     if ($MachinePathEnv -notlike "*$dockerPathToAdd*") {
    #         $MachinePathEnv = $MachinePathEnv + ";" + $dockerPathToAdd
    #         [System.Environment]::SetEnvironmentVariable("PATH", $MachinePathEnv, "MACHINE")
    #         Write-Host "SUCCESS: Added Docker to Machine PATH" -ForegroundColor Green
    #     }
        
    #     if ($ProcessPathEnv -notlike "*$dockerPathToAdd*") {
    #         $ProcessPathEnv = $ProcessPathEnv + ";" + $dockerPathToAdd
    #         [System.Environment]::SetEnvironmentVariable("PATH", $ProcessPathEnv, "PROCESS")
    #         Write-Host "SUCCESS: Added Docker to Process PATH" -ForegroundColor Green
    #     }
        
    #     $env:Path = $MachinePathEnv + ";" + $UserPathEnv
    # }
    
    # Write-Host "Verifying Docker installation..."
    # try {
    #     $dockerVersion = & docker --version 2>&1
    #     if ($LASTEXITCODE -eq 0) {
    #         Write-Host "SUCCESS: Docker verification successful: $dockerVersion" -ForegroundColor Green
    #     } else {
    #         Write-Host "WARNING: Docker installed but verification failed" -ForegroundColor Yellow
    #     }
    # } catch {
    #     Write-Host "WARNING: Docker installation may need manual configuration" -ForegroundColor Yellow
    # }
    
    # Write-Host "Docker installation and configuration completed" -ForegroundColor Green
}

function Install-Chocolatey() {
    Write-Host "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment variables to make choco available
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "Chocolatey installation completed"
}

function Install-CMake() {
    Write-Host "Installing CMake via Chocolatey..."
    choco install -y cmake
    
    # Refresh environment variables to make cmake available
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "CMake installation completed"
}

function Install-cmetrics() {
    Write-Host "Install-cmetrics function temporarily commented out"
    # Commented out to resolve PowerShell syntax errors
    # #Install flex and bison
    # choco install -y winflexbison3
    
    # #Install make (mingw32-make)
    # choco install -y mingw

    # $destinationPath = Join-Path -Path $env:SYSTEMDRIVE -ChildPath "cmetrics"
    # New-Item -Path $destinationPath -ItemType "directory" -Force -ErrorAction Stop
    
    # # Refresh PATH to include mingw make
    # $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # #Clone cmetrics repo and install cmetrics and all its dependencies
    # git clone --recursive https://github.com/calyptia/cmetrics.git
    # cd cmetrics
    # git checkout v0.6.0
    # git submodule sync
    # git -c protocol.version=2 submodule update --init --force --depth=1
    # git submodule foreach git config --local gc.auto 0
    
    # # Use cmake with minimum version flag to handle compatibility and use mingw32-make instead of make
    # cmake --fresh -G "MinGW Makefiles" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_INSTALL_PREFIX="$destinationPath" .
    # mingw32-make
    # mingw32-make install
}

# speed up Invoke-WebRequest
# https://stackoverflow.com/questions/28682642/powershell-why-is-using-invoke-webrequest-much-slower-than-a-browser-download
$ProgressPreference = 'SilentlyContinue'

Write-Host "Install GO 1.23.8 version"
Install-Go
Write-Host "Install Build dependencies"
Build-Dependencies

Write-Host "Install .NET 6.0 SDK"
Install-DotNetCoreSDK

#Write-Host "Install Docker"
#Install-Docker

Write-Host "Install Chocolatey"
Install-Chocolatey

#Write-Host "Install CMake"
#Install-CMake

#Write-Host "Install cmetrics library"
#Install-cmetrics

Write-Host "successfully installed required pre-requisites" -ForegroundColor Green
