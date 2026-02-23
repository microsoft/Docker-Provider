{{/*
Arc K8s Extension Settings Helper
Following the pattern from prometheus-collector's arc-extension-settings
This consolidates all deployment-mode-specific configuration logic
*/}}
{{- define "arc-extension-settings" -}}

{{/* Detect deployment mode - guard Azure for AKS-only or standalone values */}}
{{- $hasAzure := and (hasKey .Values "Azure") (hasKey .Values.Azure "Extension") -}}
{{- $isArcExtension := and $hasAzure (or (ne .Values.Azure.Extension.Name "") (ne .Values.Azure.Extension.ResourceId "")) -}}
{{- $hasArcClusterResourceId := and (hasKey .Values "Azure") (hasKey .Values.Azure "Cluster") (ne .Values.Azure.Cluster.ResourceId "<your_cluster_id>") -}}
{{- $isAKSAddon := and (hasKey .Values "OmsAgent") (ne .Values.OmsAgent.aksResourceID "<your_cluster_id>") (not $isArcExtension) -}}
{{- $isStandalone := and (not $isArcExtension) (not $isAKSAddon) -}}

{{/* Deployment mode detection */}}
deploymentMode: {{ if $isArcExtension }}arc-extension{{ else if $isAKSAddon }}aks-addon{{ else }}standalone{{ end }}
isArcExtension: {{ $isArcExtension }}
isAKSAddon: {{ $isAKSAddon }}
isStandalone: {{ $isStandalone }}

{{/* Cluster information - unified from both Arc and AKS sources */}}
{{- if $isArcExtension }}
resourceId: {{ .Values.Azure.Cluster.ResourceId }}
region: {{ .Values.Azure.Cluster.Region }}
clusterName: {{ .Values.amalogs.env.clusterName }}
{{- else if $isAKSAddon }}
resourceId: {{ .Values.OmsAgent.aksResourceID }}
region: {{ default .Values.OmsAgent.aksRegion .Values.global.commonGlobals.Region }}
clusterName: {{ .Values.OmsAgent.aksClusterName | default "" }}
{{- else }}
resourceId: {{ .Values.amalogs.env.clusterId | default "" }}
region: {{ .Values.amalogs.env.clusterRegion | default .Values.global.commonGlobals.Region }}
clusterName: {{ .Values.amalogs.env.clusterName }}
{{- end }}

{{/* Cloud environment - safe when Azure absent (AKS-only values) */}}
{{- $azureCloud := "" }}
{{- if and (hasKey .Values "Azure") (hasKey .Values.Azure "Cluster") }}{{ $azureCloud = lower .Values.Azure.Cluster.Cloud }}{{ end }}
cloudEnvironment: {{ default $azureCloud (lower .Values.global.commonGlobals.CloudEnvironment | default "azurepubliccloud") }}

{{/* Distribution - e.g., openshift, aks_edge_k3s, etc. */}}
distribution: {{ if and (hasKey .Values "Azure") (hasKey .Values.Azure "Cluster") }}{{ .Values.Azure.Cluster.Distribution | default "generic" }}{{ else }}generic{{ end }}

{{/* Authentication configuration */}}
{{- if $isArcExtension }}
usingAADAuth: {{ .Values.amalogs.useAADAuth | default false }}
{{- else if $isAKSAddon }}
usingAADAuth: {{ eq .Values.OmsAgent.isUsingAADAuth "true" }}
{{- else }}
usingAADAuth: false
{{- end }}

{{/* Access token secret name - safe when OmsAgent absent (standalone) */}}
accessTokenSecretName: {{ if hasKey .Values "OmsAgent" }}{{ .Values.OmsAgent.accessTokenSecretName | default "ama-logs-secret" }}{{ else }}ama-logs-secret{{ end }}

{{/* Arc Extension specific settings */}}
{{- if $isArcExtension }}
arcExtensionName: {{ .Values.Azure.Extension.Name }}
arcExtensionResourceId: {{ .Values.Azure.Extension.ResourceId }}

