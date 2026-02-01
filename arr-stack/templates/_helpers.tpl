{{/*
Expand the name of the chart.
*/}}
{{- define "arr-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "arr-stack.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "arr-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "arr-stack.labels" -}}
helm.sh/chart: {{ include "arr-stack.chart" . }}
{{ include "arr-stack.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "arr-stack.selectorLabels" -}}
app.kubernetes.io/name: {{ include "arr-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-specific labels
*/}}
{{- define "arr-stack.componentLabels" -}}
{{- $component := . -}}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Full component name
*/}}
{{- define "arr-stack.componentName" -}}
{{- $component := .component -}}
{{- $context := .context -}}
{{- printf "%s-%s" (include "arr-stack.fullname" $context) $component | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the image string for a component
*/}}
{{- define "arr-stack.image" -}}
{{- $image := .image -}}
{{- if $image.digest }}
{{- printf "%s:%s@%s" $image.repository $image.tag $image.digest }}
{{- else }}
{{- printf "%s:%s" $image.repository $image.tag }}
{{- end }}
{{- end }}

{{/*
Get storage path helper
*/}}
{{- define "arr-stack.storagePath" -}}
{{- $type := .type -}}
{{- $subpath := .subpath | default "" -}}
{{- $context := .context -}}
{{- $base := "" -}}
{{- if eq $type "media" }}
{{- $base = $context.Values.storage.media.path }}
{{- else if eq $type "downloads" }}
{{- $base = $context.Values.storage.downloads.path }}
{{- else if eq $type "appdata" }}
{{- $base = $context.Values.storage.appdata.path }}
{{- end }}
{{- if $subpath }}
{{- printf "%s/%s" $base $subpath }}
{{- else }}
{{- $base }}
{{- end }}
{{- end }}
