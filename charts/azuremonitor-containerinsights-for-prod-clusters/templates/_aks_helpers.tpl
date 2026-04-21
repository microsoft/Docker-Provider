{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Values.global.commonGlobals.CCPID $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Both formats are needed because the template is used by other adapter charts */}}
{{- define "enableKonnectivity" -}}
{{- $commonGlobals := "" }}
{{- if .Values.v1 }}
{{- $commonGlobals = (index .Values.v1 "commonGlobals") }}
{{- else }}
{{- $commonGlobals = .Values.global.commonGlobals }}
{{- end -}}
{{- if $commonGlobals.Konnectivity -}}
{{- if kindIs "invalid" $commonGlobals.Konnectivity.Enabled -}}
true
{{- else if $commonGlobals.Konnectivity.Enabled -}}
true
{{- end -}}
{{- end -}}
{{- end -}}

{{/* apiserver endpoint */}}
{{- define "apiserver_endpoint" }}
{{- if .Values.global.commonGlobals.PrivateConnect.enabled }}
{{- .Values.global.commonGlobals.PrivateConnect.privateIP }}
{{- else }}
{{- .Values.global.commonGlobals.endpointFQDN }}
{{- end }}
{{- end }}

{{- define "enableApiserverProxyForKms" -}}
{{- if and .Values.global.commonGlobals.PrivateConnect.enabled (ne .Values.global.AzureKeyVaultKms.keyVaultNetworkAccess "Private") -}}
true
{{- else if not (or .Values.global.commonGlobals.TunnelOpenVPN.Enabled (include "enableKonnectivityWithEgressSelector" .)) -}}
true
{{- end -}}
{{- end -}}

{{- define "enableAzureKmsProviderProxy" -}}
{{- if and .Values.global.AzureKeyVaultKms.enabled (include "enableKonnectivityWithEgressSelector" .) -}}
{{- if eq .Values.global.AzureKeyVaultKms.keyVaultNetworkAccess "Private" -}}
true
{{- else if .Values.global.AzureKeyVaultKms.previousKey -}}
{{- if eq .Values.global.AzureKeyVaultKms.previousKey.keyVaultNetworkAccess "Private" -}}
true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "enableKonnectivityProxyPodAndSvcCIDROnly" -}}
{{- if (include "enableKonnectivity" .) -}}
{{- if .Values.global.commonGlobals.Konnectivity.ProxyPodAndSvcCIDROnly -}}
true
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "enableKonnectivityWithEgressSelector" -}}
{{- if (include "enableKonnectivity" .) -}}
{{- if not .Values.global.commonGlobals.Konnectivity.ProxyPodAndSvcCIDROnly -}}
true
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "enableKonnectivityServerPreStop" -}}
{{- if (include "enableKonnectivity" .) -}}
{{- if .Values.global.commonGlobals.Konnectivity.enableKonnectivityServerPreStop -}}
{{- if semverCompare ">=1.28.0" .Values.global.commonGlobals.Versions.Kubernetes -}}
true
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "enableKonnectivityServerSeparateCert" -}}
  {{- if (include "enableKonnectivity" .) -}}
    {{- if .Values.global.commonGlobals.Konnectivity.EnableSeparateServerCert -}}
      {{- if semverCompare (printf ">=%s" .Values.global.commonGlobals.Konnectivity.EnableSeparateServerCertFromK8sVersion) .Values.global.commonGlobals.Versions.Kubernetes -}}
        true
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- define "loggingResourceId" -}}
{{- if .Values.global.commonGlobals.FleetHubProfile.isHubCluster }}
{{- .Values.global.commonGlobals.FleetHubProfile.fleetResourceID }}
{{- else }}
{{- .Values.global.commonGlobals.Customer.AzureResourceID }}
{{- end }}
{{- end }}

{{/*
Get the value of override update mode annotation,
default is "disabled" and only support "enabled" and "disabled" currently.
Return none and fall back to "disabled" if the value is not supported or current VPA is not existed.
*/}}
{{- define "getOverrideUpdateModeAnnotation" -}}
{{- if .current }}
  {{- if eq (index .current.metadata.annotations "kubernetes.azure.com/override-update-mode") "enabled" }}
    {{- "enabled" }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Try to get the override updateMode value if the override update mode annotation is enabled,
and the current VPA cr is existed. If not, return none and use the default updateMode "Initial"
*/}}
{{- define "getUpdateMode" -}}
{{- if .current }}
  {{- if eq (index .current.metadata.annotations "kubernetes.azure.com/override-update-mode") "enabled" }}
    {{- dict "current" .current | include "getOverrideUpdateMode" }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Get the value of override VPA update mode, user can override the updateMode in VPA cr
when the override update mode annotation is enabled, return none and use the default
updateMode value if the user input is invalid or any property is not existed
*/}}
{{- define "getOverrideUpdateMode" -}}
{{- /*
Use parentheses () to check the nested values existed due to the limitation of Helm
https://github.com/helm/helm/issues/8026
*/}}
{{- if ((((.current).spec).updatePolicy).updateMode) }}
  {{- if (dict "updateMode" .current.spec.updatePolicy.updateMode | include "isValidUpdateMode" ) }}
    {{- .current.spec.updatePolicy.updateMode | quote }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Check if the update mode is valid,
only support "Off", "Initial" and "Auto" update mode currently
*/}}
{{- define "isValidUpdateMode" -}}
{{- if not (has .updateMode (list "Recreate")) }}
true
{{- end }}
{{- end -}}

