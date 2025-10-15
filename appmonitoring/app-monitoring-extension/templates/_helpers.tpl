{{/* MCR repository template for extension charts */}}
{{- define "mcr_repository_base" }}
{{- $cloud_environment := (.Values.Azure.Cluster.Cloud | default "AZUREPUBLICCLOUD") }}
{{- if (eq $cloud_environment "ValidationCluster") }}
{{- "appmonitoring.azurecr.io" }}
{{- else if (eq $cloud_environment "AZURECHINACLOUD") }}
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