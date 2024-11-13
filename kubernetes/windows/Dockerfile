# Supported values of windows version are ltsc2019 or ltsc2022 which are being passed by the build script or build pipeline
ARG WINDOWS_VERSION=
FROM mcr.microsoft.com/windows/servercore:${WINDOWS_VERSION}
LABEL maintainer="OMSContainers@microsoft.com"
LABEL vendor=Microsoft\ Corp \
    com.microsoft.product="Azure Monitor for containers"

RUN reg add "HKLM\Software\Microsoft\Cryptography\Wintrust\Config" /v "EnableCertPaddingCheck" /t REG_DWORD /d "1" /f
RUN reg add "HKLM\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" /v "EnableCertPaddingCheck" /t REG_DWORD /d "1" /f

# Do not split this into multiple RUN!
# Docker creates a layer for every RUN-Statement
# Set the Chocolatey version
ENV chocolateyVersion 1.4.0

# Install Chocolatey
RUN powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"

# Install Ruby and MSYS2 using Chocolatey with specified install directories
RUN choco install -y ruby --version 3.1.1.1 --params "'/InstallDir:C:\ruby31'" && \
    choco install -y msys2 --version 20211130.0.0 --params "'/NoPath /NoUpdate /InstallDir:C:\ruby31\msys64'"

# Set environment variables for paths
RUN setx PATH "%PATH%;C:\ruby31\bin;C:\ruby31\msys64\usr\bin"

# Refresh environment and set up MSYS2 mirrors and retry logic for gem installs
SHELL ["powershell", "-Command"]

RUN Write-Output "Configuring MSYS2 mirrors..." ; \
    $MirrorFileMsys = 'C:\ruby31\msys64\etc\pacman.d\mirrorlist.msys' ; \
    $MirrorFileMingw = 'C:\ruby31\msys64\etc\pacman.d\mirrorlist.mingw' ; \
    (Get-Content $MirrorFileMsys) -replace '^(Server = .*)$', '#$1' | Set-Content $MirrorFileMsys ; \
    (Get-Content $MirrorFileMingw) -replace '^(Server = .*)$', '#$1' | Set-Content $MirrorFileMingw ; \
    Add-Content -Path $MirrorFileMsys -Value 'Server = https://repo.msys2.org/msys/$arch' ; \
    Add-Content -Path $MirrorFileMingw -Value 'Server = https://repo.msys2.org/mingw/$arch' ; \
    Start-Process 'C:\ruby31\msys64\usr\bin\bash.exe' -ArgumentList '-c', 'pacman -Syuu --noconfirm' -NoNewWindow -Wait

# Install required gems with retry logic for network stability
RUN Write-Output 'Installing Ruby gems with retry logic...'; \
    function Install-GemWithRetry { \
        param([string]$gemName, [string]$version, [int]$retries = 5); \
        for ($i = 0; $i -lt $retries; $i++) { \
            if (gem install $gemName -v $version --no-document --platform ruby) { break } else { \
            Write-Output 'Failed to install $gemName. Retrying in 5 seconds... ($($i+1)/$retries)'; \
            Start-Sleep -Seconds 5; } \
        }; \
        if (-not (gem list -i $gemName -v $version)) { throw 'Failed to install $gemName after $retries attempts.' }; \
    }; \
    Install-GemWithRetry -gemName 'cool.io' -version '1.7.1'; \
    Install-GemWithRetry -gemName 'oj' -version '3.3.10'; \
    Install-GemWithRetry -gemName 'fluentd' -version '1.16.3'; \
    Install-GemWithRetry -gemName 'win32-service' -version '1.0.1'; \
    Install-GemWithRetry -gemName 'win32-ipc' -version '0.7.0'; \
    Install-GemWithRetry -gemName 'win32-event' -version '0.6.3'; \
    Install-GemWithRetry -gemName 'windows-pr' -version '1.2.6'; \
    Install-GemWithRetry -gemName 'tomlrb' -version '2.0.1'; \
    Install-GemWithRetry -gemName 'gyoku' -version '1.3.1'; \
    Install-GemWithRetry -gemName 'ipaddress' -version '0.8.3'; \
    Install-GemWithRetry -gemName 'jwt' -version '2.7.1'; \
    gem sources --clear-all

# Optional: Run `ridk install` to add MSYS2 dev tools (optional if MSYS2 update fails)
RUN refreshenv && \
    ridk install 3 && \
    echo gem: --no-document >> C:\ProgramData\gemrc

# Remove gem cache and chocolatey
RUN powershell -Command "Remove-Item -Force C:\ruby31\lib\ruby\gems\3.1.0\cache\*.gem; Remove-Item -Recurse -Force 'C:\ProgramData\chocolatey'; Remove-Item -Recurse -Force 'C:\Users\ContainerAdministrator\AppData\Local\Temp'"

