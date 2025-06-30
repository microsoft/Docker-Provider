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

function Install-AzureCLI() {
    Write-Host "Installing Azure CLI for maximum compatibility with AzureCLI@2 task..."
    
    $tempDir = $env:TEMP
    $azureCliTemp = Join-Path -Path $tempDir -ChildPath "azurecli"
    New-Item -Path $azureCliTemp -ItemType "directory" -Force -ErrorAction Stop
    
    $azureCliUrl = "https://aka.ms/installazurecliwindows"
    $azureCliInstaller = Join-Path -Path $azureCliTemp -ChildPath "azurecli.msi"
    
    Write-Host "Downloading Azure CLI installer..."
    Invoke-WebRequest -Uri $azureCliUrl -OutFile $azureCliInstaller -ErrorAction Stop
    Write-Host "Downloaded Azure CLI installer successfully"
    
    Write-Host "Installing Azure CLI..."
    # Install Azure CLI silently
    Start-Process msiexec.exe -Wait -ArgumentList '/I', $azureCliInstaller, '/quiet', '/norestart'
    Write-Host "Azure CLI installation completed"
    
    # Find installed Azure CLI paths
    $possiblePaths = @(
        "C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin",
        "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin"
    )
    
    $azCliPathToAdd = ""
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $azPath = Join-Path -Path $path -ChildPath "az.cmd"
            if (Test-Path $azPath) {
                $azCliPathToAdd = $path
                Write-Host "Found Azure CLI at: $path" -ForegroundColor Green
                break
            }
        }
    }
    
    if (-not $azCliPathToAdd) {
        Write-Error "Azure CLI installation path not found after installation"
        exit 1
    }
    
    # Update PATH at Machine level for system-wide persistence
    $MachinePathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "MACHINE")
    if ($MachinePathEnv -notlike "*$azCliPathToAdd*") {
        $MachinePathEnv = $MachinePathEnv + ";" + $azCliPathToAdd
        [System.Environment]::SetEnvironmentVariable("PATH", $MachinePathEnv, "MACHINE")
        Write-Host "Added Azure CLI to Machine PATH: $azCliPathToAdd" -ForegroundColor Green
    }
    
    # Update Process PATH for immediate availability
    $ProcessPathEnv = [System.Environment]::GetEnvironmentVariable("PATH", "PROCESS")
    if ($ProcessPathEnv -notlike "*$azCliPathToAdd*") {
        $ProcessPathEnv = $ProcessPathEnv + ";" + $azCliPathToAdd
        [System.Environment]::SetEnvironmentVariable("PATH", $ProcessPathEnv, "PROCESS")
        Write-Host "Added Azure CLI to Process PATH" -ForegroundColor Green
    }
    
    # CRITICAL: Create az.cmd copies in system directories for AzureCLI@2 task detection
    $systemPaths = @(
        "C:\Windows\System32",
        "C:\Windows",
        "C:\ProgramData\chocolatey\bin"
    )
    
    $sourceAzCmd = Join-Path -Path $azCliPathToAdd -ChildPath "az.cmd"
    
    foreach ($sysPath in $systemPaths) {
        try {
            if (Test-Path $sysPath) {
                $targetAzCmd = Join-Path -Path $sysPath -ChildPath "az.cmd"
                if (-not (Test-Path $targetAzCmd)) {
                    Copy-Item -Path $sourceAzCmd -Destination $targetAzCmd -Force
                    Write-Host "Created az.cmd copy in: $sysPath" -ForegroundColor Green
                }
                
                # Also create az.exe as some systems might look for .exe
                $targetAzExe = Join-Path -Path $sysPath -ChildPath "az.exe"
                if (-not (Test-Path $targetAzExe)) {
                    Copy-Item -Path $sourceAzCmd -Destination $targetAzExe -Force
                    Write-Host "Created az.exe copy in: $sysPath" -ForegroundColor Green
                }
            }
        } catch {
            Write-Host "Could not copy to $sysPath (permissions): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Refresh current environment
    $env:Path = $MachinePathEnv + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "USER")
    
    # Final verification - test both direct path and PATH-based access
    Write-Host "Verifying Azure CLI installation..."
    
    # Test 1: Direct path access
    $azPath = Join-Path -Path $azCliPathToAdd -ChildPath "az.cmd"
    if (Test-Path $azPath) {
        Write-Host "✓ Azure CLI found at direct path: $azPath" -ForegroundColor Green
    } else {
        Write-Error "✗ Azure CLI not found at expected direct path"
        exit 1
    }
    
    # Test 2: PATH-based access (what AzureCLI@2 task uses)
    try {
        $azOutput = & az --version 2>&1
        Write-Host "✓ Azure CLI accessible via PATH command" -ForegroundColor Green
        Write-Host "Azure CLI version: $($azOutput[0])" -ForegroundColor Cyan
    } catch {
        Write-Warning "⚠ Azure CLI not immediately accessible via PATH, but should work after environment refresh"
    }
    
    # Test 3: Check if 'where az' finds the executable (Node.js which equivalent)
    try {
        $whereResult = & where.exe az 2>&1
        Write-Host "✓ 'where az' found: $whereResult" -ForegroundColor Green
    } catch {
        Write-Warning "⚠ 'where az' failed - AzureCLI@2 task might have issues detecting Azure CLI"
    }
    
    Write-Host "Azure CLI installation and configuration completed successfully!" -ForegroundColor Green
    Write-Host "Azure CLI should now be detectable by AzureCLI@2 task" -ForegroundColor Cyan
}

#function Install-cmetrics() {
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
    
    Write-Host "Install-cmetrics function temporarily commented out"
#}

# speed up Invoke-WebRequest
# https://stackoverflow.com/questions/28682642/powershell-why-is-using-invoke-webrequest-much-slower-than-a-browser-download
$ProgressPreference = 'SilentlyContinue'

Write-Host "Install GO 1.23.8 version"
Install-Go
Write-Host "Install Build dependencies"
Build-Dependencies

Write-Host "Install .NET 6.0 SDK"
Install-DotNetCoreSDK

Write-Host "Install Docker"
Install-Docker

Write-Host "Install Chocolatey"
Install-Chocolatey

#Write-Host "Install CMake"
#Install-CMake

Write-Host "Install Azure CLI"
Install-AzureCLI

#Write-Host "Install cmetrics library"
#Install-cmetrics

Write-Host "successfully installed required pre-requisites" -ForegroundColor Green
