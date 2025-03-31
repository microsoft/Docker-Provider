# Windows Exporter startup script
Write-Host "Configuring and starting Windows exporter..."

# Define collectors to enable - adjust as needed
$enabledCollectors = "process,memory,cpu,cs,logical_disk,net,os,system,container"

# Start Windows exporter with process collector enabled
$arguments = @(
    "--collectors.enabled=$enabledCollectors",
    "--web.listen-address=:9182"
)

# Start Windows exporter in the background
Start-Process -NoNewWindow -FilePath "C:\opt\windows_exporter\windows_exporter.exe" -ArgumentList $arguments

Write-Host "Windows exporter started with collectors: $enabledCollectors"
