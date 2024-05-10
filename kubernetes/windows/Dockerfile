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
ENV chocolateyVersion 1.4.0
RUN powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
# Fluentd depends on cool.io whose fat gem is only available for Ruby < 2.5, so need to specify --platform ruby when install Ruby > 2.5 and install msys2 to get dev tools
RUN choco install -y ruby --version 3.1.1.1 --params "'/InstallDir:C:\ruby31'" \
&& choco install -y msys2 --version 20211130.0.0 --params "'/NoPath /NoUpdate /InstallDir:C:\ruby31\msys64'"

# gangams - optional MSYS2 update via ridk failing in merged docker file so skipping that since we dont need optional update
RUN refreshenv \
&& ridk install 3 \
&& echo gem: --no-document >> C:\ProgramData\gemrc \
&& gem install cool.io -v 1.7.1 --platform ruby \
&& gem install oj -v 3.3.10 \
&& gem install fluentd -v 1.16.3 \
&& gem install win32-service -v 1.0.1 \
&& gem install win32-ipc -v 0.7.0 \
&& gem install win32-event -v 0.6.3 \
&& gem install windows-pr -v 1.2.6 \
&& gem install tomlrb -v 2.0.1 \
&& gem install gyoku -v 1.3.1 \
&& gem install ipaddress -v 0.8.3 \
&& gem install jwt -v 2.7.1 \
&& gem sources --clear-all

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


# copy telegraf conf file
COPY ./amalogswindows/installer/conf/telegraf.conf /etc/telegraf/

# copy keepcert alive ruby scripts
COPY ./amalogswindows/installer/scripts/rubyKeepCertificateAlive/*.rb /etc/fluent/plugin/

#Copy fluentd ruby plugins
COPY ./amalogswindows/ruby/ /etc/fluent/plugin/

# default value will be overwritten by pipeline
ARG IMAGE_TAG=win-3.1.19
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
