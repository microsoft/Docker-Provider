# Stage 1: Build Ruby installation on Server Core
FROM mcr.microsoft.com/windows/servercore:ltsc2025 AS ruby-builder

WORKDIR C:/build

# Download RubyInstaller, install Ruby, and add essential gems
RUN powershell -Command "\
    Write-Host 'Downloading RubyInstaller standalone...'; \
    $url = 'https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.1.1-1/rubyinstaller-3.1.1-1-x64.exe'; \
    Invoke-WebRequest -Uri $url -OutFile ruby-installer.exe; \
    Write-Host 'Installing Ruby from RubyInstaller...'; \
    Start-Process -FilePath 'ruby-installer.exe' -ArgumentList '/silent', '/dir=C:\ruby31' -Wait; \
    Remove-Item ruby-installer.exe; \
    Write-Host 'Installing gems...'; \
    $env:PATH = 'C:\ruby31\bin;C:\ruby31\bin\ruby_builtin_dlls;' + $env:PATH; \
    New-Item -ItemType Directory -Path 'C:\ruby31\etc' -Force -ErrorAction SilentlyContinue; \
    echo 'gem: --no-document' | Out-File -FilePath 'C:\ruby31\etc\gemrc' -Encoding UTF8; \
    & 'C:\ruby31\bin\gem.cmd' install tomlrb -v 2.0.1; \
    Write-Host 'Cleaning up...'; \
    Remove-Item -Recurse -Force 'C:\ruby31\share\doc' -ErrorAction SilentlyContinue; \
    Remove-Item -Recurse -Force 'C:\ruby31\share\man' -ErrorAction SilentlyContinue; \
    Remove-Item -Recurse -Force 'C:\ruby31\lib\ruby\gems\3.1.0\cache' -ErrorAction SilentlyContinue"

# Stage 2: Build Container Insights on Nano Server ltsc2025
ARG WINDOWS_VERSION=
FROM mcr.microsoft.com/windows/nanoserver:ltsc2025
# LABEL maintainer="OMSContainers@microsoft.com"
# LABEL vendor=Microsoft\ Corp \
#     com.microsoft.product="Azure Monitor for containers"


# install performance monitor
WORKDIR /install
COPY ./fod/install-perf-monitor.cmd .
USER ContainerAdministrator
RUN install-perf-monitor.cmd
USER ContainerUser


# Copy Ruby installation from builder stage
COPY --from=ruby-builder C:/ruby31 C:/ruby31
# Set up environment for Ruby
ENV PATH="C:\ruby31\bin;C:\ruby31\bin\ruby_builtin_dlls;C:\Windows\system32"


SHELL ["cmd", "/S", "/C"]
RUN mkdir C:\download
RUN mkdir C:\PowerShell
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

USER ContainerAdministrator
RUN reg add "HKLM\Software\Microsoft\Cryptography\Wintrust\Config" /v "EnableCertPaddingCheck" /t REG_DWORD /d "1" /f
RUN reg add "HKLM\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" /v "EnableCertPaddingCheck" /t REG_DWORD /d "1" /f
USER ContainerUser

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

# # copy out_oms.so file
COPY ./amalogswindows/out_oms.so /opt/amalogswindows/out_oms.so

# # copy containerinventory.so and perf.so file
COPY ./amalogswindows/containerinventory.so /opt/fluent-bit/bin/containerinventory.so

COPY ./amalogswindows/perf.so /opt/fluent-bit/bin/perf.so

# copy fluent-bit binary
# COPY ./cheat-fb-exe/fluent-bit.exe /opt/fluent-bit/bin/fluent-bit.exe

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
ARG IMAGE_TAG=win-3.1.27
ENV AGENT_VERSION ${IMAGE_TAG}

ENV OS_TYPE "windows"
ENV APPLICATIONINSIGHTS_AUTH "NzAwZGM5OGYtYTdhZC00NThkLWI5NWMtMjA3ZjM3NmM3YmRi"
ENV AZMON_COLLECT_ENV False
ENV CI_CERT_LOCATION "C://oms.crt"
ENV CI_KEY_LOCATION "C://oms.key"

USER ContainerAdministrator
ENTRYPOINT ["C:\\PowerShell\\pwsh.exe", "-File", "C:\\opt\\amalogswindows\\scripts\\powershell\\main.ps1"]
