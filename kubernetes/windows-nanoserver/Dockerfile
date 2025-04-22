# Multi-stage build for Windows log agent on Nano Server
ARG WINDOWS_VERSION=ltsc2022

# First stage - Download and extract required DLLs
FROM mcr.microsoft.com/windows/servercore:${WINDOWS_VERSION} AS dll-extractor
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Download and install Visual C++ Redistributable
RUN $vcRedistLocation = 'https://aka.ms/vs/16/release/vc_redist.x64.exe'; \
    $vcInstallerLocation = 'C:\vc_redist.x64.exe'; \
    $vcArgs = '/install /quiet /norestart'; \
    Invoke-WebRequest -Uri $vcRedistLocation -OutFile $vcInstallerLocation; \
    Start-Process $vcInstallerLocation -ArgumentList $vcArgs -NoNewWindow -Wait;

# Create a directory to store the DLLs
WORKDIR C:/vcruntime

# Copy standard C++ runtime DLLs - ONLY copy these three DLLs
RUN Copy-Item -Path $env:windir\System32\msvcp140.dll -Destination C:\vcruntime
RUN Copy-Item -Path $env:windir\System32\vcruntime140.dll -Destination C:\vcruntime
RUN Copy-Item -Path $env:windir\System32\vccorlib140.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue

# Download PowerShell Core for nano server - fixing string quotes issue
RUN $powershellVersion = '7.3.4'; \
    $architecture = 'win-x64'; \
    $powershellPackage = 'PowerShell-' + $powershellVersion + '-' + $architecture + '.zip'; \
    $downloadUrl = 'https://github.com/PowerShell/PowerShell/releases/download/v' + $powershellVersion + '/' + $powershellPackage; \
    Invoke-WebRequest -Uri $downloadUrl -OutFile C:\$powershellPackage; \
    Expand-Archive -Path C:\$powershellPackage -DestinationPath C:\PowerShell; \
    Remove-Item -Path C:\$powershellPackage -Force

# Final Nano Server stage
FROM mcr.microsoft.com/windows/nanoserver:${WINDOWS_VERSION}

LABEL maintainer="OMSContainers@microsoft.com"
LABEL vendor=Microsoft\ Corp \
    com.microsoft.product="Azure Monitor for containers - Nano Server POC"

# Create directories for Fluent Bit
RUN mkdir C:\opt\fluent-bit\bin

# Copy standard C++ runtime DLLs
COPY --from=dll-extractor C:/vcruntime/msvcp140.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/vcruntime140.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/vccorlib140.dll C:/opt/fluent-bit/bin/

# Copy PowerShell Core from the first stage
COPY --from=dll-extractor C:/PowerShell C:/PowerShell

# Create directories using CMD shell first
SHELL ["cmd", "/S", "/C"]
RUN mkdir C:\opt\amalogswindows\scripts

# Copy scripts from local directory to the container
COPY setup.ps1 C:/opt/amalogswindows/scripts/
COPY start.ps1 C:/opt/amalogswindows/scripts/
COPY analyze-dependencies.ps1 C:/opt/amalogswindows/scripts/

# Switch to PowerShell - use full path since it's not in PATH yet
SHELL ["C:\\PowerShell\\pwsh.exe", "-Command"]

# Debug: Verify the scripts were copied correctly
RUN Write-Host "Checking if setup script exists:"; \
    if (Test-Path -Path C:\opt\amalogswindows\scripts\setup.ps1) { \
        Write-Host "setup.ps1 found"; \
        Get-Content -Path C:\opt\amalogswindows\scripts\setup.ps1 | Select-Object -First 3; \
    } else { \
        Write-Host "setup.ps1 NOT found"; \
        Get-ChildItem -Path C:\opt\amalogswindows\scripts\; \
    }

# Add PowerShell to the PATH
ENV PATH="C:\PowerShell;${PATH}"

# Run setup.ps1
RUN & C:\opt\amalogswindows\scripts\setup.ps1

# Set environment variables - Important: Add Fluent Bit bin directory to PATH
ENV OS_TYPE="windows" \
    CONTAINER_RUNTIME="containerd" \
    PATH="C:\opt\fluent-bit\bin;C:\PowerShell;${PATH}"

WORKDIR C:/opt/amalogswindows/scripts

# Start Fluent Bit when the container starts
ENTRYPOINT ["C:\\PowerShell\\pwsh.exe", "-Command", "& { C:\\opt\\amalogswindows\\scripts\\start.ps1 }"]