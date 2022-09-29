{{/*
common labels
*/}}
{{- define "nginx-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernets.io/instance:  {{ .Release.Name }}
{{- end }}


