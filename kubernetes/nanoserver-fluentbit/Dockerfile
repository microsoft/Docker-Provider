# Simplified Dockerfile for Windows log agent on Nano Server
ARG WINDOWS_VERSION=ltsc2022

FROM mcr.microsoft.com/windows/nanoserver:${WINDOWS_VERSION}

LABEL maintainer="OMSContainers@microsoft.com"
LABEL vendor=Microsoft\ Corp \
    com.microsoft.product="Azure Monitor for containers - Nano Server POC"

# Create directories using CMD shell
SHELL ["cmd", "/S", "/C"]
RUN mkdir C:\opt\fluent-bit\bin
RUN mkdir C:\opt\amalogswindows\scripts
RUN mkdir C:\PowerShell
RUN mkdir C:\download

# Copy scripts from local directory to the container
COPY setup.ps1 C:/opt/amalogswindows/scripts/
COPY start.ps1 C:/opt/amalogswindows/scripts/
COPY analyze-dependencies.ps1 C:/opt/amalogswindows/scripts/

# Download PowerShell Core directly in Nano Server using curl (which is available in Nano Server)
# Define PowerShell version and download URL
ENV POWERSHELL_VERSION=7.3.4 \
    POWERSHELL_PACKAGE=PowerShell-7.3.4-win-x64.zip \
    DOWNLOAD_URL=https://github.com/PowerShell/PowerShell/releases/download/v7.3.4/PowerShell-7.3.4-win-x64.zip

# Download PowerShell using curl and extract it
RUN curl.exe -L -o C:\download\%POWERSHELL_PACKAGE% %DOWNLOAD_URL% && \
    tar.exe -xf C:\download\%POWERSHELL_PACKAGE% -C C:\PowerShell && \
    del C:\download\%POWERSHELL_PACKAGE%

# Add PowerShell to the PATH
ENV PATH="C:\PowerShell;${PATH}"

# Switch to PowerShell for remaining commands
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

# Run setup.ps1
RUN & C:\opt\amalogswindows\scripts\setup.ps1

# Set environment variables - Important: Add Fluent Bit bin directory to PATH
ENV OS_TYPE="windows" \
    CONTAINER_RUNTIME="containerd" \
    PATH="C:\opt\fluent-bit\bin;C:\PowerShell;${PATH}"

WORKDIR C:/opt/amalogswindows/scripts

# Start Fluent Bit when the container starts
ENTRYPOINT ["C:\\PowerShell\\pwsh.exe", "-Command", "& { C:\\opt\\amalogswindows\\scripts\\start.ps1 }"]