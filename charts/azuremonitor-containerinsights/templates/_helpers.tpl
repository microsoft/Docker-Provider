{{/*
Consolidated helper functions for azuremonitor-containerinsights chart
Merged from: _aks_addon-images.tpl, _aks_images.tpl, _aks_helpers.tpl, _aks_common.tpl
*/}}

{{/*
=============================================================================
Image Tags Section
=============================================================================
*/}}

{{/* Get addon image tag - used for ama-logs and addon-resizer */}}
{{- define "get.addonImageTag" -}}
  {{- if eq .component "addon-resizer" -}}
v1.8.23-4
  {{- else if eq .component "ama-logs-linux" -}}
3.1.34
  {{- else if eq .component "ama-logs-win" -}}
win-3.1.34
  {{- end -}}
{{- end -}}

{{/* Get image tag - used for addon-token-adapter */}}
{{- define "get.imagetag" -}}
{{- if eq .component "addon-token-adapter-linux" -}}
master.250902.1
{{- else if eq .component "addon-token-adapter-windows" -}}
master.250902.1
{{- end -}}
{{- end -}}

{{/*
=============================================================================
MCR Repository Section
=============================================================================
*/}}

{{/* MCR repository base - returns cloud-specific MCR URL */}}
{{- define "mcr_repository_base" }}
{{- $cloud_environment := (.Values.global.commonGlobals.CloudEnvironment| default "AZUREPUBLICCLOUD") }}
{{- if (eq $cloud_environment "AZURECHINACLOUD") }}
{{- "mcr.azk8s.cn" }}
{{- else if (eq $cloud_environment "USNat") }}
{{- "mcr.microsoft.eaglex.ic.gov" }}
{{- else if (eq $cloud_environment "USSec") }}
{{- "mcr.microsoft.scloud" }}
{{- else }}
{{- "mcr.microsoft.com" }}
{{- end }}
{{- end }}

{{/* MCR repository template for addon charts */}}
{{- define "addon_mcr_repository_base" }}
{{- template "mcr_repository_base" . }}
{{- end }}

{{/*
=============================================================================
Host CA Certificate Mounting Section
=============================================================================
*/}}

{{/* Check if host CA certs should be mounted for specific cloud environments */}}
{{- define "should_mount_hostca" -}}
  {{- $cloud_environment := (.Values.global.commonGlobals.CloudEnvironment | default "azurepubliccloud" | lower) }}
  {{- has $cloud_environment (list "usnat" "ussec" "azurebleucloud") -}}
{{- end }}