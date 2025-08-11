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


ARG WINDOWS_VERSION=
FROM mcr.microsoft.com/windows/nanoserver:ltsc2025
# LABEL maintainer="OMSContainers@microsoft.com"
# LABEL vendor=Microsoft\ Corp \
#     com.microsoft.product="Azure Monitor for containers"


# # install performance monitor
# WORKDIR /install
# COPY ./fod/install-perf-monitor.cmd .
# USER ContainerAdministrator
# RUN install-perf-monitor.cmd
# USER ContainerUser


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


#RUN reg add "HKLM\Software\Microsoft\Cryptography\Wintrust\Config" /v "EnableCertPaddingCheck" /t REG_DWORD /d "1" /f
#RUN reg add "HKLM\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config" /v "EnableCertPaddingCheck" /t REG_DWORD /d "1" /f

# # Do not split this into multiple RUN!
# # Docker creates a layer for every RUN-Statement
# ENV chocolateyVersion 1.4.0
# RUN powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"


# # Original code: https://github.com/fluent/fluentd-docker-image/blob/master/v1.16/windows-ltsc2022/Dockerfile
# # rexml 3.2.5 gem was installed during ruby 3.1.1.1 installation for xml parsing, not related to fluentd (dependency of fluentd 1.16.3: https://rubygems.org/gems/fluentd/versions/1.16.3-x64-mingw-ucrt)
# # removed it for vulnerability reasons.
#     # https://github.com/ManageIQ/rbvmomi2/issues/62
#     # when ruby has a version change, a different version of rexml might be installed, 
#     # so need to review the installed version of rexml, and uninstall it.
# RUN choco install -y ruby --version 3.1.1.1 --params "'/InstallDir:C:\ruby31'" \
# && choco install -y msys2 --version 20240113.0.0 --params "'/NoPath /NoUpdate /InstallDir:C:\ruby31\msys64'"
# RUN refreshenv \
# && ridk install 3 \
# && echo gem: --no-document >> C:\ProgramData\gemrc \
# # Install fluentd and its dependencies
# && gem install oj -v 3.16.1 \
# && gem install fluentd -v 1.16.3 \
# && gem install win32-service -v 2.3.2 \
# && gem install win32-ipc -v 0.7.0 \
# && gem install win32-event -v 0.6.3 \
# # remove rexml gem to avoid vulnerability
# && gem uninstall rexml -v 3.2.5 --force \
# # remove net-imap gem as it has a known CVE (CVE-2025-43857) and is not used by the agent
# && gem uninstall net-imap --force \
# # The following gems are required for fluentd plugins, or ruby for configuration parsing
# && gem install windows-pr -v 1.2.6 \
# && gem install tomlrb -v 2.0.1 \
# && gem install gyoku -v 1.3.1 \
# && gem install ipaddress -v 0.8.3 \
# && gem install jwt -v 2.7.1 \
# && gem sources --clear-all

# # Remove gem cache and chocolatey
# RUN powershell -Command "Remove-Item -Force C:\ruby31\lib\ruby\gems\3.1.0\cache\*.gem; Remove-Item -Recurse -Force 'C:\ProgramData\chocolatey'; Remove-Item -Recurse -Force 'C:\Users\ContainerAdministrator\AppData\Local\Temp'"

#SHELL ["powershell"]

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

# Copy pre-generated environment variable files
#COPY ./cheat-env-files/setagentenv.txt /opt/amalogswindows/scripts/powershell/
#COPY ./cheat-env-files/setcommonagentenv.txt /opt/amalogswindows/scripts/powershell/
#COPY ./cheat-env-files/setenv.txt /opt/amalogswindows/scripts/powershell/
#COPY ./cheat-env-files/setgenevaconfigenv.txt /opt/amalogswindows/scripts/powershell/
#COPY ./cheat-env-files/setmdmenv.txt /opt/amalogswindows/scripts/powershell/
#COPY ./cheat-env-files/setpromenv.txt /opt/amalogswindows/scripts/powershell/

# Copy Go parser executable to /opt/amalogswindows/scripts/cmd/
#COPY ./agentparser/config-parser.exe /opt/amalogswindows/scripts/cmd/

# copy ruby scripts to /opt folder
COPY ./amalogswindows/installer/scripts/*.rb /opt/amalogswindows/scripts/ruby/

# # copy out_oms.so file
COPY ./amalogswindows/out_oms.so /opt/amalogswindows/out_oms.so
# COPY ./cheat-so-files/out_oms.so /opt/amalogswindows/out_oms.so

# # copy containerinventory.so and perf.so file
COPY ./amalogswindows/containerinventory.so /opt/fluent-bit/bin/containerinventory.so
# COPY ./cheat-so-files/containerinventory.so /opt/fluent-bit/bin/containerinventory.so

COPY ./amalogswindows/perf.so /opt/fluent-bit/bin/perf.so
# COPY ./cheat-so-files/perf.so /opt/fluent-bit/bin/perf.so

# copy fluent-bit binary
COPY ./cheat-fb-exe/fluent-bit.exe /opt/fluent-bit/bin/fluent-bit.exe

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

# # Delete unnecessary files
# RUN powershell -Command "Remove-Item -Recurse -Force 'C:\ruby31\share\doc\ruby\html\js'; \
# Remove-Item -Force 'C:\ruby31\ridk_use\ridk.ps1'; \
# Remove-Item -Recurse -Force 'C:\ruby31\msys64\usr\share\texinfo\js'; \
# Remove-Item -Force 'C:\ruby31\msys64\usr\share\terminfo\78\xterm.js'; \
# Remove-Item -Force 'C:\ruby31\msys64\usr\lib\terminfo\78\xterm.js'; \
# Remove-Item -Recurse -Force 'C:\ruby31\lib\ruby\3.1.0\rdoc\generator\template\json_index\js'; \
# Remove-Item -Recurse -Force 'C:\ruby31\lib\ruby\3.1.0\rdoc\generator\template\darkfish\js'; \
# Remove-Item -Force 'C:\ruby31\bin\ridk.ps1'"

#ENTRYPOINT ["powershell", "C:\\opt\\amalogswindows\\scripts\\powershell\\main.ps1"]
#ENTRYPOINT ["cmd.exe", "/K"]
#ENTRYPOINT ["C:\\PowerShell\\pwsh.exe", "-NoExit"]
USER ContainerAdministrator
ENTRYPOINT ["C:\\PowerShell\\pwsh.exe", "-File", "C:\\opt\\amalogswindows\\scripts\\powershell\\main.ps1"]
#COPY main_keep_alive.ps1 /opt/amalogswindows/scripts/powershell
#ENTRYPOINT ["C:\\PowerShell\\pwsh.exe", "-File", "C:\\opt\\amalogswindows\\scripts\\powershell\\main_keep_alive.ps1"]
