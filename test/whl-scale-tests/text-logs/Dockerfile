ARG WINDOWS_VERSION=
FROM mcr.microsoft.com/windows/servercore:${WINDOWS_VERSION}
LABEL maintainer="OMSContainers@microsoft.com" \
      vendor="Microsoft Corp" \
      com.microsoft.product="Azure Monitor for containers"

COPY ./main.ps1 /host-logs/test/textlogs/main.ps1

ENTRYPOINT ["powershell", ".\\host-logs\\test\\textlogs\\main.ps1"]