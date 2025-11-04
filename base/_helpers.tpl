{{/*
Common helper templates shared across all services
*/}}

{{/*
Common resource labels
*/}}
{{- define "base.commonLabels" -}}
app.kubernetes.io/managed-by: ArgoCD
{{- end }}

{{/*
Common annotations
*/}}
{{- define "base.commonAnnotations" -}}
argocd.argoproj.io/sync-wave: "0"
{{- end }}









