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

# Copy the installed DLLs to our directory - each one in a separate RUN command
RUN Copy-Item -Path $env:windir\System32\msvcp140.dll -Destination C:\vcruntime
RUN Copy-Item -Path $env:windir\System32\vcruntime140.dll -Destination C:\vcruntime

# Create and prepare the scripts directory in the first stage
WORKDIR C:/build-scripts
COPY setup.ps1 .
COPY start.ps1 .

# Final Nano Server stage
FROM mcr.microsoft.com/windows/nanoserver:${WINDOWS_VERSION}

LABEL maintainer="OMSContainers@microsoft.com"
LABEL vendor=Microsoft\ Corp \
    com.microsoft.product="Azure Monitor for containers - Nano Server POC"

# Copy the VC++ DLLs from the first stage - using direct file paths for each one
COPY --from=dll-extractor C:/vcruntime/msvcp140.dll C:/Windows/System32/
COPY --from=dll-extractor C:/vcruntime/vcruntime140.dll C:/Windows/System32/

# Create directories in Nano Server using CMD
USER ContainerAdministrator
SHELL ["cmd", "/S", "/C"]
RUN mkdir C:\opt\amalogswindows\scripts
RUN dir C:\Windows\System32\pwsh.exe

# Copy scripts
COPY --from=dll-extractor C:/build-scripts/setup.ps1 C:/opt/amalogswindows/scripts/
COPY --from=dll-extractor C:/build-scripts/start.ps1 C:/opt/amalogswindows/scripts/

# Now try using PowerShell Core
SHELL ["C:\\Windows\\System32\\pwsh.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Run setup.ps1 to create directory structure and install Fluent Bit
RUN & C:\opt\amalogswindows\scripts\setup.ps1

# Set environment variables
ENV OS_TYPE="windows" \
    CONTAINER_RUNTIME="containerd" \
    PATH="C:\opt\fluent-bit\bin;${PATH}"

WORKDIR C:/opt/amalogswindows/scripts

# Start Fluent Bit when the container starts
ENTRYPOINT ["C:\\Windows\\System32\\pwsh.exe", "-Command", "& { C:\\opt\\amalogswindows\\scripts\\start.ps1 }"]