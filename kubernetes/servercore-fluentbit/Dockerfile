# Dockerfile for Windows log agent on Server Core
ARG WINDOWS_VERSION=ltsc2022

# Using Server Core as the base image
FROM mcr.microsoft.com/windows/servercore:${WINDOWS_VERSION}

LABEL maintainer="OMSContainers@microsoft.com"
LABEL vendor=Microsoft\ Corp \
    com.microsoft.product="Azure Monitor for containers - Server Core"

# First use CMD shell to ensure directory creation works properly
SHELL ["cmd", "/S", "/C"]
RUN mkdir C:\opt\fluent-bit\bin
RUN mkdir C:\etc\fluent-bit
RUN mkdir C:\opt\amalogswindows\scripts
RUN mkdir C:\opt\amalogswindows\state
RUN mkdir C:\opt\amalogswindows\state\ContainerInventory

# Switch to PowerShell for more complex operations - using full path
SHELL ["C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Debug: Display PowerShell version and path for troubleshooting
RUN Write-Host "PowerShell Version Info:"; \
    $PSVersionTable; \
    Write-Host "PowerShell Location:"; \
    Get-Command powershell | Format-List *; \
    Write-Host "System Path:"; \
    $env:Path

# Download and install Visual C++ Redistributable if needed
# Server Core already includes most of the required libraries
#RUN $vcRedistLocation = 'https://aka.ms/vs/16/release/vc_redist.x64.exe'; \
#    $vcInstallerLocation = 'C:\vc_redist.x64.exe'; \
#    $vcArgs = '/install /quiet /norestart'; \
#    Invoke-WebRequest -Uri $vcRedistLocation -OutFile $vcInstallerLocation; \
#    Start-Process $vcInstallerLocation -ArgumentList $vcArgs -NoNewWindow -Wait; \
#    Remove-Item -Path $vcInstallerLocation -Force

# Copy scripts from local directory to the container
COPY setup.ps1 C:/opt/amalogswindows/scripts/
COPY start.ps1 C:/opt/amalogswindows/scripts/
COPY analyze-dependencies.ps1 C:/opt/amalogswindows/scripts/

# Debug: Verify the scripts were copied correctly
RUN Write-Host "Checking if scripts exist:"; \
    if (Test-Path -Path C:\opt\amalogswindows\scripts\setup.ps1) { \
        Write-Host "setup.ps1 found"; \
        Get-Content -Path C:\opt\amalogswindows\scripts\setup.ps1 | Select-Object -First 3; \
    } else { \
        Write-Host "setup.ps1 NOT found"; \
        Get-ChildItem -Path C:\opt\amalogswindows\scripts\; \
    }; \
    if (Test-Path -Path C:\opt\amalogswindows\scripts\start.ps1) { \
        Write-Host "start.ps1 found"; \
        Get-Content -Path C:\opt\amalogswindows\scripts\start.ps1 | Select-Object -First 3; \
    } else { \
        Write-Host "start.ps1 NOT found"; \
    }

# Run setup.ps1
RUN & C:\opt\amalogswindows\scripts\setup.ps1

# Set environment variables
ENV OS_TYPE="windows" \
    CONTAINER_RUNTIME="containerd" \
    PATH="C:\opt\fluent-bit\bin;C:\Windows\System32\WindowsPowerShell\v1.0;${PATH}"

WORKDIR C:/opt/amalogswindows/scripts

# Use direct full path to PowerShell executable to avoid path issues
ENTRYPOINT ["cmd", "/S", "/C", "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -ExecutionPolicy Bypass -File C:\\opt\\amalogswindows\\scripts\\start.ps1"]