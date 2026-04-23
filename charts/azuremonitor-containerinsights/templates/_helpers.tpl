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
{{/*
=============================================================================
RESOURCE QUANTITY HELPERS (for toggle processing)
=============================================================================
*/}}

{{/*
Compare two resource quantities and return the maximum.
This replicates the Go maxResourceValue function using Kubernetes resource.ParseQuantity logic.
Supports all Kubernetes quantity formats: decimal fractions, binary/decimal units, CPU millicores.
Usage: {{ include "maxResourceValue" (list "1.5Gi" "2196Mi") }}
*/}}
{{- define "maxResourceValue" -}}
{{- $val1 := index . 0 -}}
{{- $val2 := index . 1 -}}

{{/* Parse val1 to bytes/millicores */}}
{{- $val1Parsed := include "parseQuantity" $val1 -}}
{{- $val2Parsed := include "parseQuantity" $val2 -}}

{{/* Compare parsed values */}}
{{- if ge ($val1Parsed | int64) ($val2Parsed | int64) -}}
{{- $val1 -}}
{{- else -}}
{{- $val2 -}}
{{- end -}}
{{- end }}

{{/*
Parse a Kubernetes resource quantity to comparable integer value.
Mimics k8s.io/apimachinery/pkg/api/resource.ParseQuantity behavior.
Returns value in smallest unit (bytes for memory, millicores for CPU).
*/}}
{{- define "parseQuantity" -}}
{{- $quantity := toString . -}}
{{- $quantity = trim $quantity -}}

{{/* Handle zero/empty */}}
{{- if or (eq $quantity "") (eq $quantity "0") -}}
0
{{- else -}}

{{/* Extract number and suffix using regex */}}
{{- $number := regexFind "^[0-9.]+" $quantity -}}
{{- $suffix := trimPrefix $number $quantity -}}

{{/* Parse the numeric part - handle decimals */}}
{{- $intPart := 0 -}}
{{- $fracPart := 0 -}}
{{- $fracDivisor := 1 -}}

{{- if contains "." $number -}}
  {{- $parts := split "." $number -}}
  {{- $intPart = index $parts "_0" | int -}}
  {{- $fracStr := index $parts "_1" -}}
  {{- $fracPart = $fracStr | int -}}
  {{- $fracLen := len $fracStr -}}
  {{- if eq $fracLen 1 -}}{{- $fracDivisor = 10 -}}
  {{- else if eq $fracLen 2 -}}{{- $fracDivisor = 100 -}}
  {{- else if eq $fracLen 3 -}}{{- $fracDivisor = 1000 -}}
  {{- else if eq $fracLen 4 -}}{{- $fracDivisor = 10000 -}}
  {{- else if eq $fracLen 5 -}}{{- $fracDivisor = 100000 -}}
  {{- else -}}{{- $fracDivisor = 1000000 -}}
  {{- end -}}
{{- else -}}
  {{- $intPart = $number | int -}}
{{- end -}}

{{/* Convert based on suffix - return in base units (bytes for memory, millicores for CPU) */}}
{{- $result := 0 -}}

{{/* Binary suffixes (1024-based) */}}
{{- if eq $suffix "Ki" -}}
  {{- $result = add (mul $intPart 1024) (div (mul $fracPart 1024) $fracDivisor) -}}
{{- else if eq $suffix "Mi" -}}
  {{- $result = add (mul $intPart 1048576) (div (mul $fracPart 1048576) $fracDivisor) -}}
{{- else if eq $suffix "Gi" -}}
  {{- $result = add (mul $intPart 1073741824) (div (mul $fracPart 1073741824) $fracDivisor) -}}
{{- else if eq $suffix "Ti" -}}
  {{- $result = add (mul $intPart 1099511627776) (div (mul $fracPart 1099511627776) $fracDivisor) -}}
{{- else if eq $suffix "Pi" -}}
  {{- $result = add (mul $intPart 1125899906842624) (div (mul $fracPart 1125899906842624) $fracDivisor) -}}

{{/* Decimal suffixes (1000-based) */}}
{{- else if eq $suffix "k" -}}
  {{- $result = add (mul $intPart 1000) (div (mul $fracPart 1000) $fracDivisor) -}}
{{- else if eq $suffix "M" -}}
  {{- $result = add (mul $intPart 1000000) (div (mul $fracPart 1000000) $fracDivisor) -}}
{{- else if eq $suffix "G" -}}
  {{- $result = add (mul $intPart 1000000000) (div (mul $fracPart 1000000000) $fracDivisor) -}}
{{- else if eq $suffix "T" -}}
  {{- $result = add (mul $intPart 1000000000000) (div (mul $fracPart 1000000000000) $fracDivisor) -}}
{{- else if eq $suffix "P" -}}
  {{- $result = add (mul $intPart 1000000000000000) (div (mul $fracPart 1000000000000000) $fracDivisor) -}}

{{/* CPU millicores */}}
{{- else if eq $suffix "m" -}}
  {{- $result = add (mul $intPart 1) (div $fracPart $fracDivisor) -}}

{{/* No suffix - treat as base unit (assume CPU cores, convert to millicores) */}}
{{- else if eq $suffix "" -}}
  {{- if contains "." $number -}}
    {{/* Decimal number without suffix - CPU cores to millicores */}}
    {{- $result = add (mul $intPart 1000) (div (mul $fracPart 1000) $fracDivisor) -}}
  {{- else -}}
    {{/* Integer without suffix - CPU cores to millicores */}}
    {{- $result = mul $intPart 1000 -}}
  {{- end -}}

{{/* Unknown suffix - treat as base unit */}}
{{- else -}}
  {{- $result = $intPart -}}
{{- end -}}

{{- $result -}}
{{- end -}}
{{- end }}
