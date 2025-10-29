{- /*
  This function adds the hostAliases for tigera operator.
*/ -}}
{{- define "podspec.tigeraHostaliases" -}}
{{- if and .Values.global.commonGlobals.PrivateLink.privateIP -}}
hostAliases:
- hostnames:
  - {{ .Values.global.commonGlobals.endpointFQDN }}
  ip: {{ .Values.global.commonGlobals.PrivateLink.privateIP }}
{{- else if and .Values.global.commonGlobals.PrivateConnect.enabled .Values.global.commonGlobals.PrivateConnect.privateIP -}}
hostAliases:
- hostnames:
  - {{ .Values.global.commonGlobals.endpointFQDN }}
  ip: {{ .Values.global.commonGlobals.PrivateConnect.privateIP }}
{{- else if and .Values.global.commonGlobals.CCPPool.enabled .Values.global.commonGlobals.CCPPool.ccpSvcIP -}}
hostAliases:
- hostnames:
  - {{ .Values.global.commonGlobals.endpointFQDN }}
  ip: {{ .Values.global.commonGlobals.CCPPool.ccpSvcIP }}
{{- end -}}
{{- end -}}