SHELL ["powershell"]

ENV tmpdir /opt/amalogswindows/scripts/powershell
ARG WINDOWS_AMA_URL=
ENV WINDOWS_AMA_URL_NEW ${WINDOWS_AMA_URL}
ENV COMPlus_ThreadPool_UnfairSemaphoreSpinLimit 0

WORKDIR /opt/amalogswindows/scripts/powershell

# copy certificate generator binaries zip
COPY ./amalogswindows/*.zip /opt/amalogswindows/

COPY setup.ps1 /opt/amalogswindows/scripts/powershell
RUN ./setup.ps1

COPY main.ps1 /opt/amalogswindows/scripts/powershell
COPY ./amalogswindows/installer/scripts/filesystemwatcher.ps1 /opt/amalogswindows/scripts/powershell
COPY ./amalogswindows/installer/livenessprobe/livenessprobe.exe /opt/amalogswindows/scripts/cmd/
COPY setdefaulttelegrafenvvariables.ps1 /opt/amalogswindows/scripts/powershell

# copy ruby scripts to /opt folder
COPY ./amalogswindows/installer/scripts/*.rb /opt/amalogswindows/scripts/ruby/

# copy out_oms.so file
COPY ./amalogswindows/out_oms.so /opt/amalogswindows/out_oms.so

# copy containerinventory.so and perf.so file
COPY ./amalogswindows/containerinventory.so /opt/fluent-bit/bin/containerinventory.so
COPY ./amalogswindows/perf.so /opt/fluent-bit/bin/perf.so

# copy fluent, fluent-bit and out_oms conf files
COPY ./amalogswindows/installer/conf/fluent.conf /etc/fluent/
COPY ./amalogswindows/installer/conf/fluent-cm.conf /etc/fluent/
COPY ./amalogswindows/installer/conf/fluent-bit.conf /etc/fluent-bit
COPY ./amalogswindows/installer/conf/azm-containers-parser.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/azm-containers-parser-multiline.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/azm-containers-input-plugins.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/out_oms.conf /etc/amalogswindows
COPY ./amalogswindows/installer/conf/fluent-bit-geneva-logs_*.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/fluent-bit-geneva.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/fluent-bit-common.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/fluent-bit-internal-metrics.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/fluent-bit-input.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/fluent-bit-telegraf-tcp.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/fluent-bit-azmon-logs_*.conf /etc/fluent-bit/
COPY ./amalogswindows/installer/conf/fluent-bit-azmon-multi-tenancy.conf /etc/fluent-bit/

# copy telegraf conf file
COPY ./amalogswindows/installer/conf/telegraf.conf /etc/telegraf/

# copy keepcert alive ruby scripts
COPY ./amalogswindows/installer/scripts/rubyKeepCertificateAlive/*.rb /etc/fluent/plugin/

#Copy fluentd ruby plugins
COPY ./amalogswindows/ruby/ /etc/fluent/plugin/

# default value will be overwritten by pipeline
ARG IMAGE_TAG=win-3.1.23
ENV AGENT_VERSION ${IMAGE_TAG}

ENV OS_TYPE "windows"
ENV APPLICATIONINSIGHTS_AUTH "NzAwZGM5OGYtYTdhZC00NThkLWI5NWMtMjA3ZjM3NmM3YmRi"
ENV AZMON_COLLECT_ENV False
ENV CI_CERT_LOCATION "C://oms.crt"
ENV CI_KEY_LOCATION "C://oms.key"

# Delete unnecessary files
RUN powershell -Command "Remove-Item -Recurse -Force 'C:\ruby31\share\doc\ruby\html\js'; \
Remove-Item -Force 'C:\ruby31\ridk_use\ridk.ps1'; \
Remove-Item -Recurse -Force 'C:\ruby31\msys64\usr\share\texinfo\js'; \
Remove-Item -Force 'C:\ruby31\msys64\usr\share\terminfo\78\xterm.js'; \
Remove-Item -Force 'C:\ruby31\msys64\usr\lib\terminfo\78\xterm.js'; \
Remove-Item -Recurse -Force 'C:\ruby31\lib\ruby\3.1.0\rdoc\generator\template\json_index\js'; \
Remove-Item -Recurse -Force 'C:\ruby31\lib\ruby\3.1.0\rdoc\generator\template\darkfish\js'; \
Remove-Item -Force 'C:\ruby31\bin\ridk.ps1'"

ENTRYPOINT ["powershell", "C:\\opt\\amalogswindows\\scripts\\powershell\\main.ps1"]