{{/* Proxy settings for Arc */}}
isProxyEnabled: {{ and (.Values.Azure.proxySettings.isProxyEnabled) (not .Values.amalogs.ignoreExtensionProxySettings) }}
httpProxy: {{ .Values.Azure.proxySettings.httpProxy }}
httpsProxy: {{ .Values.Azure.proxySettings.httpsProxy }}
noProxy: {{ .Values.Azure.proxySettings.noProxy }}
proxyCert: {{ .Values.Azure.proxySettings.proxyCert }}
isCustomCert: {{ .Values.Azure.proxySettings.isCustomCert }}
ignoreProxySettings: {{ .Values.amalogs.ignoreExtensionProxySettings | default false }}
{{- else }}
{{/* AKS addon: proxy from OmsAgent. Standalone: no proxy in settings (use Arc path if needed). */}}
{{- $hasProxy := and (hasKey .Values "OmsAgent") (or .Values.OmsAgent.httpProxy .Values.OmsAgent.httpsProxy) }}
isProxyEnabled: {{ $hasProxy }}
httpProxy: {{ if hasKey .Values "OmsAgent" }}{{ .Values.OmsAgent.httpProxy | default "" }}{{ else }}{{ "" }}{{ end }}
httpsProxy: {{ if hasKey .Values "OmsAgent" }}{{ .Values.OmsAgent.httpsProxy | default "" }}{{ else }}{{ "" }}{{ end }}
noProxy: ""
proxyCert: {{ if hasKey .Values "OmsAgent" }}{{ .Values.OmsAgent.trustedCA | default "" }}{{ else }}{{ "" }}{{ end }}
isCustomCert: false
ignoreProxySettings: false
{{- end }}

{{/* Workspace credentials */}}
{{- if $isArcExtension }}
workspaceID: {{ .Values.amalogs.secret.wsid }}
workspaceKey: {{ .Values.amalogs.secret.key }}
{{- else if $isAKSAddon }}
workspaceID: {{ .Values.OmsAgent.workspaceID }}
workspaceKey: {{ .Values.OmsAgent.workspaceKey }}
{{- else }}
workspaceID: {{ .Values.amalogs.secret.wsid }}
workspaceKey: {{ .Values.amalogs.secret.key }}
{{- end }}

{{/* Domain configuration based on cloud environment - safe when Azure/OmsAgent absent. Output string only (no boolean). */}}
{{- $cloudEnv := default $azureCloud (lower .Values.global.commonGlobals.CloudEnvironment | default "azurepubliccloud") | upper -}}
{{- $isFairfax := and (hasKey .Values "OmsAgent") (eq .Values.OmsAgent.isFairfax true) -}}
{{- $domain := "opinsights.azure.com" -}}
{{- if eq $cloudEnv "AZURECHINACLOUD" }}{{ $domain = "opinsights.azure.cn" }}{{ end -}}
{{- if or (eq $cloudEnv "AZUREUSGOVERNMENT") $isFairfax }}{{ $domain = "opinsights.azure.us" }}{{ end -}}
{{- if eq $cloudEnv "USNAT" }}{{ $domain = "opinsights.azure.eaglex.ic.gov" }}{{ end -}}
{{- if eq $cloudEnv "USSEC" }}{{ $domain = "opinsights.azure.microsoft.scloud" }}{{ end -}}
{{- if eq $cloudEnv "AZUREBLEUCLOUD" }}{{ $domain = "opinsights.sovcloud-api.fr" }}{{ end -}}
domain: {{ $domain }}

