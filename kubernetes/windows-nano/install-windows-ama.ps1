# Install Windows Azure Monitor Agent for Nano Server
# Based on kubernetes/windows/setup.ps1

$windowsazuremonitoragent = [System.Environment]::GetEnvironmentVariable("WINDOWS_AMA_URL_NEW", "process")
if ([string]::IsNullOrEmpty($windowsazuremonitoragent)) {
    Write-Host ('Environment variable WINDOWS_AMA_URL is not set. Using default value')
    $windowsazuremonitoragent = "https://github.com/microsoft/Docker-Provider/releases/download/windows-ama-bits/genevamonitoringagent.46.31.3.zip"
}
Write-Host ('Installing Windows Azure Monitor Agent: ' + $windowsazuremonitoragent)
try {
    Invoke-WebRequest -Uri $windowsazuremonitoragent -OutFile /installation/windowsazuremonitoragent.zip
    Expand-Archive -Path /installation/windowsazuremonitoragent.zip -Destination /installation/windowsazuremonitoragent
    Move-Item -Path /installation/windowsazuremonitoragent -Destination /opt/windowsazuremonitoragent/ -ErrorAction SilentlyContinue
    $version = (Get-Item C:\opt\windowsazuremonitoragent\windowsazuremonitoragent\Monitoring\Agent\MonAgentCore.exe).VersionInfo.ProductVersion
    if ([string]::IsNullOrEmpty($version)) {
        echo "Monitoring Agent Version not found" > /opt/windowsazuremonitoragent/version.txt
    } else {
        echo "Monitoring Agent Version - $version" > /opt/windowsazuremonitoragent/version.txt
    }
}
catch {
    $ex = $_.Exception
    Write-Host "exception while downloading windowsazuremonitoragent"
    Write-Host $ex
    exit 1
}
Write-Host ('Finished downloading Windows Azure Monitor Agent')
Write-Host ("Removing Install folder")
Remove-Item /installation -Recurse
