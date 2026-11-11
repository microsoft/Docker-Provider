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


RUN powershell -Command "$ErrorActionPreference = 'Stop'; $rubyPackages = choco search ruby --all-versions --exact --limit-output; if ($LASTEXITCODE -ne 0) { throw 'Unable to query Ruby versions' }; $rubyVersion = $rubyPackages | ForEach-Object { if ($_ -match '^ruby\|(3(?:\.\d+){1,3})$') { [version]$Matches[1] } } | Sort-Object -Descending | Select-Object -First 1; if (-not $rubyVersion) { throw 'No stable Ruby 3 package found' }; Write-Host ('Installing latest Ruby 3 package: ' + $rubyVersion); choco install -y ruby --version $rubyVersion --params '/InstallDir:C:\ruby'; if ($LASTEXITCODE -ne 0) { throw 'Ruby installation failed' }"
RUN choco install -y msys2 --version 20240113.0.0 --params "'/NoPath /NoUpdate /InstallDir:C:\ruby\msys64'"
RUN refreshenv \
&& ridk install 3 \
&& echo gem: --no-document >> C:\ProgramData\gemrc \
# Install fluentd and its dependencies
&& gem install oj -v 3.16.1 \
&& gem install fluentd -v 1.16.3 \
&& gem install win32-service -v 2.3.2 \
&& gem install win32-ipc -v 0.7.0 \
&& gem install win32-event -v 0.6.3 \
# remove net-imap gem as it has a known CVE (CVE-2025-43857) and is not used by the agent
&& gem uninstall net-imap --force \
# The following gems are required for fluentd plugins, or ruby for configuration parsing
&& gem install windows-pr -v 1.2.6 \
&& gem install tomlrb -v 2.0.1 \
&& gem install gyoku -v 1.3.1 \
&& gem install ipaddress -v 0.8.3 \
&& gem install jwt -v 3.2.0 \
&& gem sources --clear-all

# Remove gem cache and chocolatey
RUN powershell -Command "$rubyVersion = & C:\ruby\bin\ruby.exe -rrbconfig -e 'print RbConfig::CONFIG.fetch(%q(ruby_version))'; if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($rubyVersion)) { throw 'Unable to determine Ruby version' }; Remove-Item -Force C:\ruby\lib\ruby\gems\$rubyVersion\cache\*.gem; Remove-Item -Recurse -Force 'C:\ProgramData\chocolatey'; Remove-Item -Recurse -Force 'C:\Users\ContainerAdministrator\AppData\Local\Temp'"

SHELL ["powershell"]

ENV tmpdir /opt/amalogswindows/scripts/powershell
ARG WINDOWS_AMA_URL=
ENV WINDOWS_AMA_URL_NEW ${WINDOWS_AMA_URL}
ENV COMPlus_ThreadPool_UnfairSemaphoreSpinLimit 0

WORKDIR /opt/amalogswindows/scripts/powershell

# Distrust the eMudhra CAs affected by the October 2026 intermediate CA key compromise. Ruby (fluentd) trusts its
# own CA bundle instead of the Windows certificate stores, so Windows' automatic distrust does not reach it.
# The script fails the build when a check fails; keep it in its own RUN so nothing can mask its exit code.
COPY distrust-compromised-cas.ps1 emudhra-compromised-intermediates.pem /opt/amalogswindows/distrust/
RUN C:\opt\amalogswindows\distrust\distrust-compromised-cas.ps1 -RubyExe C:\ruby\bin\ruby.exe
RUN Remove-Item -Recurse -Force C:\opt\amalogswindows\distrust

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
COPY ./amalogswindows/installer/conf/telegraf-ama-logs-process-metrics.conf /etc/telegraf/

# copy keepcert alive ruby scripts
COPY ./amalogswindows/installer/scripts/rubyKeepCertificateAlive/*.rb /etc/fluent/plugin/

#Copy fluentd ruby plugins
COPY ./amalogswindows/ruby/ /etc/fluent/plugin/

# default value is a non-release placeholder; the real version is injected by the
# build pipeline via --build-arg IMAGE_TAG=win-<SEMVER>
ARG IMAGE_TAG=win-0.0.0-dev
ENV AGENT_VERSION ${IMAGE_TAG}

ENV OS_TYPE "windows"
ENV APPLICATIONINSIGHTS_AUTH "NzAwZGM5OGYtYTdhZC00NThkLWI5NWMtMjA3ZjM3NmM3YmRi"
ENV AZMON_COLLECT_ENV False
ENV CI_CERT_LOCATION "C://oms.crt"
ENV CI_KEY_LOCATION "C://oms.key"

# Delete unnecessary files
RUN powershell -Command "$rubyVersion = & C:\ruby\bin\ruby.exe -rrbconfig -e 'print RbConfig::CONFIG.fetch(%q(ruby_version))'; if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($rubyVersion)) { throw 'Unable to determine Ruby version' }; Remove-Item -Recurse -Force 'C:\ruby\share\doc\ruby\html\js'; \
Remove-Item -Force 'C:\ruby\ridk_use\ridk.ps1'; \
Remove-Item -Recurse -Force 'C:\ruby\msys64\usr\share\texinfo\js'; \
Remove-Item -Force 'C:\ruby\msys64\usr\share\terminfo\78\xterm.js'; \
Remove-Item -Force 'C:\ruby\msys64\usr\lib\terminfo\78\xterm.js'; \
Remove-Item -Recurse -Force "C:\ruby\lib\ruby\$rubyVersion\rdoc\generator\template\json_index\js"; \
Remove-Item -Recurse -Force "C:\ruby\lib\ruby\$rubyVersion\rdoc\generator\template\darkfish\js"; \
Remove-Item -Force 'C:\ruby\bin\ridk.ps1'"

ENTRYPOINT ["powershell", "C:\\opt\\amalogswindows\\scripts\\powershell\\main.ps1"]
