{{/*
helm/psa-namespace/templates/_helpers.tpl
Helpers pour le chart psa-namespace
*/}}

{{/*
Valider que le niveau PSA est valide
*/}}
{{- define "psa-namespace.validateLevel" -}}
{{- $validLevels := list "privileged" "baseline" "restricted" -}}
{{- if not (has . $validLevels) -}}
  {{- fail (printf "Niveau PSA invalide: '%s'. Valeurs acceptées: privileged, baseline, restricted" .) -}}
{{- end -}}
{{- end -}}

{{/*
Labels communs
*/}}
{{- define "psa-namespace.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/name: {{ .Values.namespaceName }}
{{- end -}}
