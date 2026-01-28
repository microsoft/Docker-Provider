{{/* MCR repository template for adapter charts */}}
{{- define "mcr_repository_base_adapter_chart" }}
{{- $cloud_environment := ((index .Values.v1 "commonGlobals").CloudEnvironment | default "AZUREPUBLICCLOUD") }}
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

{{- define "addon_mcr_repository_base" }}
{{- template "mcr_repository_base" . }}
{{- end }}

{{/* ccp_image_repository_base_by_component returns the image repository to use for a ccp component.
     Caller should provide the "component" (the ccp component name), "version" (the ccp k8s version) and "Values" (the helm values object) parameters:

        {{- with $image_settings := (dict "component" "kube-apiserver" "version" .Values.global.commonGlobals.Versions.Kubernetes "Values" .Values) }}
        {{ include "ccp_image_repository_base_by_component" $image_settings }}
        {{- end }}

     The component name and k8s version will be concatenated as "<component>-<version>" to look up the override in the toggle.

     When the `use-internal-container-image-override-component` toggle is enabled for the specified component and k8s version, a cloud based
     private repository will be used, otherwise, the value will fallback to `mcr_repoistory_base`.
     Components that expect to be included in the embargo process should use this ACR repository. */}}
{{- define "ccp_image_repository_base_by_component" }}
  {{- $key := (print .component "-" .version) }}
  {{- if (hasKey .Values.global.commonGlobals.InternalContainerRegistry.enabledComponentOverrides $key) }}
    {{- template "ccp_image_repository_base" . }}
  {{- else }}
    {{- template "mcr_repository_base" . }}
  {{- end }}
{{- end }}

{{/* ccp_image_repository_base returns the ACR repository for embargoed CVE images.
     This template is intended to be called by ccp_image_repository_base_by_component and acr pull template only.
     Caller should use ccp_image_repository_base_by_component for component based value. */}}
{{- define "ccp_image_repository_base" }}
  {{- $cloud_environment := (.Values.global.commonGlobals.CloudEnvironment | upper | default "AZUREPUBLICCLOUD") }}
  {{- if (or (eq $cloud_environment "AZUREUSGOVCLOUD") (eq $cloud_environment "AZUREUSGOVERNMENTCLOUD")) }}
    {{- "acsdeployment.azurecr.us"}}
  {{- else if (eq $cloud_environment "AZURECHINACLOUD") }}
    {{- "acsdeployment.azurecr.cn" }}
  {{- else if (eq $cloud_environment "USNAT") }}
    {{- "acsdeployment.azurecr.eaglex.ic.gov" }}
  {{- else if (eq $cloud_environment "USSEC") }}
    {{- "acsdeployment.azurecr.microsoft.scloud" }}
  {{- else }}
    {{- "acsproddeployment.azurecr.io" }}
  {{- end }}
{{- end }}

{{/* ccp_get_imagetag_by_component returns the image tag to use for a ccp component.
     Caller should provide the "component" (the ccp component name), "version" (the ccp k8s version) and "Values" (the helm values object) parameters:

        {{- with $image_settings := (dict "component" "kube-apiserver" "version" .Values.global.commonGlobals.Versions.Kubernetes "Values" .Values) }}
        {{ include "ccp_get_imagetag_by_component" $image_settings }}
        {{- end }}

     When the `use-internal-container-image-override-component` toggle is enabled for the specified component and k8s version,
     the override tag will be used, otherwise, the value will fallback to `get.imagetag`.

     See also: ccp_image_repository_base_by_component */}}
{{- define "ccp_get_imagetag_by_component" }}
  {{- $key := (print .component "-" .version) }}
  {{- if (hasKey .Values.global.commonGlobals.InternalContainerRegistry.enabledComponentOverrides $key) }}
    {{- (index .Values.global.commonGlobals.InternalContainerRegistry.enabledComponentOverrides $key) }}
  {{- else }}
    {{- template "get.imagetag" . }}
  {{- end }}
{{- end }}

{{/* ccp_get_ccpImageTag_by_component uses "get.ccpImageTag" as fallback.

     See also: ccp_get_imagetag_by_component */}}
{{- define "ccp_get_ccpImageTag_by_component" }}
  {{- $key := (print .component "-" .version) }}
  {{- if (hasKey .Values.global.commonGlobals.InternalContainerRegistry.enabledComponentOverrides $key) }}
    {{- (index .Values.global.commonGlobals.InternalContainerRegistry.enabledComponentOverrides $key) }}
  {{- else }}
    {{- template "get.ccpImageTag" . }}
  {{- end }}
{{- end }}

{{/* nodeaffinity on nodepool */}}
{{- define "nodepool_affinity" -}}
{{- if .Values.global.commonGlobals.requireDedicatedNodepool -}}
preferredDuringSchedulingIgnoredDuringExecution:
- weight: 100
  preference:
    matchExpressions:
    - key: agentpool
      operator: In
      values:
      - cx-{{ .Values.global.CCPID }}
{{- else -}}
requiredDuringSchedulingIgnoredDuringExecution:
  nodeSelectorTerms:
  - matchExpressions:
    - key: agentpool
      operator: In
      values:
      - agentpool1
{{- end -}}
{{- end -}}

{{- define "addon_nodepool_mode_affinity_hard" -}}
{{- if .Values.global.commonGlobals.addonRequireSystemPool }}
- key: kubernetes.azure.com/mode
  operator: In
  values:
  - system
{{- end -}}
{{- end -}}

{{- define "addon_nodepool_mode_affinity_soft" -}}
{{- if not .Values.global.commonGlobals.addonRequireSystemPool }}
- weight: 100
  preference:
    matchExpressions:
    - key: kubernetes.azure.com/mode
      operator: In
      values:
      - system
{{- end -}}
{{- end -}}

{{/* tolerations on nodepool */}}
{{- define "nodepool_toleration" -}}
- key: "agentpool"
  operator: "Equal"
  value: "cx-{{ .Values.global.CCPID }}"
  effect: "NoExecute"
{{- end }}
