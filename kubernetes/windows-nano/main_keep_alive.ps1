# main_keep_alive.ps1
# This script does nothing except keep the container alive.

Write-Host "main_keep_alive.ps1: Container keep-alive loop started. Press Ctrl+C to exit."

while ($true) {
    Start-Sleep -Seconds 3600
}