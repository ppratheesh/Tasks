{{- define "resource-name" -}}
{{ .Release.Name }}
{{- end }}

{{/*
common labels
*/}}
{{- define "app-labels" -}}
app.kubernetes.io/name: {{ include "resource-name" . }}-app
app.kubernetes.io/instance: {{ include "resource-name" . }}
{{- end }}

