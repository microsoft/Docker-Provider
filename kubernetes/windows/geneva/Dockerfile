# Supported values of windows version are ltsc2019 or ltsc2022 which are being passed by the build script or build pipeline
ARG WINDOWS_VERSION=
FROM mcr.microsoft.com/windows/servercore:${WINDOWS_VERSION}
MAINTAINER OMSContainers@microsoft.com
LABEL vendor=Microsoft\ Corp \
    com.microsoft.product="Azure Monitor for containers"

ARG IMAGE_TAG=win-ciprod10042022-3c05dd1b

# Do not split this into multiple RUN!
# Docker creates a layer for every RUN-Statement
RUN powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
# Fluentd depends on cool.io whose fat gem is only available for Ruby < 2.5, so need to specify --platform ruby when install Ruby > 2.5 and install msys2 to get dev tools
RUN choco install -y ruby --version 3.1.1.1 --params "'/InstallDir:C:\ruby31'" \
&& choco install -y msys2 --version 20211130.0.0 --params "'/NoPath /NoUpdate /InstallDir:C:\ruby31\msys64'" \
&& choco install -y vim

RUN refreshenv \
&& ridk install 3 \
&& echo gem: --no-document >> C:\ProgramData\gemrc \
&& gem install tomlrb -v 2.0.1 \
&& gem sources --clear-all

# Remove gem cache and chocolatey
RUN powershell -Command "Remove-Item -Force C:\ruby31\lib\ruby\gems\3.1.0\cache\*.gem; Remove-Item -Recurse -Force 'C:\ProgramData\chocolatey'"

SHELL ["powershell"]

ENV tmpdir /opt/amalogswindows/scripts/powershell

COPY setup.ps1 /opt/amalogswindows/scripts/powershell/setup.ps1
RUN ./opt/amalogswindows/scripts/powershell/setup.ps1

# copy ruby scripts to /opt folder
COPY ./amalogswindows/installer/scripts/*.rb /opt/amalogswindows/scripts/ruby/

COPY main.ps1 /opt/amalogswindows/scripts/powershell/main.ps1
COPY ./amalogswindows/installer/scripts/filesystemwatcher.ps1 /opt/amalogswindows/scripts/powershell
COPY ./amalogswindows/installer/livenessprobe/livenessprobe.exe /opt/amalogswindows/scripts/cmd/

ENTRYPOINT ["powershell", ".\\opt\\amalogswindows\\scripts\\powershell\\main.ps1"]