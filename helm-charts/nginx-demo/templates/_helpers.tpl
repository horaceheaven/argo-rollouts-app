{{/*
Expand the name of the chart.
*/}}
{{- define "nginx-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "nginx-demo.fullname" -}}
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
{{- define "nginx-demo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nginx-demo.labels" -}}
helm.sh/chart: {{ include "nginx-demo.chart" . }}
{{ include "nginx-demo.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nginx-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "nginx-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate HTML content for ConfigMap
*/}}
{{- define "nginx-demo.htmlContent" -}}
{{- $env := .env }}
{{- $config := index .root.Values.html $env -}}
<!DOCTYPE html>
<html>
<head>
    <title>{{ $config.title }}</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background: linear-gradient(135deg, {{ $config.color }} 0%, {{ if eq $env "blue" }}#764ba2{{ else }}#38ef7d{{ end }} 100%);
            font-family: 'Arial', sans-serif;
        }
        .container {
            text-align: center;
            color: white;
            padding: 50px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
        }
        h1 {
            font-size: 72px;
            margin: 20px 0;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .version {
            font-size: 36px;
            margin: 20px 0;
            padding: 20px 40px;
            background: rgba(255, 255, 255, 0.2);
            border-radius: 10px;
        }
        .info {
            font-size: 18px;
            margin-top: 30px;
            opacity: 0.9;
        }
        .badge {
            display: inline-block;
            padding: 10px 20px;
            background: {{ if eq $env "blue" }}#4299e1{{ else }}#48bb78{{ end }};
            border-radius: 20px;
            margin: 10px;
            font-weight: bold;
        }
        {{- if eq $env "green" }}
        .status-banner {
            font-size: 24px;
            font-weight: bold;
            padding: 15px 30px;
            background: rgba(255, 255, 255, 0.3);
            border-radius: 15px;
            margin-bottom: 20px;
            border: 3px solid #fff;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.05); }
        }
        {{- end }}
    </style>
</head>
<body>
    <div class="container">
        {{- if eq $env "green" }}
        <div class="status-banner">🟢 PREVIEW ENVIRONMENT</div>
        <h1>GREEN VERSION</h1>
        {{- else }}
        <div style="font-size: 24px; font-weight: bold; padding: 15px 30px; background: rgba(255, 255, 255, 0.3); border-radius: 15px; margin-bottom: 20px; border: 3px solid #fff;">🔵 PRODUCTION ENVIRONMENT</div>
        <h1>BLUE VERSION</h1>
        {{- end }}
        <div class="version">Version {{ $config.version }}</div>
        <div class="info">
            {{- range $config.badges }}
            <div class="badge">{{ . }}</div>
            {{- end }}
        </div>
        <p style="margin-top: 40px; font-size: 20px;">
            {{- if eq $env "green" }}
            This is the <strong>PREVIEW</strong> environment<br>
            Testing new version before promotion to production<br>
            <span style="font-size: 16px; opacity: 0.8;">Preview Service: {{ .root.Values.blueGreen.previewService }}</span><br>
            <span style="font-size: 14px; opacity: 0.7; margin-top: 10px; display: block;">Ready for manual promotion to production 🚀</span>
            {{- else }}
            This is the <strong>BLUE</strong> environment<br>
            Currently serving all production traffic<br>
            <span style="font-size: 16px; opacity: 0.8;">Active Service: {{ .root.Values.blueGreen.activeService }}</span>
            {{- end }}
        </p>
        <div style="margin-top: 30px; padding: 15px; background: rgba(0,0,0,0.2); border-radius: 10px; font-family: monospace;">
            <div style="font-size: 14px; opacity: 0.9; margin-bottom: 5px;">Git Commit:</div>
            <div style="font-size: 18px; font-weight: bold; color: #fff;">{{ .root.Values.app.image.tag | default "{{GIT_HASH}}" }}</div>
        </div>
    </div>
</body>
</html>
{{- end }}

