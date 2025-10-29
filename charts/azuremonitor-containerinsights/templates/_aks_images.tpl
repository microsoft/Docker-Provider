{{- define "get.imagetag" -}}
{{- if eq .component "kube-addon-manager" -}}
  {{- if semverCompare "<1.7.0" .version -}}v6.5
  {{- else if semverCompare "<1.10.0" .version -}}v8.6
  {{- else if semverCompare "<1.13.0" .version -}}v8.9.1
  {{- else -}}v9.0.2_v0.0.5.9
  {{- end -}}
{{- else if eq .component "kube-apiserver" -}}
  {{- if semverCompare "=1.17.3" .version -}}v1.17.3-hotfix.20200601
  {{- else if semverCompare "=1.17.7" .version -}}v1.17.7-hotfix.20200624
  {{- else if semverCompare "=1.17.9" .version -}}v1.17.9-hotfix.20200714
  {{- else if semverCompare "=1.17.11" .version -}}v1.17.11-hotfix.20200901
  {{- else if semverCompare "=1.17.13" .version -}}v1.17.13-hotfix.20210310.1
  {{- else if semverCompare "=1.17.16" .version -}}v1.17.16-hotfix.20210310.1
  {{- else if semverCompare "=1.18.4" .version -}}v1.18.4-hotfix.20200624
  {{- else if semverCompare "=1.18.6" .version -}}v1.18.6-hotfix.20200723
  {{- else if semverCompare "=1.18.8" .version -}}v1.18.8-hotfix.20200924
  {{- else if semverCompare "=1.18.10" .version -}}v1.18.10-hotfix.20210310.1
  {{- else if semverCompare "=1.18.14" .version -}}v1.18.14-hotfix.20210322.1
  {{- else if semverCompare "=1.18.17" .version -}}v1.18.17-hotfix.20210525.3
  {{- else if semverCompare "=1.18.19" .version -}}v1.18.19-hotfix.20210522.3
  {{- else if semverCompare "=1.19.1" .version -}}v1.19.1-hotfix.20200923
  {{- else if semverCompare "=1.19.6" .version -}}v1.19.6-hotfix.20210310
  {{- else if semverCompare "=1.19.7" .version -}}v1.19.7-hotfix.20210310
  {{- else if semverCompare "=1.19.9" .version -}}v1.19.9-hotfix.20210526
  {{- else if semverCompare "=1.19.11" .version -}}v1.19.11-hotfix.20211101
  {{- else if semverCompare "=1.19.13" .version -}}v1.19.13-hotfix.20211101
  {{- else if semverCompare "=1.20.2" .version -}}v1.20.2-hotfix.20210310
  {{- else if semverCompare "=1.20.5" .version -}}v1.20.5-hotfix.20210603
  {{- else if semverCompare "=1.20.7" .version -}}v1.20.7-hotfix.20211115
  {{- else if semverCompare "=1.20.9" .version -}}v1.20.9-hotfix.20211115
  {{- else if semverCompare "=1.20.13" .version -}}v1.20.13-hotfix.20220210
  {{- else if semverCompare "=1.20.15" .version -}}v1.20.15-hotfix.20220201
  {{- else if semverCompare "=1.21.1" .version -}}v1.21.1-hotfix.20211115
  {{- else if semverCompare "=1.21.2" .version -}}v1.21.2-hotfix.20211115
  {{- else if semverCompare "=1.21.7" .version -}}v1.21.7-hotfix.20220601
  {{- else if semverCompare "=1.21.9" .version -}}v1.21.9-hotfix.20220601
  {{- else if semverCompare "=1.21.14" .version -}}v1.21.14-hotfix.20220620
  {{- else if semverCompare "=1.22.1" .version -}}v1.22.1-hotfix.20211115
  {{- else if semverCompare "=1.22.2" .version -}}v1.22.2-hotfix.20211115
  {{- else if semverCompare "=1.22.4" .version -}}v1.22.4-hotfix.20220615
  {{- else if semverCompare "=1.22.6" .version -}}v1.22.6-hotfix.20220916
  {{- else if semverCompare "=1.22.11" .version -}}v1.22.11-hotfix.20221109
  {{- else if semverCompare "=1.22.15" .version -}}v1.22.15-hotfix.20221109
  {{- else if semverCompare "=1.23.3" .version -}}v1.23.3-hotfix.20220615
  {{- else if semverCompare "=1.23.5" .version -}}v1.23.5-hotfix.20220916
  {{- else if semverCompare "=1.23.8" .version -}}v1.23.8-hotfix.20221109
  {{- else if semverCompare "=1.23.12" .version -}}v1.23.12-hotfix.20230208
  {{- else if semverCompare "=1.23.15" .version -}}v1.23.15-hotfix.20230208
  {{- else if semverCompare "=1.24.0" .version -}}v1.24.0-hotfix.20220916
  {{- else if semverCompare "=1.24.3" .version -}}v1.24.3-hotfix.20221216
  {{- else if semverCompare "=1.24.6" .version -}}v1.24.6-hotfix.20230208
  {{- else if semverCompare "=1.24.9" .version -}}v1.24.9-hotfix.20230612
  {{- else if semverCompare "=1.24.10" .version -}}v1.24.10-hotfix.20230612
  {{- else if semverCompare "=1.25.2" .version -}}v1.25.2-hotfix.20221216
  {{- else if semverCompare "=1.25.4" .version -}}v1.25.4-hotfix.20230208
  {{- else if semverCompare "=1.25.5" .version -}}v1.25.5-hotfix.20230612
  {{- else if semverCompare "=1.25.6" .version -}}v1.25.6-hotfix.20231009
  {{- else if semverCompare "=1.25.11" .version -}}v1.25.11-hotfix.20231102
  {{- else if semverCompare "=1.25.15" .version -}}v1.25.15-hotfix.20231103
  {{- else if semverCompare "=1.26.0" .version -}}v1.26.0-hotfix.20230612
  {{- else if semverCompare "=1.26.3" .version -}}v1.26.3-hotfix.20231009
  {{- else if semverCompare "=1.26.6" .version -}}v1.26.6-hotfix.20231102
  {{- else if semverCompare "=1.26.10" .version -}}v1.26.10-hotfix.20231103
  {{- else if semverCompare "=1.26.12" .version -}}v1.26.12
  {{- else if semverCompare "=1.27.1" .version -}}v1.27.1-hotfix.20231009
  {{- else if semverCompare "=1.27.3" .version -}}v1.27.3-hotfix.20231102
  {{- else if semverCompare "=1.27.7" .version -}}v1.27.7-hotfix.20240411
  {{- else if semverCompare "=1.27.9" .version -}}v1.27.9-hotfix.20240411
  {{- else if semverCompare "=1.27.13" .version -}}v1.27.13
  {{- else if semverCompare "=1.28.0" .version -}}v1.28.0-hotfix.20240712-1
  {{- else if semverCompare "=1.28.3" .version -}}v1.28.3-hotfix.20240712-1
  {{- else if semverCompare "=1.28.5" .version -}}v1.28.5-hotfix.20240712-1
  {{- else if semverCompare "=1.28.9" .version -}}v1.28.9-hotfix.20240712-1
  {{- else if semverCompare "=1.28.10" .version -}}v1.28.10-hotfix.20240712-1
  {{- else if semverCompare "=1.28.11" .version -}}v1.28.11-hotfix.20240712-1
  {{- else if semverCompare "=1.29.0" .version -}}v1.29.0-hotfix.20240712
  {{- else if semverCompare "=1.29.2" .version -}}v1.29.2-hotfix.20240712
  {{- else if semverCompare "=1.29.4" .version -}}v1.29.4-hotfix.20240712
  {{- else if semverCompare "=1.29.14" .version -}}v1.29.14-hotfix.20250703
  {{- else if semverCompare "=1.29.15" .version -}}v1.29.15-hotfix.20250703
  {{- else if semverCompare "=1.30.0" .version -}}v1.30.0-hotfix.20240712
  {{- else if semverCompare "=1.30.2" .version -}}v1.30.2-hotfix.20240712
  {{- else if and (semverCompare ">=1.30.11" .version) (semverCompare "<=1.30.14" .version) -}}v{{.version}}-hotfix.20250703
  {{- else if and (semverCompare ">=1.31.0" .version) (semverCompare "<=1.31.11" .version) -}}v{{.version}}-hotfix.20250703
  {{- else if and (semverCompare ">=1.32.0" .version) (semverCompare "<=1.32.7" .version) -}}v{{.version}}-hotfix.20250703
  {{- else if and (semverCompare ">=1.33.0" .version) (semverCompare "<=1.33.3" .version) -}}v{{.version}}-hotfix.20250703
  {{- else if semverCompare ">=1.34.0" .version -}}v{{ .version }}-1
  {{- else if and (semverCompare ">=1.28.100" .version) (semverCompare "<=1.28.101" .version) -}}v{{.version}}-akslts-hotfix.20250703
  {{- else if and (semverCompare ">=1.27.0" .version) (ge ((semver .version).Patch) 100) -}}v{{.version}}-akslts
  {{- else -}}v{{ .version }}
  {{- end -}}
{{- else if eq .component "kube-scheduler" -}}
  {{- if semverCompare "=1.17.3" .version -}}v1.17.3-hotfix.20200601
  {{- else if semverCompare "=1.17.7" .version -}}v1.17.7-hotfix.20200624
  {{- else if semverCompare "=1.17.9" .version -}}v1.17.9-hotfix.20200714
  {{- else if semverCompare "=1.17.11" .version -}}v1.17.11-hotfix.20200901
  {{- else if semverCompare "=1.17.13" .version -}}v1.17.13-hotfix.20210310.1
  {{- else if semverCompare "=1.17.16" .version -}}v1.17.16-hotfix.20210310.1
  {{- else if semverCompare "=1.18.4" .version -}}v1.18.4-hotfix.20200624
  {{- else if semverCompare "=1.18.6" .version -}}v1.18.6-hotfix.20200723
  {{- else if semverCompare "=1.18.8" .version -}}v1.18.8-hotfix.20200924
  {{- else if semverCompare "=1.18.10" .version -}}v1.18.10-hotfix.20210310.1
  {{- else if semverCompare "=1.18.14" .version -}}v1.18.14-hotfix.20210322.1
  {{- else if semverCompare "=1.18.17" .version -}}v1.18.17-hotfix.20210525.3
  {{- else if semverCompare "=1.18.19" .version -}}v1.18.19-hotfix.20210522.3
  {{- else if semverCompare "=1.19.1" .version -}}v1.19.1-hotfix.20200923
  {{- else if semverCompare "=1.19.6" .version -}}v1.19.6-hotfix.20210310
  {{- else if semverCompare "=1.19.7" .version -}}v1.19.7-hotfix.20210310
  {{- else if semverCompare "=1.19.9" .version -}}v1.19.9-hotfix.20210526
  {{- else if semverCompare "=1.19.11" .version -}}v1.19.11-hotfix.20211101
  {{- else if semverCompare "=1.19.13" .version -}}v1.19.13-hotfix.20211101
  {{- else if semverCompare "=1.20.2" .version -}}v1.20.2-hotfix.20210310
  {{- else if semverCompare "=1.20.5" .version -}}v1.20.5-hotfix.20210603
  {{- else if semverCompare "=1.20.7" .version -}}v1.20.7-hotfix.20211115
  {{- else if semverCompare "=1.20.9" .version -}}v1.20.9-hotfix.20211115
  {{- else if semverCompare "=1.20.13" .version -}}v1.20.13-hotfix.20220210
  {{- else if semverCompare "=1.20.15" .version -}}v1.20.15-hotfix.20220201
  {{- else if semverCompare "=1.21.1" .version -}}v1.21.1-hotfix.20211115
  {{- else if semverCompare "=1.21.2" .version -}}v1.21.2-hotfix.20211115
  {{- else if semverCompare "=1.21.7" .version -}}v1.21.7-hotfix.20220601
  {{- else if semverCompare "=1.21.9" .version -}}v1.21.9-hotfix.20220601
  {{- else if semverCompare "=1.21.14" .version -}}v1.21.14-hotfix.20220620
  {{- else if semverCompare "=1.22.1" .version -}}v1.22.1-hotfix.20211115
  {{- else if semverCompare "=1.22.2" .version -}}v1.22.2-hotfix.20211115
  {{- else if semverCompare "=1.22.4" .version -}}v1.22.4-hotfix.20220615
  {{- else if semverCompare "=1.22.6" .version -}}v1.22.6-hotfix.20220916
  {{- else if semverCompare "=1.22.11" .version -}}v1.22.11-hotfix.20221109
  {{- else if semverCompare "=1.22.15" .version -}}v1.22.15-hotfix.20221109
  {{- else if semverCompare "=1.23.3" .version -}}v1.23.3-hotfix.20220615
  {{- else if semverCompare "=1.23.5" .version -}}v1.23.5-hotfix.20220916
  {{- else if semverCompare "=1.23.8" .version -}}v1.23.8-hotfix.20221109
  {{- else if semverCompare "=1.23.12" .version -}}v1.23.12-hotfix.20230208
  {{- else if semverCompare "=1.23.15" .version -}}v1.23.15-hotfix.20230208
  {{- else if semverCompare "=1.24.0" .version -}}v1.24.0-hotfix.20220916
  {{- else if semverCompare "=1.24.3" .version -}}v1.24.3-hotfix.20221216
  {{- else if semverCompare "=1.24.6" .version -}}v1.24.6-hotfix.20230208
  {{- else if semverCompare "=1.24.9" .version -}}v1.24.9-hotfix.20230612
  {{- else if semverCompare "=1.24.10" .version -}}v1.24.10-hotfix.20230612
  {{- else if semverCompare "=1.25.2" .version -}}v1.25.2-hotfix.20221216
  {{- else if semverCompare "=1.25.4" .version -}}v1.25.4-hotfix.20230208
  {{- else if semverCompare "=1.25.5" .version -}}v1.25.5-hotfix.20230612
  {{- else if semverCompare "=1.25.6" .version -}}v1.25.6-hotfix.20230728
  {{- else if semverCompare "=1.25.11" .version -}}v1.25.11-hotfix.20231102
  {{- else if semverCompare "=1.25.15" .version -}}v1.25.15-hotfix.20231103
  {{- else if semverCompare "=1.26.0" .version -}}v1.26.0-hotfix.20230612
  {{- else if semverCompare "=1.26.3" .version -}}v1.26.3-hotfix.20230728
  {{- else if semverCompare "=1.26.6" .version -}}v1.26.6-hotfix.20231102
  {{- else if semverCompare "=1.26.10" .version -}}v1.26.10-hotfix.20231103
  {{- else if semverCompare "=1.26.12" .version -}}v1.26.12
  {{- else if semverCompare "=1.27.1" .version -}}v1.27.1-hotfix.20230728
  {{- else if semverCompare "=1.27.3" .version -}}v1.27.3-hotfix.20231102
  {{- else if semverCompare "=1.27.7" .version -}}v1.27.7-hotfix.20240411
  {{- else if semverCompare "=1.27.9" .version -}}v1.27.9-hotfix.20240411
  {{- else if semverCompare "=1.27.14" .version -}}v1.27.15
  {{- else if semverCompare "=1.28.0" .version -}}v1.28.0-hotfix.20240712-1
  {{- else if semverCompare "=1.28.3" .version -}}v1.28.3-hotfix.20240712-1
  {{- else if semverCompare "=1.28.5" .version -}}v1.28.5-hotfix.20240712-1
  {{- else if semverCompare "=1.28.10" .version -}}v1.28.11-hotfix.20240712-1
  {{- else if semverCompare "=1.28.11" .version -}}v1.28.11-hotfix.20240712-1
  {{- else if semverCompare "=1.29.0" .version -}}v1.29.0-hotfix.20240712
  {{- else if semverCompare "=1.29.2" .version -}}v1.29.2-hotfix.20240712
  {{- else if semverCompare "=1.29.5" .version -}}v1.29.6-hotfix.20240712
  {{- else if semverCompare "=1.29.6" .version -}}v1.29.6-hotfix.20240712
  {{- else if semverCompare "=1.30.0" .version -}}v1.30.0-hotfix.20240712
  {{- else if semverCompare "=1.30.2" .version -}}v1.30.2-hotfix.20240712
  {{- else if and (semverCompare ">=1.27.0" .version) (ge ((semver .version).Patch | int) 100) -}}v{{.version}}-akslts
  {{- else if semverCompare ">=1.34.0" .version -}}v{{ .version }}-1
  {{- else -}}v{{ .version }}
  {{- end -}}
{{- else if eq .component "kube-controller-manager" -}}
  {{- if semverCompare "=1.17.3" .version -}}v1.17.3-hotfix.20200601
  {{- else if semverCompare "=1.17.7" .version -}}v1.17.7-hotfix.20200917
  {{- else if semverCompare "=1.17.9" .version -}}v1.17.9-hotfix.20200917
  {{- else if semverCompare "=1.17.11" .version -}}v1.17.11-hotfix.20200901
  {{- else if semverCompare "=1.17.13" .version -}}v1.17.13-hotfix.20210310.1
  {{- else if semverCompare "=1.17.16" .version -}}v1.17.16-hotfix.20210310.1
  {{- else if semverCompare "=1.18.4" .version -}}v1.18.4-hotfix.20200624
  {{- else if semverCompare "=1.18.6" .version -}}v1.18.6-hotfix.20200917
  {{- else if semverCompare "=1.18.8" .version -}}v1.18.8-hotfix.20200924
  {{- else if semverCompare "=1.18.10" .version -}}v1.18.10-hotfix.20210310.1
  {{- else if semverCompare "=1.18.14" .version -}}v1.18.14-hotfix.20210525
  {{- else if semverCompare "=1.18.17" .version -}}v1.18.17-hotfix.20210525.3
  {{- else if semverCompare "=1.18.19" .version -}}v1.18.19-hotfix.20210522.3
  {{- else if semverCompare "=1.19.1" .version -}}v1.19.1-hotfix.20200923
  {{- else if semverCompare "=1.19.6" .version -}}v1.19.6-hotfix.20210310
  {{- else if semverCompare "=1.19.7" .version -}}v1.19.7-hotfix.20210525
  {{- else if semverCompare "=1.19.9" .version -}}v1.19.9-hotfix.20210526
  {{- else if semverCompare "=1.19.11" .version -}}v1.19.11-hotfix.20211101
  {{- else if semverCompare "=1.19.13" .version -}}v1.19.13-hotfix.20211101
  {{- else if semverCompare "=1.20.2" .version -}}v1.20.2-hotfix.20210525
  {{- else if semverCompare "=1.20.5" .version -}}v1.20.5-hotfix.20210603
  {{- else if semverCompare "=1.20.7" .version -}}v1.20.7-hotfix.20211115
  {{- else if semverCompare "=1.20.9" .version -}}v1.20.9-hotfix.20220126
  {{- else if semverCompare "=1.20.13" .version -}}v1.20.13-hotfix.20220210
  {{- else if semverCompare "=1.20.15" .version -}}v1.20.15-hotfix.20220201
  {{- else if semverCompare "=1.21.1" .version -}}v1.21.1-hotfix.20211115
  {{- else if semverCompare "=1.21.2" .version -}}v1.21.2-hotfix.20220126
  {{- else if semverCompare "=1.21.7" .version -}}v1.21.7-hotfix.20220601
  {{- else if semverCompare "=1.21.9" .version -}}v1.21.9-hotfix.20220601
  {{- else if semverCompare "=1.21.14" .version -}}v1.21.14-hotfix.20220620
  {{- else if semverCompare "=1.22.1" .version -}}v1.22.1-hotfix.20211115
  {{- else if semverCompare "=1.22.2" .version -}}v1.22.2-hotfix.20211115
  {{- else if semverCompare "=1.22.4" .version -}}v1.22.4-hotfix.20220615
  {{- else if semverCompare "=1.22.6" .version -}}v1.22.6-hotfix.20220916
  {{- else if semverCompare "=1.22.11" .version -}}v1.22.11-hotfix.20221109
  {{- else if semverCompare "=1.22.15" .version -}}v1.22.15-hotfix.20221109
  {{- else if semverCompare "=1.23.3" .version -}}v1.23.3-hotfix.20220615
  {{- else if semverCompare "=1.23.5" .version -}}v1.23.5-hotfix.20220916
  {{- else if semverCompare "=1.23.8" .version -}}v1.23.8-hotfix.20221109
  {{- else if semverCompare "=1.23.12" .version -}}v1.23.12-hotfix.20230208
  {{- else if semverCompare "=1.23.15" .version -}}v1.23.15-hotfix.20230208
  {{- else if semverCompare "=1.24.0" .version -}}v1.24.0-hotfix.20220916
  {{- else if semverCompare "=1.24.3" .version -}}v1.24.3-hotfix.20221216
  {{- else if semverCompare "=1.24.6" .version -}}v1.24.6-hotfix.20230208
  {{- else if semverCompare "=1.24.9" .version -}}v1.24.9-hotfix.20230612
  {{- else if semverCompare "=1.24.10" .version -}}v1.24.10-hotfix.20230612
  {{- else if semverCompare "=1.25.2" .version -}}v1.25.2-hotfix.20221216
  {{- else if semverCompare "=1.25.4" .version -}}v1.25.4-hotfix.20230208
  {{- else if semverCompare "=1.25.5" .version -}}v1.25.5-hotfix.20230612
  {{- else if semverCompare "=1.25.6" .version -}}v1.25.6-hotfix.20230728
  {{- else if semverCompare "=1.25.11" .version -}}v1.25.11-hotfix.20231102
  {{- else if semverCompare "=1.25.15" .version -}}v1.25.15-hotfix.20231103
  {{- else if semverCompare "=1.26.0" .version -}}v1.26.0-hotfix.20230612
  {{- else if semverCompare "=1.26.3" .version -}}v1.26.3-hotfix.20230728
  {{- else if semverCompare "=1.26.6" .version -}}v1.26.6-hotfix.20231102
  {{- else if semverCompare "=1.26.10" .version -}}v1.26.10-hotfix.20231103
  {{- else if semverCompare "=1.26.12" .version -}}v1.26.12
  {{- else if semverCompare "=1.27.1" .version -}}v1.27.1-hotfix.20230728
  {{- else if semverCompare "=1.27.3" .version -}}v1.27.3-hotfix.20231102
  {{- else if semverCompare "=1.27.7" .version -}}v1.27.7-hotfix.20240411
  {{- else if semverCompare "=1.27.9" .version -}}v1.27.9-hotfix.20240411
  {{- else if semverCompare "=1.27.13" .version -}}v1.27.13
  {{- else if semverCompare "=1.28.0" .version -}}v1.28.0-hotfix.20240712-1
  {{- else if semverCompare "=1.28.3" .version -}}v1.28.3-hotfix.20240712-1
  {{- else if semverCompare "=1.28.5" .version -}}v1.28.5-hotfix.20240712-1
  {{- else if semverCompare "=1.28.9" .version -}}v1.28.9-hotfix.20240712-1
  {{- else if semverCompare "=1.28.10" .version -}}v1.28.10-hotfix.20240712-1
  {{- else if semverCompare "=1.28.11" .version -}}v1.28.11-hotfix.20240712-1
  {{- else if semverCompare "=1.29.0" .version -}}v1.29.0-hotfix.20240712
  {{- else if semverCompare "=1.29.2" .version -}}v1.29.2-hotfix.20240712
  {{- else if semverCompare "=1.29.4" .version -}}v1.29.4-hotfix.20240712
  {{- else if semverCompare "=1.30.0" .version -}}v1.30.0-hotfix.20240712
  {{- else if semverCompare "=1.30.2" .version -}}v1.30.2-hotfix.20240712
  {{- else if and (semverCompare ">=1.27.0" .version) (ge ((semver .version).Patch) 100) -}}v{{.version}}-akslts
  {{- else if semverCompare ">=1.34.0" .version -}}v{{ .version }}-1
  {{- else -}}v{{ .version }}
  {{- end -}}
{{- else if eq .component "hyperkube" -}}
  {{- if semverCompare "=1.12.8" .version -}}v1.12.8_v0.0.5
  {{- else if semverCompare "=1.13.10" .version -}}v1.13.10_v0.0.5
  {{- else if semverCompare "=1.13.11" .version -}}v1.13.11_v0.0.5
	{{- else if semverCompare "=1.13.12" .version -}}v1.13.12_v0.0.5
	{{- else if semverCompare "=1.14.6" .version -}}v1.14.6_v0.0.5
	{{- else if semverCompare "=1.14.7" .version -}}v1.14.7-hotfix.20200408.1
	{{- else if semverCompare "=1.14.8" .version -}}v1.14.8-hotfix.20200529.1
	{{- else if semverCompare "=1.15.3" .version -}}v1.15.3_v0.0.5
	{{- else if semverCompare "=1.15.4" .version -}}v1.15.4_v0.0.5
	{{- else if semverCompare "=1.15.5" .version -}}v1.15.5_v0.0.5
	{{- else if semverCompare "=1.15.7" .version -}}v1.15.7-hotfix.20200408.1
	{{- else if semverCompare "=1.15.10" .version -}}v1.15.10-hotfix.20200408.1
	{{- else if semverCompare "=1.15.11" .version -}}v1.15.11-hotfix.20201203
	{{- else if semverCompare "=1.15.12" .version -}}v1.15.12-hotfix.20200824.2
	{{- else if semverCompare "=1.16.0" .version -}}v1.16.0_v0.0.5
	{{- else if semverCompare "=1.16.7" .version -}}v1.16.7-hotfix.20200601.3
	{{- else if semverCompare "=1.16.8" .version -}}v1.16.8.2
	{{- else if semverCompare "=1.16.9" .version -}}v1.16.9-hotfix.20200529.7
	{{- else if semverCompare "=1.16.10" .version -}}v1.16.10-hotfix.20200917.3
	{{- else if semverCompare "=1.16.13" .version -}}v1.16.13-hotfix.20210118.2
	{{- else if semverCompare "=1.16.14" .version -}}v1.16.14-hotfix.20200901.4
	{{- else if semverCompare "=1.16.15" .version -}}v1.16.15-hotfix.20210118.4
	{{- else if semverCompare "=1.17.3" .version -}}v1.17.3-hotfix.20200601.3
	{{- else if semverCompare "=1.17.4" .version -}}v1.17.4.2
	{{- else if semverCompare "=1.17.5" .version -}}v1.17.5.2
	{{- else if semverCompare "=1.17.7" .version -}}v1.17.7-hotfix.20200917.3
	{{- else if semverCompare "=1.17.9" .version -}}v1.17.9-hotfix.20200917.3
	{{- else if semverCompare "=1.17.11" .version -}}v1.17.11-hotfix.20200901.4
	{{- else if semverCompare "=1.17.13" .version -}}v1.17.13-hotfix.20210310.2
	{{- else if semverCompare "=1.17.16" .version -}}v1.17.16-hotfix.20210310.2
	{{- else if semverCompare "=1.18.1" .version -}}v1.18.1.6
	{{- else if semverCompare "=1.18.2" .version -}}v1.18.2-hotfix.20200626.7
	{{- else if semverCompare "=1.18.4" .version -}}v1.18.4-hotfix.20200626.7
	{{- else if semverCompare "=1.18.6" .version -}}v1.18.6-hotfix.20200917.5
	{{- else if semverCompare "=1.18.8" .version -}}v1.18.8-hotfix.20201112.4
	{{- else if semverCompare "=1.18.10" .version -}}v1.18.10-hotfix.20210310.4
	{{- else if semverCompare "=1.18.14" .version -}}v1.18.14-hotfix.20210525.2
	{{- else if semverCompare "=1.18.17" .version -}}v1.18.17-hotfix.20210525.2
	{{- else if semverCompare "=1.18.19" .version -}}v1.18.19-hotfix.20210522.2
  {{- else -}}v{{ .version }}
  {{- end -}}
{{- else if eq .component "kubectl" -}}
  {{- if semverCompare "=1.17.3" .version -}}v1.17.3-hotfix.20200601
  {{- else if semverCompare "=1.17.7" .version -}}v1.17.7-hotfix.20200624
  {{- else if semverCompare "=1.17.9" .version -}}v1.17.9-hotfix.20200714
  {{- else if semverCompare "=1.17.11" .version -}}v1.17.11-hotfix.20200901
  {{- else if semverCompare "=1.17.13" .version -}}v1.17.13-hotfix.20210310.1
  {{- else if semverCompare "=1.17.16" .version -}}v1.17.16-hotfix.20210310.1
  {{- else if semverCompare "=1.18.4" .version -}}v1.18.4-hotfix.20200624
  {{- else if semverCompare "=1.18.6" .version -}}v1.18.6-hotfix.20200723
  {{- else if semverCompare "=1.18.8" .version -}}v1.18.8-hotfix.20200924
  {{- else if semverCompare "=1.18.10" .version -}}v1.18.10-hotfix.20210310.1
  {{- else if semverCompare "=1.18.14" .version -}}v1.18.14-hotfix.20210322
  {{- else if semverCompare "=1.18.17" .version -}}v1.18.17-hotfix.20210525.2
  {{- else if semverCompare "=1.18.19" .version -}}v1.18.19-hotfix.20210522.2
  {{- else if semverCompare "=1.19.1" .version -}}v1.19.1-hotfix.20200923
  {{- else if semverCompare "=1.19.6" .version -}}v1.19.6-hotfix.20210310.1
  {{- else if semverCompare "=1.19.7" .version -}}v1.19.7-hotfix.20210310.1
  {{- else if semverCompare "=1.19.9" .version -}}v1.19.9-hotfix.20210526.2
  {{- else if semverCompare "=1.19.11" .version -}}v1.19.11-hotfix.20211101.1
  {{- else if semverCompare "=1.19.13" .version -}}v1.19.13-hotfix.20211101.1
  {{- else if semverCompare "=1.20.2" .version -}}v1.20.2-hotfix.20210310.1
  {{- else if semverCompare "=1.20.5" .version -}}v1.20.5-hotfix.20210603.2
  {{- else if semverCompare "=1.20.7" .version -}}v1.20.7-hotfix.20211115
  {{- else if semverCompare "=1.20.9" .version -}}v1.20.9-hotfix.20211115.1
  {{- else if semverCompare "=1.20.13" .version -}}v1.20.13-hotfix.20220210.2
  {{- else if semverCompare "=1.20.15" .version -}}v1.20.15-hotfix.20220201.2
  {{- else if semverCompare "=1.21.1" .version -}}v1.21.1-hotfix.20211115
  {{- else if semverCompare "=1.21.2" .version -}}v1.21.2-hotfix.20211115.1
  {{- else if semverCompare "=1.21.7" .version -}}v1.21.7-hotfix.20220601
  {{- else if semverCompare "=1.21.9" .version -}}v1.21.9-hotfix.20220601.1
  {{- else if semverCompare "=1.21.14" .version -}}v1.21.14-hotfix.20220620.1
  {{- else if semverCompare "=1.22.1" .version -}}v1.22.1-hotfix.20211115.1
  {{- else if semverCompare "=1.22.2" .version -}}v1.22.2-hotfix.20211115.1
  {{- else if semverCompare "=1.22.4" .version -}}v1.22.4-hotfix.20220615
  {{- else if semverCompare "=1.22.6" .version -}}v1.22.6-hotfix.20220916
  {{- else if semverCompare "=1.22.11" .version -}}v1.22.11-hotfix.20221109.1
  {{- else if semverCompare "=1.22.15" .version -}}v1.22.15-hotfix.20221109.1
  {{- else if semverCompare "=1.23.3" .version -}}v1.23.3-hotfix.20220615
  {{- else if semverCompare "=1.23.5" .version -}}v1.23.5-hotfix.20220916
  {{- else if semverCompare "=1.23.8" .version -}}v1.23.8-hotfix.20221109.2
  {{- else if semverCompare "=1.23.12" .version -}}v1.23.12-hotfix.20230208.1
  {{- else if semverCompare "=1.23.15" .version -}}v1.23.15-hotfix.20230208.1
  {{- else if semverCompare "=1.24.0" .version -}}v1.24.0-hotfix.20220916
  {{- else if semverCompare "=1.24.3" .version -}}v1.24.3-hotfix.20221216
  {{- else if semverCompare "=1.24.6" .version -}}v1.24.6-hotfix.20230208.1
  {{- else if semverCompare "=1.24.9" .version -}}v1.24.9-hotfix.20230612
  {{- else if semverCompare "=1.24.10" .version -}}v1.24.10-hotfix.20230612
  {{- else if semverCompare "=1.25.2" .version -}}v1.25.2-hotfix.20221216.1
  {{- else if semverCompare "=1.25.4" .version -}}v1.25.4-hotfix.20230208.1
  {{- else if semverCompare "=1.25.5" .version -}}v1.25.5-hotfix.20230612
  {{- else if semverCompare "=1.25.6" .version -}}v1.25.6-hotfix.20230728
  {{- else if semverCompare "=1.25.11" .version -}}v1.25.11-hotfix.20231102
  {{- else if semverCompare "=1.25.15" .version -}}v1.25.15-hotfix.20231103
  {{- else if semverCompare "=1.26.0" .version -}}v1.26.0-hotfix.20230612
  {{- else if semverCompare "=1.26.3" .version -}}v1.26.3-hotfix.20230728
  {{- else if semverCompare "=1.26.6" .version -}}v1.26.6-hotfix.20231102
  {{- else if semverCompare "=1.26.10" .version -}}v1.26.10-hotfix.20231103-1
  {{- else if semverCompare "=1.26.12" .version -}}v1.26.12-1
  {{- else if semverCompare "=1.27.1" .version -}}v1.27.1-hotfix.20230728
  {{- else if semverCompare "=1.27.3" .version -}}v1.27.3-hotfix.20240125
  {{- else if semverCompare "=1.27.7" .version -}}v1.27.7-hotfix.20240712-4
  {{- else if semverCompare "=1.27.9" .version -}}v1.27.9-hotfix.20240712-4
  {{- else if semverCompare "=1.27.13" .version -}}v1.27.13-2
  {{- else if semverCompare "=1.28.0" .version -}}v1.28.0-hotfix.20240712-4
  {{- else if semverCompare "=1.28.3" .version -}}v1.28.3-hotfix.20240712-4
  {{- else if semverCompare "=1.28.5" .version -}}v1.28.5-hotfix.20240712-4
  {{- else if and (semverCompare ">=1.27.0" .version) (ge ((semver .version).Patch) 100) -}}v{{.version}}-akslts
  {{- else if and (semverCompare ">=1.29.0" .version)  (semverCompare "<1.30.0" .version) -}}v1.29.13
  {{- else if semverCompare "=1.30.0" .version -}}v1.30.0-1
  {{- else if semverCompare "=1.30.1" .version -}}v1.30.1-1
  {{- else if semverCompare "=1.30.2" .version -}}v1.30.2-hotfix.20240613
  {{- else if semverCompare ">=1.34.0" .version -}}v{{ .version }}-1
  {{- else -}}v{{ .version }}
  {{- end -}}
{{- else if eq .component "kube-proxy" -}}
    {{- if semverCompare "=1.17.3" .version -}}v1.17.3-hotfix.20200601.3
    {{- else if semverCompare "=1.17.7" .version -}}v1.17.7-hotfix.20200917.3
    {{- else if semverCompare "=1.17.9" .version -}}v1.17.9-hotfix.20200917.3
    {{- else if semverCompare "=1.17.11" .version -}}v1.17.11-hotfix.20200901.2
    {{- else if semverCompare "=1.17.13" .version -}}v1.17.13-hotfix.20210310.2
    {{- else if semverCompare "=1.17.16" .version -}}v1.17.16-hotfix.20210310.2
    {{- else if semverCompare "=1.18.2" .version -}}v1.18.2-hotfix.20200626.4
    {{- else if semverCompare "=1.18.4" .version -}}v1.18.4-hotfix.20200626.5
    {{- else if semverCompare "=1.18.6" .version -}}v1.18.6-hotfix.20200917.4
    {{- else if semverCompare "=1.18.8" .version -}}v1.18.8-hotfix.20201112.2
    {{- else if semverCompare "=1.18.10" .version -}}v1.18.10-hotfix.20210310.2
    {{- else if semverCompare "=1.18.14" .version -}}v1.18.14-hotfix.20210525
    {{- else if semverCompare "=1.18.17" .version -}}v1.18.17-hotfix.20210525.3
    {{- else if semverCompare "=1.18.19" .version -}}v1.18.19-hotfix.20210522.3
    {{- else if semverCompare "=1.19.7" .version -}}v1.19.7-hotfix.20210525
    {{- else if semverCompare "=1.19.9" .version -}}v1.19.9-hotfix.20210526.3
    {{- else if semverCompare "=1.19.11" .version -}}v1.19.11-hotfix.20211101.1
    {{- else if semverCompare "=1.19.13" .version -}}v1.19.13-hotfix.20211101.1
    {{- else if semverCompare "=1.20.2" .version -}}v1.20.2-hotfix.20210525
    {{- else if semverCompare "=1.20.5" .version -}}v1.20.5-hotfix.20210603.3
    {{- else if semverCompare "=1.20.7" .version -}}v1.20.7-hotfix.20211021.1
    {{- else if semverCompare "=1.20.9" .version -}}v1.20.9-hotfix.20211115.2
    {{- else if semverCompare "=1.20.13" .version -}}v1.20.13-hotfix.20220210.3
    {{- else if semverCompare "=1.20.15" .version -}}v1.20.15-hotfix.20220201.3
    {{- else if semverCompare "=1.21.1" .version -}}v1.21.1-hotfix.20211022.1
    {{- else if semverCompare "=1.21.2" .version -}}v1.21.2-hotfix.20211115.2
    {{- else if semverCompare "=1.21.7" .version -}}v1.21.7-hotfix.20220601.1
    {{- else if semverCompare "=1.21.9" .version -}}v1.21.9-hotfix.20220601.2
    {{- else if semverCompare "=1.21.14" .version -}}v1.21.14-hotfix.20220620.3
    {{- else if semverCompare "=1.22.1" .version -}}v1.22.1-hotfix.20211115.1
    {{- else if semverCompare "=1.22.2" .version -}}v1.22.2-hotfix.20211115.1
    {{- else if semverCompare "=1.22.4" .version -}}v1.22.4-hotfix.20220615.1
    {{- else if semverCompare "=1.22.6" .version -}}v1.22.6-hotfix.20220728.2
    {{- else if semverCompare "=1.22.11" .version -}}v1.22.11-hotfix.20221109.1
    {{- else if semverCompare "=1.22.15" .version -}}v1.22.15-hotfix.20221109.1
    {{- else if semverCompare "=1.23.3" .version -}}v1.23.3-hotfix.20220615.1
    {{- else if semverCompare "=1.23.5" .version -}}v1.23.5-hotfix.20220728.4
    {{- else if semverCompare "=1.23.8" .version -}}v1.23.8-hotfix.20221109.3
    {{- else if semverCompare "=1.23.12" .version -}}v1.23.12-hotfix.20230208.2
    {{- else if semverCompare "=1.23.15" .version -}}v1.23.15-hotfix.20230208.2
    {{- else if semverCompare "=1.24.0" .version -}}v1.24.0-hotfix.20220615.4
    {{- else if semverCompare "=1.24.3" .version -}}v1.24.3-hotfix.20221216.1
    {{- else if semverCompare "=1.24.6" .version -}}v1.24.6-hotfix.20230208.2
    {{- else if semverCompare "=1.24.9" .version -}}v1.24.9-hotfix.20230612
    {{- else if semverCompare "=1.24.10" .version -}}v1.24.10-hotfix.20230612-1
    {{- else if semverCompare "=1.25.2" .version -}}v1.25.2-hotfix.20221216
    {{- else if semverCompare "=1.25.4" .version -}}v1.25.4-hotfix.20230208
    {{- else if semverCompare "=1.25.5" .version -}}v1.25.5-hotfix.20230612
    {{- else if semverCompare "=1.25.6" .version -}}v1.25.6-hotfix.20231009-3
    {{- else if semverCompare "=1.25.11" .version -}}v1.25.11-hotfix.20231102-1
    {{- else if semverCompare "=1.25.15" .version -}}v1.25.15-hotfix.20231103-1
    {{- else if semverCompare "=1.26.0" .version -}}v1.26.0-hotfix.20230612
    {{- else if semverCompare "=1.26.3" .version -}}v1.26.3-hotfix.20231009-2
    {{- else if semverCompare "=1.26.6" .version -}}v1.26.6-hotfix.20231102
    {{- else if semverCompare "=1.26.10" .version -}}v1.26.10-hotfix.20231103-8
    {{- else if semverCompare "=1.27.1" .version -}}v1.27.1-hotfix.20231009
    {{- else if semverCompare "=1.27.3" .version -}}v1.27.3-hotfix.20240125
    {{- else if semverCompare "=1.27.7" .version -}}v1.27.7-hotfix.20240411
    {{- else if semverCompare "=1.27.9" .version -}}v1.27.9-hotfix.20240411
    {{- else if semverCompare "=1.27.14" .version -}}v1.27.14-1
    {{- else if semverCompare "=1.28.0" .version -}}v1.28.0-hotfix.20240125
    {{- else if semverCompare "=1.28.3" .version -}}v1.28.3-hotfix.20240411
    {{- else if semverCompare "=1.28.5" .version -}}v1.28.5-hotfix.20240411
    {{- else if semverCompare "=1.28.10" .version -}}v1.28.10-1
    {{- else if semverCompare "=1.29.2" .version -}}v1.29.2-hotfix.20240411
    {{- else if semverCompare "=1.29.5" .version -}}v1.29.5-1
    {{- else if semverCompare "=1.30.0" .version -}}v1.30.0-hotfix.20240712-3
    {{- else if semverCompare "=1.30.1" .version -}}v1.30.1-hotfix.20240712-3
    {{- else if semverCompare "=1.30.2" .version -}}v1.30.2-hotfix.20240712-3
    {{- else if semverCompare "=1.30.6" .version -}}v1.30.6-1
    {{- else if semverCompare "=1.31.1" .version -}}v1.31.1-2
    {{- else if and (semverCompare ">=1.27.0" .version) (ge ((semver .version).Patch) 100) -}}v{{.version}}-akslts
    {{- else if semverCompare ">=1.34.0" .version -}}v{{ .version }}-1
    {{- else -}}v{{ .version }}
    {{- end -}}
{{- else if eq .component "cloud-provider-controller-manager" -}}
  {{- if semverCompare ">=1.33.0" .version -}}v1.33.2
  {{- else if semverCompare ">=1.32.0" .version -}}v1.32.7
  {{- else if semverCompare ">=1.31.0" .version -}}v1.31.8
  {{- else if semverCompare ">=1.30.0" .version -}}v1.30.14
  {{- else if semverCompare ">=1.29.0" .version -}}v1.29.15
  {{- else if semverCompare ">=1.28.0" .version -}}v1.28.14
  {{- else if semverCompare ">=1.27.0" .version -}}v1.27.21
  {{- else if semverCompare ">=1.26.0" .version -}}v1.26.22
  {{- else if semverCompare ">=1.25.0" .version -}}v1.25.24
  {{- else if semverCompare ">=1.24.0" .version -}}v1.24.22
  {{- else if semverCompare ">=1.23.0" .version -}}v1.23.30
  {{- else if semverCompare ">=1.22.0" .version -}}v1.1.26
  {{- else if semverCompare ">=1.21.0" .version -}}v1.0.23
  {{- else if semverCompare ">=1.20.0" .version -}}v0.7.21
  {{- else if semverCompare ">=1.19.0" .version -}}v0.6.0
  {{- else -}}v0.5.1.4
  {{- end -}}
{{- else if eq .component "appmonitoring-webhook" -}}
1.0.0-beta.8
{{- else if eq .component "tunnel-front" -}}
master.250401.1
{{- else if eq .component "tunnel-end" -}}
master.250401.1
{{- else if eq .component "tunnel-openvpn-front" -}}
master.241001.1
{{- else if eq .component "tunnel-openvpn-end" -}}
master.241001.1
{{- else if eq .component "apiserver-network-proxy-agent" -}}
v0.30.3-5
{{- else if eq .component "aad-pod-identity-nmi" -}}
v1.8.18
{{- else if eq .component "gitops-manager-config-operator" -}}
1.7.0
{{- else if eq .component "gitops-manager-config-agent" -}}
1.7.0
{{- else if eq .component "resourcesync-operator" -}}
1.7.1
{{- else if eq .component "http-application-routing-nginx-ingress-controller" -}}
  {{- if semverCompare ">=1.22.0" .version -}}1.2.1
  {{- else if semverCompare ">=1.21.0" .version -}}0.49.3
  {{- else -}}0.19.0
  {{- end -}}
{{- else if eq .component "http-application-routing-external-dns" -}}
  {{- if semverCompare ">=1.22.0" .version -}}v0.10.2
  {{- else if semverCompare ">=1.21.0" .version -}}v0.8.0
  {{- else -}}v0.6.0-hotfix-20200228
  {{- end -}}
{{- else if eq .component "http-application-routing-defaultbackend" -}}
1.4
{{- else if eq .component "ip-masq-agent" -}}
v2.5.0.12
{{- else if eq .component "azuredisk-csi-v2" -}}
v2.0.0-beta.10
{{- else if eq .component "azdiskschedulerextender-csi" -}}
v2.0.0-beta.10
{{- else if eq .component "csi-node-driver-registrar" -}}
  {{- if semverCompare ">=1.31.0" .version -}}v2.14.0
  {{- else if semverCompare ">=1.29.0" .version -}}v2.13.0
  {{- else if semverCompare ">=1.28.0" .version -}}v2.12.0
  {{- else if semverCompare ">=1.27.0" .version -}}v2.10.1
  {{- else if semverCompare ">=1.24.0" .version -}}v2.8.0
  {{- else if semverCompare ">=1.21.0" .version -}}v2.5.0
  {{- else -}}v2.3.0
  {{- end -}}
{{- else if eq .component "csi-livenessprobe" -}}
  {{- if semverCompare ">=1.31.0" .version -}}v2.16.0
  {{- else if semverCompare ">=1.29.0" .version -}}v2.15.0
  {{- else if semverCompare ">=1.28.0" .version -}}v2.14.0
  {{- else if semverCompare ">=1.27.0" .version -}}v2.12.0
  {{- else if semverCompare ">=1.24.0" .version -}}v2.10.0
  {{- else if semverCompare ">=1.21.0" .version -}}v2.6.0
  {{- else -}}v2.2.0
  {{- end -}}
{{- else if eq .component "azuredisk-csi-linux" -}}
  {{- if semverCompare ">=1.33.0" .version -}}v1.33.4-2
  {{- else if semverCompare ">=1.32.0" .version -}}v1.32.10-2
  {{- else if semverCompare ">=1.31.0" .version -}}v1.31.11
  {{- else if semverCompare ">=1.30.0" .version -}}v1.30.12
  {{- else if semverCompare ">=1.28.0" .version -}}v1.29.14
  {{- else if semverCompare ">=1.27.0" .version -}}v1.28.12
  {{- else if semverCompare ">=1.26.0" .version -}}v1.26.9
  {{- else if semverCompare ">=1.24.0" .version -}}v1.26.8
  {{- else if semverCompare ">=1.21.0" .version -}}v1.26.2.2
  {{- else -}}v1.2.2.5
  {{- end -}}
{{- else if eq .component "azuredisk-csi-windows" -}}
  {{- if semverCompare ">=1.33.0" .version -}}v1.33.4
  {{- else if semverCompare ">=1.32.0" .version -}}v1.32.10
  {{- else if semverCompare ">=1.31.0" .version -}}v1.31.11
  {{- else if semverCompare ">=1.30.0" .version -}}v1.30.12
  {{- else if semverCompare ">=1.28.0" .version -}}v1.29.14
  {{- else if semverCompare ">=1.27.0" .version -}}v1.28.12
  {{- else if semverCompare ">=1.26.0" .version -}}v1.26.9
  {{- else if semverCompare ">=1.24.0" .version -}}v1.26.8
  {{- else if semverCompare ">=1.21.0" .version -}}v1.26.2
  {{- else -}}v1.2.2.5
  {{- end -}}
{{- else if eq .component "azurefile-csi-linux" -}}
  {{- if semverCompare ">=1.33.0" .version -}}v1.33.4-2
  {{- else if semverCompare ">=1.32.0" .version -}}v1.32.5
  {{- else if semverCompare ">=1.31.0" .version -}}v1.31.7
  {{- else if semverCompare ">=1.29.0" .version -}}v1.30.10
  {{- else if semverCompare ">=1.28.0" .version -}}v1.29.12
  {{- else if semverCompare ">=1.27.0" .version -}}v1.28.14
  {{- else if semverCompare ">=1.26.0" .version -}}v1.26.11-2
  {{- else if semverCompare ">=1.24.0" .version -}}v1.24.11
  {{- else if semverCompare ">=1.21.0" .version -}}v1.24.0
  {{- else -}}v1.2.2
  {{- end -}}
{{- else if eq .component "azurefile-csi-windows" -}}
  {{- if semverCompare ">=1.33.0" .version -}}v1.33.4
  {{- else if semverCompare ">=1.32.0" .version -}}v1.32.5
  {{- else if semverCompare ">=1.31.0" .version -}}v1.31.7
  {{- else if semverCompare ">=1.29.0" .version -}}v1.30.10
  {{- else if semverCompare ">=1.28.0" .version -}}v1.29.12
  {{- else if semverCompare ">=1.27.0" .version -}}v1.28.14
  {{- else if semverCompare ">=1.26.0" .version -}}v1.26.11
  {{- else if semverCompare ">=1.24.0" .version -}}v1.24.11
  {{- else if semverCompare ">=1.21.0" .version -}}v1.24.0
  {{- else -}}v1.2.2
  {{- end -}}
{{- else if eq .component "blob-csi" -}}
  {{- if semverCompare ">=1.33.0" .version -}}v1.26.7
  {{- else if semverCompare ">=1.32.0" .version -}}v1.26.6
  {{- else if semverCompare ">=1.31.0" .version -}}v1.25.9
  {{- else if semverCompare ">=1.30.0" .version -}}v1.24.11
  {{- else if semverCompare ">=1.28.0" .version -}}v1.23.11
  {{- else if semverCompare ">=1.27.0" .version -}}v1.22.9
  {{- else if semverCompare ">=1.26.0" .version -}}v1.21.7-2
  {{- else if semverCompare ">=1.24.0" .version -}}v1.19.5-7
  {{- else -}}v1.19.2
  {{- end -}}
{{- else if eq .component "csi-provisioner" -}}
  {{- if semverCompare ">=1.29.0" .version -}}v5.2.0
  {{- else if semverCompare ">=1.28.0" .version -}}v3.6.2
  {{- else if semverCompare ">=1.24.0" .version -}}v3.5.0
  {{- else if semverCompare ">=1.21.0" .version -}}v3.1.0
  {{- else -}}v2.1.1-hotfix.20220128-aks
  {{- end -}}
{{- else if eq .component "csi-attacher" -}}
  {{- if semverCompare ">=1.32.0" .version -}}v4.9.0
  {{- else if semverCompare ">=1.29.0" .version -}}v4.8.1
  {{- else if semverCompare ">=1.28.0" .version -}}v4.4.2
  {{- else if semverCompare ">=1.27.0" .version -}}v4.3.0
  {{- else if semverCompare ">=1.21.0" .version -}}v3.4.0
  {{- else -}}v3.1.0-hotfix.20220128-aks
  {{- end -}}
{{- else if eq .component "csi-resizer" -}}
  {{- if semverCompare ">=1.29.0" .version -}}v1.13.2
  {{- else if semverCompare ">=1.28.0" .version -}}v1.9.3
  {{- else if semverCompare ">=1.27.0" .version -}}v1.8.0
  {{- else if semverCompare ">=1.21.0" .version -}}v1.4.0
  {{- else -}}v1.1.0-hotfix.20220128-aks
  {{- end -}}
{{- else if eq .component "csi-snapshotter" -}}
  {{- if semverCompare ">=1.33.0" .version -}}v8.3.0
  {{- else if semverCompare ">=1.29.0" .version -}}v8.2.0
  {{- else if semverCompare ">=1.27.0" .version -}}v6.2.2
  {{- else if semverCompare ">=1.21.0" .version -}}v5.0.1
  {{- else -}}v3.0.3-hotfix.20220128-aks
  {{- end -}}
{{- else if eq .component "snapshot-controller" -}}
  {{- if semverCompare ">=1.33.0" .version -}}v8.3.0
  {{- else if semverCompare ">=1.29.0" .version -}}v8.2.0
  {{- else if semverCompare ">=1.27.0" .version -}}v6.2.2
  {{- else if semverCompare ">=1.21.0" .version -}}v5.0.1
  {{- else -}}v3.0.3-hotfix.20220128-aks
  {{- end -}}
{{- else if eq .component "azure-cns-image" -}}
v1.4.44.5
{{- else if eq .component "azure-cns-image-windows" -}}
v1.4.44.5
{{- else if eq .component "azure-cni-networkmonitor" -}}
v1.1.8_hotfix
{{- else if eq .component "calico-typha-image" -}}
v3.8.9
{{- else if eq .component "calico-pod2daemon-flexvol-image" -}}
v3.8.9.1
{{- else if eq .component "calico-cni-image" -}}
v3.8.9.3
{{- else if eq .component "calico-node-image" -}}
v3.8.9.5
{{- else if eq .component "ccp-initializer" -}}
master.250807.1
{{- else if eq .component "ccp-auto-thrust" -}}
  {{- if semverCompare ">=1.27.0" .version -}}master.250505.2
  {{- else -}}master.250108.7
  {{- end -}}
{{- else if eq .component "ccp-auto-thrust-csi" -}}
  {{- if semverCompare ">=1.27.0" .version -}}master.250307.1
  {{- else -}}master.250108.7
  {{- end -}}
{{- else if eq .component "admissionsenforcer" -}}
master.250822.2
{{- else if eq .component "msi-adapter" -}}
master.250822.1
{{- else if eq .component "private-connect-router" -}}
master.250811.1
{{- else if eq .component "private-connect-balancer" -}}
master.250731.2
{{- else if eq .component "addon-token-adapter-linux" -}}
master.250902.1
{{- else if eq .component "addon-token-adapter-windows" -}}
master.250902.1
{{- else if eq .component "addon-token-reconciler" -}}
master.250819.2
{{- else if eq .component "aks-kube-addon-manager" -}}
master.250528.2
{{- else if eq .component "kms-plugin" -}}
v0.8.0
{{- else if eq .component "ccp-coredns" -}}
v1.12.0-1
{{- end -}}
{{- end -}}
