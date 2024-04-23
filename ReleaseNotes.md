# Azure Monitor for Containers

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).  For more
information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact
[opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Release History
### 04/22/2024 -
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.20 (linux)
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.20 (windows)
- Linux
  - [CBL-Mariner 2.0.20240403](https://github.com/microsoft/azurelinux/releases/tag/2.0.20240403-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.29.7
  - Telegraf - 1.28.5
  - Fluent-bit - 2.2.2
  - Fluentd - 1.16.3
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.16.3
  - Windows AMA - 46.9.43
  - Golang - 1.20.5
##### Code change log
## What's Changed
- Common
  * Containerlogv2 Kubernetes Metadata Grafana Dashboard Private Preview by @wanlonghenry in https://github.com/microsoft/Docker-Provider/pull/1218
  * fix bugs by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1230
  * reduce podsChunkSizeMin (#1225) by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1226
  * fix version in Geneva config xml by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1227
- Linux
  * update dcr optimization error messages by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1228
  * update fluent-bit to 2.2.2 in linux by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1229

### 03/29/2024 -
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.19 (linux)
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.19 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20240301](https://github.com/microsoft/azurelinux/releases/tag/2.0.20240301-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.29.7
  - Telegraf - 1.28.5
  - Fluent-bit - 2.1.10
  - Fluentd - 1.16.3
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.16.3
  - Windows AMA - 46.9.43
  - Golang - 1.20.5
##### Code change log
## What's Changed
- Common
    * Gangams/telemetry cloud specific by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1199
    * Bump github.com/docker/docker from 24.0.6+incompatible to 24.0.7+incompatible in /source/plugins/go/input by @dependabot in https://github.com/microsoft/Docker-Provider/pull/1194 
    * Containerlogv2 Metadata and annotations based filtering by @wanlonghenry in https://github.com/microsoft/Docker-Provider/pull/1148
    * Move LOGS_AND_EVENTS_ONLY telemetry to DS by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1212
    * Fix input plugin bugs by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1207
    * collect logs from pods from excluded system ns (#1138) by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1146
    * Enable disable addon test pipeline by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1208
    * Update the pipeline to not trigger for builds by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1214
    * Gangams/add flag to enable service account timebound token by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1213
    * Bump github.com/docker/docker from 24.0.7+incompatible to 24.0.9+incompatible in /source/plugins/go/input by @dependabot in https://github.com/microsoft/Docker-Provider/pull/1209
    * Add telemetry for KubernetesMetadata size by @wanlonghenry in https://github.com/microsoft/Docker-Provider/pull/1216
- Windows
    * Start telegraf only when fluent tcp listener up and running by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1205
    * Solving pipeline bugs for windows ama url variable by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1215

### 03/13/2024 -
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.18 (linux)
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.18 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20240301](https://github.com/microsoft/azurelinux/releases/tag/2.0.20240301-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.29.7
  - Telegraf - 1.28.5
  - Fluent-bit - 2.1.10
  - Fluentd - 1.16.3
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.16.3
  - Windows AMA - 46.9.43
  - Golang - 1.20.5
##### Code change log
## What's Changed
- Common
    * Build pipeline no disk space by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1170
    * update latest image version in yaml by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1167
    * Gangams/fix gh issue 3999 by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1168
    * Gangams/geneva msi mode bug fix by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1173
    * make multiline filter first in pipeline by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1151
    * fix telegraf config related fixes by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1176
    * update multiline parser config logic by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1180
    * Update .trivyignore by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1187
    * Gangams/expose disable telemetry config option by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1189
    * Updating the out_oms packages and Golang version to 1.21 by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1182
    * Integrating fluent-bit input plugins for Linux/Windows  by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1144
    * fix bugs in fluent-bit input plugins by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1200
    * Update trivyignore by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1203
- Linux
    * Gangams/telegraf update to 1.28.5 by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1159
    * Disable component based on logs profile (#1141) by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1145
    * explicity set LOGS_AND_EVENTS_ONLY by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1177
    * fix bugs for geneva and legacy mode for toggle components by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1174
    * update v2 schema configmap by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1175
    * add syslog option to linux daemonset for Arc by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1179
    * update mdsd for aarch64 patch by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1183
    * suppress errors and do a quiet grep by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1184
    * Upgrade fluentd to 1.16.3 for linux by @wanlonghenry in https://github.com/microsoft/Docker-Provider/pull/1185
    * fix script errors by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1190
    * fix configmap parse error by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1191
    * Gangams/extend arc k8s msi arm templates for ampls by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1192
    * Golang downgrade back to 1.20.5 by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1198
- Windows
    * Longw/fluentd upgrade win by @wanlonghenry in https://github.com/microsoft/Docker-Provider/pull/1193
    * Update the code to take toggle for env vars in windows by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1196
    * Update windows_fluent_bit default to disable by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1201
 
### 01/31/2024 -
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.17 (linux)
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.17 (windows)
##### Release branch: https://github.com/microsoft/Docker-Provider/commits/release-ciprod-3.1.17/
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20240123](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20240123-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.29.4
  - Telegraf - 1.27.3
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.9.43
  - Golang - 1.20.5
##### Code change log
## What's Changed
- Common
    * Longw/esrp signing and dynamic scripts refactoring by @wanlonghenry in #1087
    * Add user agent to KubeAPI and CAdvisor clients by @pfrcks in #1108
    * Gangams/dotnet core version update by @ganga1980 in #1110
    * Fix bug by @pfrcks in #1111
    * Update pipeline build image from ubuntu 18 to 20 by @wanlonghenry in #1119
    * Add telegraf enabled/disabled info in TelegrafMetricsSentCount by @jatakiajanvi12 in #1121
    * Telemetry gap: Adding missing heartbeat telemetry by @jatakiajanvi12 in #1129
    * Telemetry optimization - Add K8sAPI and CAdvisorAPI response code telemetry in customMetrics by @jatakiajanvi12 in #1122
    * Telemetry gap: Add PerfMetricsCount and HPACount metrics by @jatakiajanvi12 in #1131
    * Telemetry optimization: Sending mdsd error traces as metrics by @jatakiajanvi12 in #1147
    * Make multiline languages configurable by @pfrcks in #1149
    * Change multiline default config to disable all by @wanlonghenry in #1153
    * Upgrade pipeline ubuntu image version by @wanlonghenry in #1156
- Linux
    * Fix telegraf rs false errors by @pfrcks in #1105
    * Update the fluent-bit plugins and telegraf to version 1.27.3 by @jatakiajanvi12 in #1107
    * Gangams/mdsd update for FIPS and FedRamp compliance by @ganga1980 in #1135
- Windows
    * Send kubemonagent event using windows ama by @jatakiajanvi12 in #1127
    * Removing the exit condition if credentials not provided for proxy in Windows by @jatakiajanvi12 in #1136
    * Removing the certificate creation for geneva non MSI by @jatakiajanvi12 in #1137
    * Fix the geneva logs multi-tenancy regression in legacy mode by @ganga1980 in #1161
- Azure Arc K8s Extension
    * Gangams/fix arc k8s windows custom metrics bug by @ganga1980 in #1118

### 12/08/2023 -
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.16 (linux)
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.15 (windows)
##### Release branch: https://github.com/microsoft/Docker-Provider/commits/user/amagraw/3.1.16
##### Commit: https://github.com/microsoft/Docker-Provider/commit/7b7335d94a436b086c8fe2a8c883b865deae3990
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20231004](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20231004-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.28.11
  - Telegraf - 1.27.2
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.9.43
  - Golang - 1.20.5
##### Code change log
## What's Changed
- Linux
    * Update mdsd to 1.28.11 by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1106
- Azure Arc K8s Extension
    * Change mcr path in mooncake cloud to public mcr by @wanlonghenry in https://github.com/microsoft/Docker-Provider/pull/1132

### 10/25/2023 - HOTFIX
##### ARC Version - 3.1.15.1
##### Commit: https://github.com/microsoft/Docker-Provider/commit/fac0c9381f52009bafbcb6fcae52165073e63035 
##### Code change log
## What's Changed
* Revert token changes for arc due to Telegraf bug by @wanlonghenry in https://github.com/microsoft/Docker-Provider/pull/1101

### 10/13/2023 -
##### Version microsoft/oms:3.1.15 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.15 (linux)
##### Version microsoft/oms:win-3.1.15 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.15 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20230924](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20230924-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.27.4
  - Telegraf - 1.27.2
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.9.43
  - Golang - 1.20.5
##### Code change log
## What's Changed
- Linux
  * use omfwd for syslog and update mdsd to 1.27.4 by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1093
  * syslog fix mounting bug by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1095
- Windows
  * Windows AMA <> Container Log/LogV2 integration by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1071
  * Add tailing of the MonAgentHost logs by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1094
- Common
  * Telemetry optimization: Removing the exception writing to AppInsights telemetry by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1092
  * Update multiline comments in configmap by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1097

### 10/04/2023 -
##### Version microsoft/oms:3.1.14 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.14 (linux)
##### Version microsoft/oms:win-3.1.14 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.14 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20230630](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20230805-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.26.1
  - Telegraf - 1.27.2
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.3.2
  - Golang - 1.20.5
##### Code change log
- Common
  * Gangams/implement timebound token and token refresh by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1075 
  * Add nil check for non existence of the fields to avoid nil class exception by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1080
  * Force 1hour expiry for default 1 year valid tokens by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1086
  * Remove wait time for stable MCR release by @wanlonghenry in https://github.com/microsoft/Docker-Provider/pull/1077
  * Fix component governance and sbom generation by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1089
  * Remove all ApplicationInsights code by @tokaplan in https://github.com/microsoft/Docker-Provider/pull/1088
- Windows
  * Update the pipeline to take WINDOWS_AMA_URL from the pipeline by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1059
  * Moving the thread pool env var to dockerfile by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1079
### 09/15/2023 -
##### Version microsoft/oms:3.1.13 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.13 (linux)
##### Version microsoft/oms:win-3.1.13 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.13 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20230630](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20230805-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.26.1
  - Telegraf - 1.27.2
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.3.2
  - Golang - 1.20.5
##### Code change log
- Common
  * Telemetry optimization - Remove unnecessary customDimensions field and shortening some fields by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1056
  * Add separate flags for windows and linux in configmap for geneva logs… by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1064
- Windows
  * Gangams/fix insights metrics issue geneva logs by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1054
  * Not install windows pods for arc extension by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1063
### 08/17/2023 -
##### Version microsoft/oms:3.1.12 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.12 (linux)
##### Version microsoft/oms:win-3.1.12 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.12 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20230630](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20230805-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.26.1
  - Telegraf - 1.27.2
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.3.2
  - Golang - 1.20.5
##### Code change log
- Common
  * Make infra geneva config optional in multi tenancy by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1050
  * Retry only retriable http status codes by @ganga1980 in https://github.com/microsoft/Docker-Provider/pull/1046
- Linux
  * Set mdsd limits by @pfrcks in https://github.com/microsoft/Docker-Provider/pull/1027
  * Updating telegraf to version 1.27.2 by @jatakiajanvi12 in https://github.com/microsoft/Docker-Provider/pull/1048

### 08/03/2023 -
##### Version microsoft/oms:3.1.11 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.11 (linux)
##### Version microsoft/oms:win-3.1.11 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.11 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20230630](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20230630-2.0)
  - Golang - 1.20.5
  - Ruby - 3.1.3
  - MDSD - 1.26.1
  - Telegraf - 1.26.0
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.3.2
  - Golang - 1.20.5
##### Code change log
- Common
  - Add java and python stacktrace for multiline
  - Add multiline test yamls
  - Disable threaded by default and make optional
  - Update golang version to 1.20.5
  - Add CI templates support for containerlogv2 
  - Add streams params in templates
  - Add env vars: CONTAINER_MEMORY_LIMIT_IN_BYTES and HOSTNAME to ama-logs-yaml
- Linux
  - Remove amd64 requirement in ARC
  - Remove the use of dnf package
  - Remove fluentd cert pem files causing CVEs
  - Update the frequency duration to 1s, grafana dashboard for 1P
  - Add test workloads
  - Expose mdsd config for high log customers
  - Add env variable HOSTNAME to all linux pods in ARC K8s

### 06/30/2023 -
##### Version microsoft/oms:3.1.10 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.10 (linux)
##### Version microsoft/oms:win-3.1.10 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.10 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20230526](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20230526-2.0)
  - Golang - 1.20.3
  - Ruby - 3.1.3
  - MDSD - 1.26.1
  - Telegraf - 1.26.0
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.14
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.3.2
  - Golang - 1.20.3
##### Code change log
- Common
  - Add Containerlogv2 support in dataCollectionSettings
  - Update troubleshoot doc for MSI GA
- Linux
  - Update HPA api version to v2
  - Update environment variable Geneva Helm chart
- Windows
  - Add gem ipaddress package for fluentd
  - Fix window vulnerability for CVE-2013-3900
  - Address windows spin-wait thread pool issue
  - Update fluent-bit version from 2.0.5 to 2.0.14 for addressing memory leak issue

### 06/08/2023 -
##### Version microsoft/oms:3.1.9 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.9 (linux)
##### Version microsoft/oms:win-3.1.9 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.9 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20230526](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20230526-2.0)
  - Golang - 1.20.3
  - Ruby - 3.1.3
  - MDSD - 1.26.1
  - Telegraf - 1.26.0
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.5
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.3.2
  - Golang - 1.20.3
##### Code change log
- Common
  - Allow scheduling ama-logs pods on tainted nodes in Arc K8S clusters via amalogs.scheduleOnTaintedNodes option
  - Add azure policy, terraform, and bicep support for MSI onboarding
  - Cost optimization GA changes
- Linux
  - Fix bug which causes ama-logs pod to restart continously for docker container runtime clusters
  - Remove vim package from image to vulnerabilities footprint
  - Update Dockerfile for trivy vulnerabilities scan
  - Update Mariner version from 2.0.20230426 to 2.0.20230526
- Windows
  - Fix chocolatey version to 1.4.0
  - Mute telegraf if monitor_kubernetes_pods is false or N/A
  - Use IPV4 address for AKS clusters with dual stacks for cadvisor calls
  - Update BouncyCastle version to 1.8.9 from 1.8.6.1

### 05/16/2023 -
##### Version microsoft/oms:3.1.8 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.8 (linux)
##### Version microsoft/oms:win-3.1.8 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.8 (windows)
##### Current dependencies
- Linux
  - [CBL-Mariner 2.0.20230426](https://github.com/microsoft/CBL-Mariner/releases/tag/2.0.20230426-2.0)
  - Golang - 1.20.3
  - Ruby - 3.1.3
  - MDSD - 1.26.1
  - Telegraf - 1.26.0
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.5
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.3.2
  - Golang - 1.20.3
##### Code change log
- Common
  - Retire unused pipeline files and Dockerfile
  - Update release pipeline for override tag
  - Update LogCollection troubleshoot script for ARO clusters
- Linux
  - Add KataRuntimePod check in kubernetes_container_inventory
  - Update MDSD version from 1.17.1 to 1.26.1
  - Update Telegraf version from 1.25.2 to 1.26.0 for vulnerabilities fixes
  - Update Dockerfile for trivy vulnerabilities scan

### 04/26/2023 -
##### Version microsoft/oms:3.1.7 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.7 (linux)
##### Version microsoft/oms:win-3.1.7 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.7 (windows)
##### Current dependencies
- Linux
  - CBL-Mariner 2.0
  - Golang - 1.20.3
  - Ruby - 3.1.3
  - MDSD - 1.17.1-build.master.377
  - Telegraf - 1.25.2
  - Fluent-bit - 2.0.9
  - Fluentd - 1.14.6
- Windows
  - Ruby - 3.1.1
  - Fluent-bit - 2.0.5
  - Telegraf - 1.24.2
  - Fluentd - 1.14.6
  - Windows AMA - 46.3.2
  - Golang - 1.20.3
##### Code change log
- Common
  - Adding the multiline changes in fluent-bit-common
- Linux
  - Migration of base image Ubuntu 18.04 to CBL-Mariner 2.0
  - Update golang version from 1.18.3 to 1.20.3
  - Updated the default wait times for the telegraf network port listeners
  - Exposed the wait times through config maps for testing and support

### 04/07/2023 -
##### Version microsoft/oms:3.1.6 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.6 (linux)
##### Version microsoft/oms:win-3.1.6 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.6 (windows)
##### Code change log
- Common
  - Geneva logs integration for single and multi tenancy
  - Change output fwd plugin settings configurable
  - Add multiline logs feature with configmap
  - Config AMA specific envvars only if 1p mode is configured
  - Update prometheus.io/scheme default description in configmap
  - Add support to specify azure autonomous resource endpoint parameter for the Extension chart for custom metrics
  - Add autonomous fqdn to endpoint for metrics 
  - Add devskim as github action and codeql as enabled in ADO pipeline
  - AgentLogCollection.sh update for collecting more detailed logs
  - Fix pod ready condition issue for pods that are job ready 
  - Updating packages for go vulnerabilities
  - Remove the necessary askcoin references in troubleshooter and readme
  - Change md5 to sha256 for the omslogger
  - Log message and yaml to sync with AKS RP
  - Add nil check in kubelet
  - Fix fluent-bit output plugin crash when the tags are missing for the telegraf metrics
- Linux Agent
  - Use -p when creating dirs in main.sh
  - Disable telegraf on replicaset by default. For resource optimization, telegraf in replicaset only enabled either the cluster level Prometheus Scraping or NPM configured
  - Remove unused default gem openssl, gem find, gem rvm & python installed

### 03/21/2023 -
##### Version microsoft/oms:3.1.4 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.4 (linux)
##### Version microsoft/oms:win-3.1.5 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.5 (windows)
##### Code change log
- Windows Agent
  - Downgrade telegraf to version 1.24.2 due to Telegraf Data Collector Service error

Note: Starting 03/01/2023 we have moved to the semver versioning system for naming image tags with the release 3.1.4
### 03/01/2023 -
##### Version microsoft/oms:3.1.4 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.4 (linux)
##### Version microsoft/oms:win-3.1.4 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.1.4 (windows)
##### Code change log
- Common
  - Move to semver versioning system for naming imageTags
  - Fix bug in overwriting prometheus namespace
  - Fix kube events timestamp using metadata timestamp
  - Moved syslog telemetry from AI to pod inventory
  - Update telegraf to version 1.25.2
  - Fix bug wherein sidecar container was not muted by default
  - Removed labelSelector from ama-logs.yaml and helm charts
  - Update fluent-bit to version 2.0.5
  - Enabled multiline support for ContainerLogV2 via configmap
- Linux Agent
  - Update ruby to version 3.1.3
- Windows Agent
  - Fix podName missing bug in ContainerLogV2

Note : The agent version(s) below has dates (ciprod\<mmddyyyy\>), which indicate the agent build dates (not release dates)

### 01/18/2023 -
##### Version microsoft/oms:ciprod01182023-095c864a Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod01182023-095c864a (linux)
##### Version microsoft/oms:win-ciprod01182023-095c864a Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod01182023-095c864a (windows)
##### Code change log
- Linux Agent
  - Replace ifconfig.co url with mcr.microsoft.com for network connectivity test
  - Add xvda in devices so that telegraf can fetch the Disk IO data from xvda disk as well
- Common
  - Added the config option to ignore proxy settings for the AMPLS + Proxy environment
  - Changes to the MSI Onboarding ARM templates for handling DCR naming and handling the scenario where DCR name is more than 64 characters and also removing the spaces in the workspace region if user inputs the workspace region name with spaces
  - Add specific master/control-plane toleration key to fix the node upgrade issue in Arc extension.
  - AKS, Arc K8s and Provisioned cluster template updates for Data collection settings.
  - Implementation of Data collection settings for Cost optimization feature
  - Telemetry to track data collection settings enablement and settings
  - Agent rename changes for the Azure Arc Provisioned cluster onboarding templates
  - Update for troubleshooting script for collecting syslog data

### 12/03/2022 -
##### Version microsoft/oms:ciprod12032022-c9f3dc30 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod12032022-c9f3dc30 (linux)
##### Version microsoft/oms:win-ciprod12032022-c9f3dc30 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod12032022-c9f3dc30 (windows)
##### Code change log
- Linux Agent
  - Enable syslog support
- Windows Agent
  - Use ghrelease as gcc download path
  - Move fluent-bit conf update before fluent-bit start
  - Make containerd and secure port as default for windows same as linux
- Common (Linux & Windows Agent)
  - Add FluentBit Telegraf Plugin buffer and chunk config options to configmap
  - Remove references to healthservice in troubleshooting script
  - Add pods namespace label name for all telegraf conf
  - Update telegraf version from 1.23.2 to 1.24.2
  - Address Computer Name mismatch in KubeEvents

### 10/05/2022 -
##### Version microsoft/oms:ciprod10042022-3c05dd1b Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod10042022-3c05dd1b (linux)
##### Version microsoft/oms:win-ciprod10042022-3c05dd1b Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod10042022-3c05dd1b (windows)
##### Code change log

- Common
  - Rename resource names from omsagent based to ama-logs based #823
  - Chart major version bumped to 3.0.0 (no auto update)
  - Change image tag format from ciprod\<mmddyyyy\> to ciprod\<mmddyyyy\>-\<short-commit-id\> where commit-id is the id of the last commit to be included in the release
  - Add gatekeeper-system to exlude namespace #833
  - flag to ignore proxy settings which are automatically set by arc k8s extension #824
  - Added new rule group and rule properties #818
  - fix: Update DCR creation to Clusters resource group instead of workspace (ARM Template update) #819
  - Support LCM #820
  - Bug fixes
    - https://github.com/microsoft/Docker-Provider/pull/834

### 08/10/2022 -
##### Version microsoft/oms:ciprod08102022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod08102022 (linux)
##### Version microsoft/oms:win-ciprod08102022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod08102022 (windows)
##### Code change log
- Linux Agent
  - Consume ruby from RVM instead of brightbox ppa

- Common
  - Update to Ruby 3.1.1
  - Update telegraf to 1.23.2
  - Updates fluentd to 1.14.6
  - Use default JSON gem instead of yajl-json
  - Consume tomlrb as a gem instead of committed source code
  - Move from beta.kubernetes.io to kubernetes.io
  - Bug fixes
    - Fix bug in processing fractional memory limits
    - Fix log loss due to inode reuse

### 07/27/2022 -
##### Version microsoft/oms:ciprod06272022-hotfix Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06272022-hotfix (linux)
- Fixes for sending the proper node allocatable cpu and memory value for the container which does not specify limits.

### 06/27/2022 -
##### Version microsoft/oms:ciprod06272022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06272022 (linux)
##### Code change log
- Fixes for following bugs in ciprod06142022 which are caught in AKS Canary region deployment
  - Fix the exceptions related to file write & read access of the MDM inventory state file
  - Fix for missing Node GPU allocatable & capacity metrics for the clusters which are whitelisted for AKS LargeCluster Private Preview feature

### 6/14/2022 -
##### Version microsoft/oms:ciprod06142022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06142022 (linux)
##### Version microsoft/oms:win-ciprod06142022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod06142022 (windows)
##### Code change log
- Linux Agent
  - Prometheus sidecar memory optimization
  - Fix for issue of Telegraf connecting to FluentD Port 25228 during container startup
  - Add integration for collecting Subnets IP usage metrics for Azure CNI (turned OFF by default)
  - Replicaset Agent improvements related to supporting of 5K Node cluster scale
- Common (Linux & Windows Agent)
  - Make custom metrics endpoint configurable to support edge environments
- Misc
  - Moved Trivy image scan to Azure Pipeline


### 5/19/2022 -
##### Version microsoft/oms:ciprod05192022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod05192022 (linux)
##### Version microsoft/oms:win-ciprod05192022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod05192022 (windows)
##### Code change log
- Linux Agent
  - PodReadyPercentage metric bug fix
  - add cifs & fuse file systems to ignore list
  - CA Cert Fix for Mariner Hosts in Air Gap
  - Disk usage metrics will no longer be collected for the paths "/mnt/containers" and "/mnt/docker"
- Windows Agent
  - Ruby version upgrade from 2.6.5.1 to 2.7.5.1
  - Added Support for Windows Server 2022
  - Multi-Arch Image to support both Windows 2019 and Windows 2022
- Common (Linux & Windows Agent)
  - Telegraf version update from 1.20.3 to 1.22.2 to fix the vulnerabilitis
  - Removal of Health feature as part of deprecation plan
  - AAD Auth MSI feature support for  Arc K8s  (not usable externally yet)
  - MSI onboarding ARM template updates for both AKS & Arc K8s
  - Fixed the bug related to windows metrics in MSI mode for AKS
  - Configmap updates for log collection settings for v2 schema
- Misc
  - Improvements related to CI/CD Multi-arc image
      - Do trivy rootfs checks
      - Disable push to ACR for PR and PR updates
      - Enable batch builds
      - Scope Dev/Prod pipelines to respective branches
      - Shorten datetime component of image tag
  - Troubleshooting script updates for MSI onboarding
  - Instructions for testing of agent in MSI auth mode
  - Add CI Windows Build to MultiArch Dev pipeline
  - Updates related to building of Multi-arc image for windows in Build Pipeline and local dev builds
  - Test yamls to test container logs and prometheus scraping on both WS2019 & WS2022
  - Arc K8s conformance test updates
  - Script to collect the Agent logs for troubleshooting
  - Force run trivy stage for Linux
  - Fix docker msi download link in windows install-build-pre-requisites.ps1 script
  - Added Onboarding templates for legacy auth for internal testing
  - Update the Build pipelines to have separate phase for Windows

### 3/17/2022 -
##### Version microsoft/oms:ciprod03172022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod03172022 (linux)
##### Version microsoft/oms:win-ciprod03172022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod03172022 (windows)
##### Code change log
- Linux Agent
  - Multi-Arch Image to support both AMD64 and ARM64
  - Ruby upgraded to version 2.7 from 2.6
  - Fix Telegraf Permissions
  - Fix ADX bug with database name
  - Vulnerability fixes
  - MDSD updated to 1.17.0
    - HTTP Proxy support
    - Retries for Log Analytics Ingestion
    - ARM64 support
    - Memory leak fixes for network failure scenario
- Windows Agent
  - Bug fix for FluentBit stdout and stderr log filtering
- Common
  - Upgrade Go lang version from 1.14.1 to 1.15.14
  - MSI onboarding ARM template update
  - AKS HTTP Proxy support
  - Go packages upgrade to address vulnerabilities

### 1/31/2022 -
##### Version microsoft/oms:ciprod01312022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod01312022 (linux)
##### Version microsoft/oms:win-ciprod01312022 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod01312022 (windows)
##### Code change log
- Linux Agent
  - Configurable DB name via configmap for ADX (default DB name:containerinsights)
  - Default to cAdvisor port to 10250 and container runtime to  Containerd
  - Update AgentVersion annotation in yamls (omsagent and chart) with released MDSD agent version
  - Incresing windows agent CPU limits from 200m to 500m
  - Ignore new disk path that comes from containerd starting with k8s version >= 1.19.x, which was adding unnecessary InsightsMetrics logs and increasing cost
  - Route the AI SDK logs to log file instead of stdout
  - Telemetry to collect ContainerLog Records with empty Timestamp
  - FluentBit version upgrade from 1.6.8 to 1.7.8
- Windows Agent
  - Update to use FluentBit for container log collection and removed FluentD dependency for container log collection
  - Telemetry to track if any of the variable fields of windows container inventory records has field size >= 64KB
  - Add windows os check in in_cadvisor_perf plugin to avoid making call in MDSD in MSI auth mode
  - Bug fix for placeholder_hostname in telegraf metrics
  - FluentBit version upgrade from 1.4.0 to 1.7.8
- Common
    - Upgrade FluentD gem version from 1.12.2 to 1.14.2
    - Upgrade Telegraf version from 1.18.0 to 1.20.3
    - Fix for exception in node allocatable
    - Telemetry to track nodeCount & containerCount
- Other changes
   - Updates to Arc K8s Extension ARM Onboarding templates with GA API version
   - Added ARM Templates for MSI Based Onboarding for AKS
   - Conformance test updates relates to sidecar container
   - Troubelshooting script to detect issues related to Arc K8s Extension onboarding
   - Remove the dependency SP for CDPX since configured to use MSI
   - Linux Agent Image build improvements
   - Update msys2 version to fix windows agent build
   - Add explicit exit code 1 across all the PS scripts


### 10/13/2021 -
##### Version microsoft/oms:ciprod10132021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod10132021 (linux)
##### Version microsoft/oms:win-ciprod10132021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod10132021 (windows)
##### Code change log
- Linux Agent
  - MDSD Proxy support for non-AKS
  - log rotation for mdsd log files {err,warn, info & qos}
  - Onboarding status
  - AAD Auth MSI changes  (not usable externally yet)
  - Upgrade k8s and adx go packages to fix vulnerabilities
  - Fix missing telegraf metrics (TelegrafMetricsSentCount & TelegrafMetricsSendErrorCount) in mdsd route
  - Improve fluentd liveness probe checks to handle both supervisor and worker process
  - Fix telegraf startup issue when endpoint is unreachable
- Windows Agent
  - Windows liveness probe optimization
- Common
    - Add new metrics to MDM for allocatable % calculation of cpu and memory usage
- Other changes
   - Helm chart updates for removal of rbac api version and deprecation of.Capabilities.KubeVersion.GitVersion to .Capabilities.KubeVersion.Version
   - Updates to build and release ev2
   - Scripts to collect troubleshooting logs
   - Unit test tooling
   - Yaml updates in parity with aks rp yaml
   - upgrade golang version for windows in pipelines
   - Conformance test updates

### 09/02/2021 -
##### Version microsoft/oms:ciprod08052021-1 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod08052021-1 (linux)
##### Code change log
- Bumping image tag for some tooling (no code changes except the IMAGE_TAG environment variable)

### 08/05/2021 -
##### Version microsoft/oms:ciprod08052021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod08052021 (linux)
##### Code change log
- Linux Agent
  - Fix for CPU spike which occurrs at around 6.30am UTC on every day because of unattended package upgrades
  - Update MDSD build which has fixes for the following issues
     - Undeterministic Core dump issue because of the non 200 status code and runtime exception stack unwindings
     - Reduce the verbosity of the error logs for OMS & ODS code paths.
     - Increase Timeout for OMS Homing service API calls from 30s to 60s
   - Fix for https://github.com/Azure/AKS/issues/2457
   - In replicaset, tailing of the mdsd.err log file to agent telemetry


### 07/13/2021 -
##### Version microsoft/oms:win-ciprod06112021-2 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod06112021-2 (windows)
##### Code change log
- Hotfix for fixing NODE_IP environment variable not set issue for non sidecar mode

### 07/02/2021 -
##### Version microsoft/oms:ciprod06112021-1 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06112021-1 (linux)
##### Version microsoft/oms:win-ciprod06112021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod06112021 (windows)
##### Code change log
- Hotfix for crash in clean_cache in in_kube_node_inventory plugin
- We didn't rebuild windows container, so the image version for windows container stays the same as last release (ciprod:win-ciprod06112021) before this hotfix

### 06/11/2021 -
##### Version microsoft/oms:ciprod06112021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06112021 (linux)
##### Version microsoft/oms:win-ciprod06112021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod06112021 (windows)
 - Linux Agent
   - Removal of base omsagent dependency
   - Using MDSD version 1.10.1  as base agent for all the supported LA data types
   - Ruby version upgrade to 2.6 i.e. same version as windows agent
   - Upgrade FluentD gem version to 1.12.2
   - All the Ruby Fluentd Plugins upgraded to v1 as per Fluentd guidance
   - Fluent-bit tail plugin Mem_Buf_limit is configurable via ConfigMap
 - Windows Agent
   - CA cert changes for airgapped clouds
   - Send perf metrics to MDM from windows daemonset
   - FluentD gem version upgrade from 1.10.2 to 1.12.2 to make same version as Linux Agent
  - Doc updates
   - README updates related to OSM preview release for Arc K8s
   - README updates related to recommended alerts

### 05/20/2021 -
##### Version microsoft/oms:ciprod05202021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod05202021 (linux)
##### No Windows changes with this release, win-ciprod04222021 still current.
##### Code change log
- Telegraf now waits 30 seconds on startup for network connections to complete (Linux only)
- Change adding telegraf to the liveness probe reverted (Linux only)

### 05/12/2021 -
##### Version microsoft/oms:ciprod05122021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod05122021 (linux)
##### No Windows changes with this release, win-ciprod04222021 still current.
##### Code change log
- Upgrading oneagent to version 1.8 (only for Linux)
- Enabling oneagent for container logs for East US 2

### 04/22/2021 -
##### Version microsoft/oms:ciprod04222021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod04222021 (linux)
##### Version microsoft/oms:win-ciprod04222021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod04222021 (windows)
##### Code change log
- Bug fixes for metrics cpuUsagePercentage and memoryWorkingSetPercentage for windows nodes
- Added metrics for threshold violation
- Made Job completion metric configurable
- Udated default buffer sizes in fluent-bit
- Updated recommended alerts
- Fixed bug where logs written before agent starts up were not collected
- Fixed bug which kept agent logs from being rotated
- Bug fix for Windows Containerd container log collection
- Bug fixes
- Doc updates
- Minor telemetry changes

### 03/26/2021 -
##### Version microsoft/oms:ciprod03262021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod03262021 (linux)
##### Version microsoft/oms:win-ciprod03262021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod03262021 (windows)
##### Code change log
- Started collecting new metric - kubelet running pods count
- Onboarding script fixes to add explicit json output
- Proxy and token updates for ARC
- Doc updates for Microsoft charts repo release
- Bug fixes for trailing whitespaces in enable-monitoring.sh script
- Support for higher volume of prometheus metrics by scraping metrics from sidecar
- Update to get new version of telegraf - 1.18
- Add label and field selectors for prometheus scraping using annotations
- Support for OSM integration
- Removed wireserver calls to get CA certs since access is removed
- Added liveness timeout for exec for linux containers

### 02/23/2021 -
##### Version microsoft/oms:ciprod02232021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod02232021 (linux)
##### Version microsoft/oms:win-ciprod02232021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod02232021 (windows)
##### Code change log
- ContainerLogV2 schema support for LogAnalytics & ADX (not usable externally yet)
- Fix nodemetrics (cpuusageprecentage & memoryusagepercentage) metrics not flowing. This is fixed upstream for k8s versions >= 1.19.7 and >=1.20.2.
- Fix cpu & memory usage exceeded threshold container metrics not flowing when requests and/or limits were not set
- Mute some unused exceptions from going to telemetry
- Collect containerimage (repository, image & imagetag) from spec (instead of runtime)
- Add support for extension MSI for k8s arc
- Use cloud specific instrumentation keys for telemetry
- Picked up newer version for apt
- Add priority class to daemonset (in our chart only)

### 01/11/2021 -
##### Version microsoft/oms:ciprod01112021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod01112021 (linux)
##### Version microsoft/oms:win-ciprod01112021 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod01112021 (windows)
##### Code change log
- Fixes for Linux Agent Replicaset Pod OOMing issue
- Update fluentbit (1.14.2 to 1.6.8) for the Linux Daemonset
- Make Fluentbit settings: log_flush_interval_secs, tail_buf_chunksize_megabytes and tail_buf_maxsize_megabytes configurable via configmap
- Support for PV inventory collection
- Removal of Custom metric region check for Public cloud regions and update to use cloud environment variable to determine the custom metric support
- For daemonset pods, add the dnsconfig to use ndots: 3 from ndots:5 to optimize the number of DNS API calls made
- Fix for inconsistency in the collection container environment variables for the pods which has high number of containers
- Fix for disabling of std{out;err} log_collection_settings via configmap issue in windows daemonset
- Update to use workspace key from mount file rather than environment variable for windows daemonset agent
- Remove per container info logs in the container inventory
- Enable ADX route for windows container logs
- Remove logging to termination log in windows agent liveness probe

### 11/09/2020 -
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod11092020 (linux)
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod11092020 (windows)
##### Code change log
- Fix for duplicate windows metrics

### 10/27/2020 -
##### Version microsoft/oms:ciprod10272020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod10272020 (linux)
##### Version microsoft/oms:win-ciprod10272020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod10272020 (windows)
##### Code change log
- Activate oneagent in few AKS regions (koreacentral,norwayeast)
- Disable syslog
- Fix timeout for Windows daemonset liveness probe
- Make request == limit for Windows daemonset resources (cpu & memory)
- Schema v2 for container log (ADX only - applicable only for select customers for piloting)

### 10/05/2020 -
##### Version microsoft/oms:ciprod10052020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod10052020 (linux)
##### Version microsoft/oms:win-ciprod10052020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod10052020 (windows)
##### Code change log
- Health CRD to version v1 (from v1beta1) for k8s versions >= 1.19.0
- Collection of PV usage metrics for PVs mounted by pods (kube-system pods excluded by default)(doc-link-needed)
- Zero fill few custom metrics under a timer, also add zero filling for new PV usage metrics
- Collection of additional Kubelet metrics ('kubelet_running_pod_count','volume_manager_total_volumes','kubelet_node_config_error','process_resident_memory_bytes','process_cpu_seconds_total','kubelet_runtime_operations_total','kubelet_runtime_operations_errors_total'). This also includes updates to 'kubelet' workbook to include these new metrics
- Collection of Azure NPM (Network Policy Manager) metrics (basic & advanced. By default, NPM metrics collection is turned OFF)(doc-link-needed)
- Support log collection when docker root is changed with knode. Tracked by [this](https://github.com/Azure/AKS/issues/1373) issue
- Support for Pods in 'Terminating' state for nodelost scenarios
- Fix for reduction in telemetry for custom metrics ingestion failures
- Fix CPU capacity/limits metrics being 0 for Virtual nodes (VK)
- Add new custom metric regions (eastus2,westus,australiasoutheast,brazilsouth,germanywestcentral,northcentralus,switzerlandnorth)
- Enable strict SSL validation for AppInsights Ruby SDK
- Turn off custom metrics upload for unsupported cluster types
- Install CA certs from wire server for windows (in certain clouds)

### 09/16/2020 -
> Note: This agent release targetted ONLY for non-AKS clusters via Azure Monitor for containers HELM chart update
##### Version microsoft/oms:ciprod09162020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod09162020 (linux)
##### Version microsoft/oms:win-ciprod09162020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod09162020 (windows)
##### Code change log
- Collection of Azure Network Policy Manager Basic and Advanced metrics
- Add support in Windows Agent for Container log collection of CRI runtimes such as ContainerD
- Alertable metrics support Arc K8s cluster to parity with AKS
- Support for multiple container log mount paths when docker is updated through knode
- Bug fix related to MDM telemetry

### 08/07/2020 -
##### Version microsoft/oms:ciprod08072020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod08072020 (linux)
##### Version microsoft/oms:win-ciprod08072020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod08072020 (windows)
##### Code change log
- Collection of KubeState metrics for deployments and HPA
- Add the Proxy support for Windows agent
- Fix for ContainerState in ContainerInventory to handle Failed state and collection of environment variables for terminated and failed containers
- Change /spec to /metrics/cadvisor endpoint to collect node capacity metrics
- Disable Health Plugin by default and can enabled via configmap
- Pin version of jq to 1.5+dfsg-2
- Bug fix for showing node as 'not ready' when there is disk pressure
- oneagent integration (disabled by default)
- Add region check before sending alertable metrics to MDM
- Telemetry fix for agent telemetry for sov. clouds


### 07/15/2020 -
##### Version microsoft/oms:ciprod07152020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod07152020 (linux)
##### Version microsoft/oms:win-ciprod05262020-2 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod05262020-2 (windows)
##### Code change log
- Following hotfixes which are applicable only for Linux agent
  - Fix the issue related to collection of multi-containers in pod for the ContainerInventory table
  - Fix the containerhostname field value to have podname rather than nodename in ContainerInventory table
  - Fix OOM issue during container startup if there are high number of pods or containers on the node
  - Fix the ContainerName field value same as before in ContainerInventory table
- We didn't rebuild windows container, so the image version for windows container stays the same as last release (ciprod:win-ciprod05262020-2) before this hotfix

### 06/30/2020 -
##### Version microsoft/oms:ciprod06302020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06302020 (linux)
##### Version microsoft/oms:win-ciprod05262020-2 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod05262020-2 (windows)
##### Code change log
- Hotfix for nested JSON log parsing bug (applicable only to Linux Daemonset)
- We didn't rebuild windows container, so the image version for windows container stays the same as last release (ciprod:win-ciprod05262020-2) before this hotfix

### 05/27/2020 -
##### Version microsoft/oms:win-ciprod05262020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod05262020-2 (windows)
##### Code change log
- Update [application insights instrumentation key](https://github.com/microsoft/OMS-docker/pull/410) for windows image to point to the production instance

### 05/22/2020 -
##### Version microsoft/oms:ciprod05222020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod05222020 (linux)
##### Version microsoft/oms:win-ciprod05222020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-ciprod05222020 (windows)
##### Code change log
- Windows Daemonset - Collection of Windows std/stderr logs
- More Alerable Metrics (going to Metrics Store/custom metrics - see Customer Impact section below for metrics list)
- Fix OOM-ing at high prometheus scrape volume
- Update fluentbit (0.14.4 to 1.4.2)
- Drop non-numeric metrics thru Telegraf
- Reduce Health exception (when API server response is nil)
- Add 'Computer' dimension to all telemetry (internal use)
- Support for specifiying HTTP & HTTPS Proxy for outbound/egress (applicable only for non-AKS clusters)
- Move to rbac.authorization.k8s.io/v1 for ClusterRole & ClusterRoleBinding
- Move to apiextensions.k8s.io/v1 for Health CRD

##### Customer Impact
- Windows Logs - Customers will see agent automatically start collecting windows container STDOUT/STDERR logs sending them to same loganaytics workspace (containerlogs table)
- Alertable metrics - Customers will see the below metrics & namespaces in 'Metrics' TOC for AKS clusters
     - Metrics
         - diskUsagePercentage
         - completedJobsCount
         - oomKilledContainerCount
         - podReadyPercentage
         - restartingContainerCount
         - cpuExceededPercentage
         - memoryRssExceededPercentage
         - memoryWorkingSetExceededPercentage
     - Metric Namespaces
         - insights.container/containers
- HTTP/S Proxy support - For non-AKS clusters, proxy can be configured when installing thru HELM. Please see documentation for more details


### 04/16/2020 -
> Note: This agent release targetted ONLY for non-AKS clusters via Azure Monitor for containers HELM chart update
##### Version microsoft/oms:ciprod04162020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod04162020
##### Code change log
- Add support for rate limiting
- Add support for Container Runtime Interface compatible container runtime(s) like CRI-O and ContainerD
     - cAdvisor APIs are used to collect the container inventory for Docker/Moby and CRI runtime K8s environments
     - Based on the container runtime, corresponding container log FluentBit parser(docker/cri) selected

##### Customer Impact
- Ingestion will throttle the workspaces if the agent on the cluster sending the beyond Log Analytics Workspace throttling  limits i.e. 500 MB/s
- On Docker runtime environments, Inventory of the containers obtained  earlier via Docker REST API.
  Agent now uses the cAdvisor APIs to get the inventory of the containers for Docker and non-Docker container runtime environments.

### 03/02/2020 -
##### Version microsoft/oms:ciprod03022020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod03022020
##### Code change log
- Collection of GPU metrics as InsightsMetrics
- Enable config map settings to enable collection of 'Normal' kube events
- Fix kubehealth exceptions to handle empty/nil kube api responses
- Get resource limits for health and MDM from kubelet instead of kube api
- Bug fix for windows node image collection where image name contains multiple slashes
- Exclude ARO master node for data collection
- Telemetry for kube events flushed
- Changes to support msi for mdm if service principal doesnt exist
- Changes for AKS telemetry to ping ods endpoint first and then network check
- KubeEvents bug fix for KubeEvent type

##### Customer Impact
- Providing capability for customers to collect 'Normal' kube events using config map
- Metrics for GPU are collected and ingested to customers workspace if they have GPU enabled nodes
- Bug fix for windows container image collection allows customers to get the right data in the ContainerInventory table for windows       containers.

### 01/07/2020 -
##### Version microsoft/oms:ciprod01072020 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod01072020
##### Code change log
- Switch between 10255(old) and 10250(new) ports for cadvisor for older and newer versions of kubernetes

##### Customer Impact
- Node cpu, node memory, container cpu and container memory metrics were obtained earlier by querying kubelet readonly port(http://$NODE_IP:10255). Agent now supports getting these metrics from kubelet port(https://$NODE_IP:10250) as well. During the agent startup, it checks for connectivity to kubelet port(https://$NODE_IP:10250), and if it fails the metrics source is defaulted to readonly port(http://$NODE_IP:10255).

### 12/04/2019 -
##### Version microsoft/oms:ciprod12042019 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod12042019
- Fix scheduler for all input plugins
- Fix liveness probe
- Reduce chunk sizes for all fluentD buffers to support larger clusters (nodes & pods)
- Chunk Kubernetes API calls (pods,nodes,events)
- Use HTTP.start instead of HTTP.new
- Merge KubePerf into KubePods & KubeNodes
- Merge KubeServices into KubePod
- Use stream based yajl for JSON parsing
- Health - Query only kube-system pods
- Health - Use keep_if instead of select
- Container log enrichment (turned OFF by default for ContainerName & ContainerImage)
- Application Insights Telemetry - Async
- Fix metricTime to be batch time for all metric input plugins
- Close socket connections properly for DockerAPIClient
- Fix top un handled exceptions in Kubernetes API Client and pod inventory
- Fix retries, wait between retries, chunk size, thread counts to be consistent for all FluentD workflows
- Back-off for containerlog enrichment K8S API calls
- Add new regions (3) for Azure Monitor Custom metrics
- Increase the cpu(1 core) & memory(750Mi) limits for replica-set to support larger clusters (nodes & pods)
- Move to Ubuntu 18.04 LTS
- Support for Kubernetes 1.16
- Use ifconfig for detecting network connectivity issues
- Collect eventType != Normal

### 10/11/2019 -
##### Version microsoft/oms:ciprod10112019 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod10112019
- Update prometheus config scraping capability to restrict collecting metrics from pods in specific namespaces.
- Feature to send custom configuration/prometheus scrape errors to KubeMonAgentEvents table in customer's workspace.
- Bug fix to collect data for init containers for Container Logs, KubePodInventory and Perf.
- Bug fix for empty array being a valid setting in custom config in configmap.
- Restrict kubelet_docker_operations and kubelet_docker_operations_errors to create_containers, remove_containers and pull_image operations.
- Fix top exceptions in telemetry

### 08/22/2019 -
##### Version microsoft/oms:ciprod08222019 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod08222019
- Cluster Health Private Preview based on config map setting
- Update resource requests for replicaset to 110m and 250Mi
- Update custom metrics supported regions
- Fix for promethus config map telemetry
- Telemetry for controller kind
- Update url to use one of the whitelisted urls for cp monitor telemetry
- Configmap with clusterid for AKS to be used by Application Insights

### 07/09/2019 -
##### Version microsoft/oms:ciprod07092019 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod07092019
- Prometheus custom metric collection using config map allowing omsagent to
  * Scrape metrics from user defined urls
  * Scrape kubernetes pods with prometheus annotations
  * Scrape metrics from kubernetes services
- Exception fixes in daemonset and replicaset
- Container Inventory plugin changes to get image id from the repo digest and populate repository for image with
only image digest
- Remove telegraf errors from being sent to ApplicationInsights and instead log it to stderr to provide visibility for
customers
- Bug fixes for region names with spaces being processed incorrectly while sending mdm metrics
- Add log size in telemetry
- Remove buffer chunk size and buffer max size from fluentbit configuration
### 06/14/2019 -
##### Version microsoft/oms:ciprod06142019 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod06142019
- MDM pod metrics bug fixes - MDM rejecting pod metrics due to nodename or controllername dimensions being empty
- Prometheus metrics collection by default in every node for kubelet docker operations and kubelet docker operation errors
- Telegraf metric collection for diskio and networkio metrics
- Agent Configuration/ Settings for data collection
  * Cluster level log collection enable/disable option
  * Ability to enable/disable stdout and/or stderr logs collection per namespace
  * Cluster level environment variable collection enable/disable option
  * Config file version & config schema version
  * Pod annotation for supported config schema version(s)
- Log collection optimization/tuning for better performance
  * Derive k8s namespaces from log file name (instead of making call to k8s api service)
  * Do not tail log files for containers in the excluded namespace list (if excluded both in stdout & stderr)
  * Limit buffer size to 1M and flush logs more frequently [every 10 secs (instead of 30 secs)]
  * Tuning of several other fluent bit settings
-	Increase requests
  * Replica set memory request by 75M (100M to 175M)
  * Daemonset CPU request by 25m (50m to 75m)
- Will be pushing image only to MCR ( no more Docker) starting this release. AKS-engine will also start to pull our agent image from MCR

### 04/23/2019 -
##### Version microsoft/oms:ciprod043232019 Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:ciprod04232019
- Windows node monitoring (metrics & inventory)
- Telegraf integration (Telegraf metrics to LogAnalytics)
- Node Disk usage metrics (used, free, used%) as InsightsMetrics
- Resource stamping for all types (inventory, metrics (perf), metrics (InsightsMetrics), logs) [Applicable only for AKS clusters]
- Upped daemonset memory request (not limit) from 150Mi to 225 Mi
- Added liveness probe for fluentbit
- Fix for MDM filter plugin when kubeapi returns non-200 response

### 03/12/2019 - Version microsoft/oms:ciprod03122019
- Fix for closing response.Body in outoms
- Update Mem_Buf_Limit to 5m for fluentbit
- Tail only files that were modified since 5 minutes
- Remove some unwanted logs that are chatty in outoms
- Fix for MDM disablement for AKS-Engine
- Fix for Pod count metric (same as container count) in MDM

### 02/21/2019 - Version microsoft/oms:ciprod02212019
- Container logs enrichment optimization
  * Get container meta data only for containers in current node (vs cluster before)
- Update fluent bit 0.13.7 => 0.14.4
  * This fixes the escaping issue in the container logs
- Mooncake cloud support for agent (AKS only)
  * Ability to disable agent telemetry
  * Ability to onboard and ingest to mooncake cloud
- Add & populate 'ContainerStatusReason'  column to KubePodInventory
- Alertable (custom) metrics (to AzureMonitor - only for AKS clusters)
  * Cpuusagenanocores & % metric
  * MemoryWorkingsetBytes & % metric
  * MemoryRssBytes & % metric
  * Podcount by node, phase & namespace metric
  * Nodecount metric
- ContainerNodeInventory_CL to fixed type

### 01/09/2018 - Version microsoft/oms:ciprod01092019
- Omsagent - 1.8.1.256 (nov 2018 release)
- Persist fluentbit state between container restarts
- Populate 'TimeOfCommand' for agent ingest time for container logs
- Get node cpu usage from cpuusagenanoseconds (and convert to cpuusgaenanocores)
- Container Node Inventory - move to fluentD from OMI
- Mount docker.sock (Daemon set) as /var/run/host
- Add omsagent user to docker group
- Move to fixed type for kubeevents & kubeservices
- Disable collecting ENV for our oms agent container (daemonset & replicaset)
- Disable container inventory collection for 'sandbox' containers & non kubernetes managed containers
- Agent telemetry - ContainerLogsAgentSideLatencyMs
- Agent telemetry - PodCount
- Agent telemetry - ControllerCount
- Agent telemetry - K8S Version
- Agent telemetry - NodeCoreCapacity
- Agent telemetry - NodeMemoryCapacity
- Agent telemetry - KubeEvents (exceptions)
- Agent telemetry - Kubenodes (exceptions)
- Agent telemetry - kubepods (exceptions)
- Agent telemetry - kubeservices (exceptions)
- Agent telemetry - Daemonset , Replicaset as dimensions (bug fix)

### 11/29/2018 - Version microsoft/oms:ciprod11292018
- Disable Container Image inventory workflow
- Kube_Events memory leak fix for replica-set
- Timeout (30 secs) for outOMS
- Reduce critical lock duration for quicker log processing (for log enrichment)
- Disable OMI based Container Inventory workflow to fluentD based Container Inventory
- Moby support for the new Container Inventory workflow
- Ability to disable environment variables collection by individual container
- Bugfix - No inventory data due to container status(es) not available
- Agent telemetry cpu usage & memory usage (for DaemonSet and ReplicaSet)
- Agent telemetry - log generation rate
- Agent telemetry - container count per node
- Agent telemetry - collect container logs from agent (DaemonSet and ReplicaSet) as AI trace
- Agent telemetry - errors/exceptions for Container Inventory workflow
- Agent telemetry - Container Inventory Heartbeat

### 10/16/2018 - Version microsoft/oms:ciprod10162018-2
- Fix for containerID being 00000-00000-00000
- Move from fluentD to fluentbit for container log collection
- Seg fault fixes in json parsing for container inventory & container image inventory
- Telemetry enablement
- Remove ContainerPerf, ContainerServiceLog, ContainerProcess fluentd-->OMI workflows
- Update log level for all fluentD based workflows

### 7/31/2018 - Version microsoft/oms:ciprod07312018
- Changes for node lost scenario (roll-up pod & container statuses as Unknown)
- Discover unscheduled pods
- KubeNodeInventory - delimit multiple true node conditions for node status
- UTF Encoding support for container logs
- Container environment variable truncated to 200K
- Handle json parsing errors for OMI provider for docker
- Test mode enablement for ACS-engine testing
- Latest OMS agent (1.6.0-163)
- Latest OMI (1.4.2.5)


### 6/7/2018 - Version microsoft/oms:ciprod06072018
- Remove node-0 dependency
- Remove passing WSID & Key as environment variables and pass them as kubernetes secret (for non-AKS; we already pass them as secret for AKS)
- Please note that if you are manually deploying thru yaml you need to -
- Provide workspaceid & key as base64 encoded strings with in double quotes (.yaml has comments to do so as well)
- Provide cluster name twice (for each container – daemonset & replicaset)

### 5/8/2018 - Version microsoft/oms:ciprod05082018
- Kubernetes RBAC enablement
- Latest released omsagent (1.6.0-42)
- Bug fix so that we do not collect kube-system namespace container logs when kube api calls fail occasionally (Bug #215107)
- .yaml changes (for RBAC)