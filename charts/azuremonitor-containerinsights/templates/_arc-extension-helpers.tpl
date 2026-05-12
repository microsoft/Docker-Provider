{{/*
Arc extension helper to determine if this is an ARC or AKS deployment
*/}}

{{ define "arc-extension-settings" }}
# Get resource ID from multiple possible sources
{{- $resourceId := "" }}
{{- if and .Values.Azure .Values.Azure.Cluster .Values.Azure.Cluster.ResourceId }}
  {{- $resourceId = .Values.Azure.Cluster.ResourceId }}
{{- else if and .Values.OmsAgent .Values.OmsAgent.aksResourceID }}
  {{- $resourceId = .Values.OmsAgent.aksResourceID }}
{{- else if and .Values.global .Values.global.commonGlobals .Values.global.commonGlobals.Customer .Values.global.commonGlobals.Customer.AzureResourceID }}
  {{- $resourceId = .Values.global.commonGlobals.Customer.AzureResourceID }}
{{- end }}

# If resource ID contains managedclusters it's AKS, otherwise it's Arc
{{- if and $resourceId (contains "microsoft.containerservice/managedclusters" (lower $resourceId)) }}
isArcExtension: false
{{- else }}
isArcExtension: true
{{- end }}

{{- end }}