{{/* Feature flags - unified from both value structures */}}
{{- if $isAKSAddon }}
multitenancyEnabled: {{ .Values.OmsAgent.isMultitenancyLogsEnabled | default false }}
rsvpaEnabled: {{ .Values.OmsAgent.isRSVPAEnabled | default false }}
syslogEnabled: {{ .Values.OmsAgent.isSyslogEnabled | default false }}
sidecarScrapingEnabled: {{ .Values.OmsAgent.isSidecarScrapingEnabled | default true }}
prometheusScrapingDisabled: {{ .Values.OmsAgent.isPrometheusMetricsScrapingDisabled | default false }}
retinaFlowLogsEnabled: {{ .Values.OmsAgent.isRetinaFlowLogsEnabled | default false }}
resourceOptimizationEnabled: {{ .Values.OmsAgent.isResourceOptimizationEnabled | default false }}
windowsAMAEnabled: {{ .Values.OmsAgent.isWindowsAMAEnabled | default true }}
windowsFluentBitEnabled: {{ .Values.OmsAgent.isWindowsAMAFluentBitEnabled | default false }}
windowsBurstableQoSEnabled: {{ .Values.OmsAgent.isWindowsBurstableQoSEnabled | default true }}
windowsAddonTokenAdapterDisabled: {{ .Values.OmsAgent.isWindowsAddonTokenAdapterDisabled | default false }}
customMetricsEnabled: {{ not .Values.OmsAgent.isCustomMetricsDisabled }}
telegrafLivenessprobeEnabled: {{ .Values.OmsAgent.isTelegrafLivenessprobeEnabled | default false }}
openTelemetryLogsEnabled: {{ .Values.AppmonitoringAgent.isOpenTelemetryLogsEnabled | default false }}
openTelemetryLogsPort: {{ .Values.AppmonitoringAgent.openTelemetryLogsPort | default 28331 }}
appMonitoringEnabled: {{ .Values.AppmonitoringAgent.enabled | default false }}
legacyAddonDelivery: {{ .Values.legacyAddonDelivery | default false }}
{{- else }}
multitenancyEnabled: false
rsvpaEnabled: false
syslogEnabled: {{ .Values.amalogs.syslog.enabled | default false }}
sidecarScrapingEnabled: {{ .Values.amalogs.sidecarscraping | default true }}
prometheusScrapingDisabled: false
retinaFlowLogsEnabled: false
resourceOptimizationEnabled: false
windowsAMAEnabled: true
windowsFluentBitEnabled: false
windowsBurstableQoSEnabled: true
windowsAddonTokenAdapterDisabled: false
customMetricsEnabled: {{ .Values.amalogs.enableCustomMetrics | default false }}
telegrafLivenessprobeEnabled: {{ .Values.amalogs.enableTelegrafLivenessprobe | default false }}
openTelemetryLogsEnabled: false
openTelemetryLogsPort: 28331
appMonitoringEnabled: false
legacyAddonDelivery: false
{{- end }}

{{/* Scheduling configuration */}}
{{- if $isArcExtension }}
scheduleOnTaintedNodes: {{ .Values.amalogs.scheduleOnTaintedNodes | default false }}
priority: {{ .Values.amalogs.priority | default 10 }}
rbacEnabled: {{ .Values.amalogs.rbac | default true }}
{{- else }}
scheduleOnTaintedNodes: false
priority: 10
rbacEnabled: true
{{- end }}

{{/* Service account token configuration */}}
{{- if $isArcExtension }}
enableServiceAccountTimeBoundToken: {{ .Values.amalogs.enableServiceAccountTimeBoundToken | default true }}
{{- else }}
enableServiceAccountTimeBoundToken: true
{{- end }}

{{/* Dynamic sizing configuration (AKS addon only) */}}
{{- if $isAKSAddon }}
enableDaemonSetSizing: {{ and .Values.global.commonGlobals.isAutomaticSKU .Values.OmsAgent.enableDaemonSetSizing }}
{{- else }}
enableDaemonSetSizing: false
{{- end }}

