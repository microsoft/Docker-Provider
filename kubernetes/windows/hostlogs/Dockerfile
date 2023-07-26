# Supported values of windows version are ltsc2019 or ltsc2022 which are being passed by the build script or build pipeline
ARG WINDOWS_VERSION=
FROM mcr.microsoft.com/windows/servercore:${WINDOWS_VERSION}
MAINTAINER OMSContainers@microsoft.com
LABEL vendor=Microsoft\ Corp \
    com.microsoft.product="Azure Monitor for containers"

ARG IMAGE_TAG=0.1.0

ENV chocolateyVersion 1.4.0
RUN powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
RUN choco install -y ruby --version 3.1.1.1 --params "'/InstallDir:C:\ruby31'" \
&& choco install -y msys2 --version 20211130.0.0 --params "'/NoPath /NoUpdate /InstallDir:C:\ruby31\msys64'"

RUN refreshenv \
&& ridk install 3 \
&& echo gem: --no-document >> C:\ProgramData\gemrc \
&& gem install tomlrb -v 2.0.1 \
&& gem sources --clear-all

# Remove gem cache and chocolatey
RUN powershell -Command "Remove-Item -Force C:\ruby31\lib\ruby\gems\3.1.0\cache\*.gem; Remove-Item -Recurse -Force 'C:\ProgramData\chocolatey'"

SHELL ["powershell"]

ENV tmpdir /opt/hostlogswindows/scripts/powershell

COPY setup.ps1 /opt/hostlogswindows/scripts/powershell/setup.ps1
RUN ./opt/hostlogswindows/scripts/powershell/setup.ps1

# copy ruby scripts to /opt folder
COPY ./hostlogswindows/installer/scripts/*.rb /opt/hostlogswindows/scripts/ruby/

COPY main.ps1 /opt/hostlogswindows/scripts/powershell/main.ps1
COPY ./hostlogswindows/installer/scripts/filesystemwatcher.ps1 /opt/hostlogswindows/scripts/powershell
COPY ./hostlogswindows/installer/livenessprobe/livenessprobe.exe /opt/hostlogswindows/scripts/cmd/

ENTRYPOINT ["powershell", ".\\opt\\hostlogswindows\\scripts\\powershell\\main.ps1"]