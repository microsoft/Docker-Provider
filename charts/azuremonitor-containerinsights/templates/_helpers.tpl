{{/* vim: set filetype=mustache: */}}
{{/*
Unified helper functions for azuremonitor-containerinsights chart
This file merges helpers from both AKS addon and Arc K8s extension charts
*/}}

{{/*
=============================================================================
CHART NAMING HELPERS (from Arc chart)
=============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "azuremonitor-containers.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "azuremonitor-containers.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "azuremonitor-containers.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
=============================================================================
IMAGE TAGS SECTION (from AKS chart)
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
MCR REPOSITORY SECTION (from AKS chart)
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
HOST CA CERTIFICATE MOUNTING SECTION (from AKS chart)
=============================================================================
*/}}

{{/* Check if host CA certs should be mounted for specific cloud environments */}}
{{- define "should_mount_hostca" -}}
  {{- $cloud_environment := (.Values.global.commonGlobals.CloudEnvironment | default "azurepubliccloud" | lower) }}
  {{- has $cloud_environment (list "usnat" "ussec" "azurebleucloud") -}}
{{- end }}