{{/*
Get the value of override min/max annotation,
default is "disabled" and only support "enabled" and "disabled" currently.
Return none and fall back to "disabled" if the value is not supported.
*/}}
{{- define "getOverrideMinMaxAnnotation" -}}
{{- if .current }}
  {{- if eq (index .current.metadata.annotations "kubernetes.azure.com/override-min-max") "enabled" }}
    {{- "enabled" }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Try to get the user override vpa min/max allowed value if the override min/max allowed annotation is enabled,
and the current VPA cr is existed.
If not, return none and use the default min/max allowed value.
*/}}
{{- define "getAllowedValue" -}}
{{- if .current }}
  {{- if eq (index .current.metadata.annotations "kubernetes.azure.com/override-min-max") "enabled" }}
    {{- (dict "current" .current "containerName" .containerName "resource" .resource) | include "getOverrideAllowedValue" }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Find the target container policy in VPA containerPolicies array
*/}}
{{- define "getVpaContainer" -}}
  {{- $name := .containerName }}
  {{- range $container := .containerPolicies }}
    {{- if eq $name $container.containerName }}
      {{- toYaml $container }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Get the user override vpa min/max allowed value from target container in current existing vpa cr
*/}}
{{- define "getOverrideAllowedValue" -}}
{{- /*
Use parentheses () to check the nested values existed due to the limitation of Helm
https://github.com/helm/helm/issues/8026
*/}}
{{- $container := (dict "containerName" .containerName "containerPolicies" .current.spec.resourcePolicy.containerPolicies) | include "getVpaContainer" | fromYaml }}
{{- if eq .resource "maxCPU" }}
  {{- if ((($container).maxAllowed).cpu) }}
    {{- $container.maxAllowed.cpu }}
  {{- end }}
{{- end }}
{{- if eq .resource "maxMemory" }}
  {{- if ((($container).maxAllowed).memory) }}
    {{- $container.maxAllowed.memory }}
  {{- end }}
{{- end }}
{{- if eq .resource "minCPU" }}
  {{- if ((($container).minAllowed).cpu) }}
    {{- $container.minAllowed.cpu }}
  {{- end }}
{{- end }}
{{- if eq .resource "minMemory" }}
  {{- if ((($container).minAllowed).memory) }}
    {{- $container.minAllowed.memory }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Get the value of override requests limits annotation,
default is "disabled" and only support "enabled" and "disabled" currently.
Return none and fall back to "disabled" if the value is not supported.
*/}}
{{- define "getOverrideRequestsLimitsAnnotation" -}}
{{- if .current }}
  {{- if eq (index .current.metadata.annotations "kubernetes.azure.com/override-requests-limits") "enabled" }}
    {{- "enabled" }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Find target container in deployment / daemonset containers property
*/}}
{{- define "getContainer" -}}
  {{- $name := .containerName }}
  {{- range $container := .containers }}
    {{- if eq $name $container.name }}
      {{- toYaml $container }}
    {{- end }}
  {{- end }}
{{- end -}}

{{/*
Get user override resource requests/limits value from target container in existing deployment / daemonset
*/}}
{{- define "getOverrideRequestsLimitsValue" -}}
{{- $container := (dict "containerName" .containerName "containers" .current.spec.template.spec.containers) | include "getContainer" | fromYaml }}
{{- if eq .resource "requestCPU" }}
  {{- if (((($container).resources).requests).cpu) }}
    {{- $container.resources.requests.cpu }}
  {{- end }}
{{- end }}
{{- if eq .resource "requestMemory" }}
  {{- if (((($container).resources).requests).memory) }}
    {{- $container.resources.requests.memory }}
  {{- end }}
{{- end }}
{{- if eq .resource "limitCPU" }}
  {{- if (((($container).resources).limits).cpu) }}
    {{- $container.resources.limits.cpu }}
  {{- end }}
{{- end }}
{{- if eq .resource "limitMemory" }}
  {{- if (((($container).resources).limits).memory) }}
    {{- $container.resources.limits.memory }}
  {{- end }}
{{- end }}
{{- end -}}

{{/*
Get user override requests/limits value when current deployment/daemonset and override annotation is existed,
if not, this function will return none and caller should set the default/fallback resource requests/limits value.
*/}}
{{- define "getRequestsLimitsValue" -}}
{{- if .current }}
  {{- if eq (index .current.metadata.annotations "kubernetes.azure.com/override-requests-limits") "enabled" }}
    {{- (dict "current" .current "containerName" .containerName "resource" .resource) | include "getOverrideRequestsLimitsValue" }}
  {{- end }}
{{- end }}
{{- end -}}

{{/* should use AzureStackCloud */}}
{{- define "should_use_azurestackcloud" -}}
  {{- $cloud_environment := (.Values.global.commonGlobals.CloudEnvironment | default "azurepubliccloud" | lower) }}
  {{- has $cloud_environment (list "usnat" "ussec" "azurebleucloud" "azuredeloscloud") -}}
{{- end }}

{{/* should mount ca certs from host */}}
{{- define "should_mount_hostca" -}}
  {{- $cloud_environment := (.Values.global.commonGlobals.CloudEnvironment | default "azurepubliccloud" | lower) }}
  {{- has $cloud_environment (list "usnat" "ussec" "azurebleucloud" "azuredeloscloud") -}}
{{- end }}