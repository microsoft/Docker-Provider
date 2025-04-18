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

# Copy standard C++ runtime DLLs
RUN Copy-Item -Path $env:windir\System32\msvcp140.dll -Destination C:\vcruntime
RUN Copy-Item -Path $env:windir\System32\vcruntime140.dll -Destination C:\vcruntime
RUN Copy-Item -Path $env:windir\System32\vccorlib140.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue

# Copy additional C++ runtime DLLs identified by the dependency analyzer
RUN Copy-Item -Path $env:windir\System32\vcruntime140_1.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\msvcp140_1.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\concrt140.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue

# Copy Universal CRT API forwarding DLLs
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-runtime-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-string-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-stdio-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-heap-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-convert-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-math-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-locale-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-time-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-filesystem-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-environment-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-process-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue
RUN Copy-Item -Path $env:windir\System32\api-ms-win-crt-utility-l1-1-0.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue

# Copy ucrtbase.dll which is the actual implementation of the Universal CRT
RUN Copy-Item -Path $env:windir\System32\ucrtbase.dll -Destination C:\vcruntime -ErrorAction SilentlyContinue

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

# Copy additional C++ runtime DLLs 
COPY --from=dll-extractor C:/vcruntime/vcruntime140_1.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/msvcp140_1.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/concrt140.dll C:/opt/fluent-bit/bin/

# Copy Universal CRT API forwarding DLLs
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-runtime-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-string-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-stdio-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-heap-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-convert-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-math-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-locale-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-time-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-filesystem-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-environment-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-process-l1-1-0.dll C:/opt/fluent-bit/bin/
COPY --from=dll-extractor C:/vcruntime/api-ms-win-crt-utility-l1-1-0.dll C:/opt/fluent-bit/bin/

# Copy ucrtbase.dll which is the actual implementation of the Universal CRT
COPY --from=dll-extractor C:/vcruntime/ucrtbase.dll C:/opt/fluent-bit/bin/

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