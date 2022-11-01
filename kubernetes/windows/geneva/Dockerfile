# Supported values of windows version are ltsc2019 or ltsc2022 which are being passed by the build script or build pipeline
ARG WINDOWS_VERSION=
FROM mcr.microsoft.com/windows/servercore:${WINDOWS_VERSION}
MAINTAINER OMSContainers@microsoft.com
LABEL vendor=Microsoft\ Corp \
    com.microsoft.product="Azure Monitor for containers"

ARG IMAGE_TAG=win-ciprod10042022-3c05dd1b

SHELL ["powershell"]

ENV tmpdir /opt/amalogswindows/scripts/powershell

COPY setup.ps1 /opt/amalogswindows/scripts/powershell/setup.ps1
RUN ./opt/amalogswindows/scripts/powershell/setup.ps1

COPY main.ps1 /opt/amalogswindows/scripts/powershell/main.ps1

ENTRYPOINT ["powershell", ".\\opt\\amalogswindows\\scripts\\powershell\\main.ps1"]