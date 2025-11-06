{{/* MCR repository template for extension charts */}}
{{- define "mcr_repository_base" }}
{{- $cloud_environment := (lower (.Values.Azure.Cluster.Cloud | default "AZUREPUBLICCLOUD")) }}
{{- if (eq $cloud_environment "validationcluster") }}
{{- "appmonitoring.azurecr.io" }}
{{- else if (eq $cloud_environment "azurechinacloud") }}
{{- "mcr.azk8s.cn" }}
{{- else if (eq $cloud_environment "usnat") }}
{{- "mcr.microsoft.eaglex.ic.gov" }}
{{- else if (eq $cloud_environment "ussec") }}
{{- "mcr.microsoft.scloud" }}
{{- else }}
{{- "mcr.microsoft.com" }}
{{- end }}
{{- end }}

{{- define "addon_mcr_repository_base" }}
{{- template "mcr_repository_base" . }}
{{- end }}