{{/* Image configuration */}}
{{- if $isAKSAddon }}
imageRepo: "mcr.microsoft.com/azuremonitor/containerinsights/ciprod"
imageTagLinux: {{ .Values.OmsAgent.imageTagLinux | default "3.1.34" }}
imageTagWindows: {{ .Values.OmsAgent.imageTagWindows | default "win-3.1.34" }}
imagePullPolicy: {{ if .Values.OmsAgent.isImagePullPolicyAlways }}Always{{ else }}IfNotPresent{{ end }}
{{- else }}
imageRepo: {{ .Values.amalogs.image.repo | default "mcr.microsoft.com/azuremonitor/containerinsights/ciprod" }}
imageTagLinux: {{ .Values.amalogs.image.tag | default "3.1.34" }}
imageTagWindows: {{ .Values.amalogs.image.tagWindows | default "win-3.1.34" }}
imagePullPolicy: {{ .Values.amalogs.image.pullPolicy | default "IfNotPresent" }}
{{- end }}

{{/* Certificate mounting for sovereign clouds */}}
{{- $shouldMountCerts := or (eq $cloudEnv "USNAT") (eq $cloudEnv "USSEC") (eq $cloudEnv "AZUREBLEUCLOUD") -}}
mountMarinerCerts: {{ $shouldMountCerts }}
mountUbuntuCerts: {{ $shouldMountCerts }}
{{- if and (hasKey .Values "Azure") (hasKey .Values.Azure "Cluster") (or (eq .Values.Azure.Cluster.Distribution "aks_edge_k3s") (eq .Values.Azure.Cluster.Distribution "aks_edge_k8s")) }}
mountUbuntuCerts: false
{{- end }}

{{/* Test mode - templates should use $settings.isTestMode (this is the single source) */}}
{{- if $isArcExtension }}
isTestMode: {{ .Values.amalogs.ISTEST | default false }}
{{- else }}
isTestMode: false
{{- end }}

{{/* High log scale mode */}}
{{- if $isArcExtension }}
enableHighLogScaleMode: {{ .Values.amalogs.enableHighLogScaleMode | default false }}
{{- else }}
enableHighLogScaleMode: false
{{- end }}

{{/* ArcA cluster flag */}}
{{- if $isArcExtension }}
isArcACluster: {{ .Values.amalogs.isArcACluster | default false }}
{{- else }}
isArcACluster: false
{{- end }}

{{/* Syslog port configuration */}}
{{- if $isAKSAddon }}
syslogPort: {{ .Values.OmsAgent.syslogHostPort | default "28330" }}
shouldMountSyslogHostPort: {{ .Values.OmsAgent.shouldMountSyslogHostPort | default true }}
{{- else if $isArcExtension }}
syslogPort: {{ .Values.amalogs.syslog.syslogPort | default "28330" }}
shouldMountSyslogHostPort: {{ .Values.amalogs.syslog.enabled | default false }}
{{- else }}
syslogPort: "28330"
shouldMountSyslogHostPort: false
{{- end }}

{{/* Identity client ID */}}
{{- if $isAKSAddon }}
identityClientID: {{ .Values.OmsAgent.identityClientID | default "" }}
{{- else }}
identityClientID: ""
{{- end }}

{{/* Custom metrics endpoint */}}
{{- if $isArcExtension }}
  {{- if ne .Values.amalogs.metricsEndpoint "<your_metrics_endpoint>" }}
customMetricsEndpoint: {{ .Values.amalogs.metricsEndpoint }}
  {{- else if ne .Values.Azure.proxySettings.autonomousFqdn "<arca_autonomous_fqdn>" }}
customMetricsEndpoint: "https://metricsingestiongateway.monitoring.{{ .Values.Azure.proxySettings.autonomousFqdn }}"
  {{- else }}
customMetricsEndpoint: ""
  {{- end }}
{{- else }}
customMetricsEndpoint: ""
{{- end }}

{{/* Token audience for custom endpoints */}}
{{- if and $isArcExtension (ne .Values.amalogs.tokenAudience "<your_token_audience>") }}
tokenAudience: {{ .Values.amalogs.tokenAudience }}
{{- else }}
tokenAudience: ""
{{- end }}

{{- end -}}