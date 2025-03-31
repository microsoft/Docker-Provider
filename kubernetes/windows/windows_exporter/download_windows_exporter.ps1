# Download and configure Windows exporter
$windowsExporterVersion = "0.25.0"
$windowsExporterUrl = "https://github.com/prometheus-community/windows_exporter/releases/download/v$windowsExporterVersion/windows_exporter-$windowsExporterVersion-amd64.exe"
$windowsExporterPath = "C:\opt\windows_exporter\windows_exporter.exe"

# Create directory
if (!(Test-Path "C:\opt\windows_exporter")) {
    New-Item -ItemType Directory -Path "C:\opt\windows_exporter" -Force
}

# Download the exporter
Write-Host "Downloading Windows exporter v$windowsExporterVersion..."
Invoke-WebRequest -Uri $windowsExporterUrl -OutFile $windowsExporterPath

Write-Host "Windows exporter downloaded successfully to $windowsExporterPath"