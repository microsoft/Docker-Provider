# Monitor memory usage of multiple processes
# $processNames = @("fluent-bit", "telegraf", "MonAgentCore", "MonAgentManager", "MonAgentHost", "MonAgentLauncher")
$processNames = @("fluent-bit", "MonAgentCore", "MonAgentManager", "MonAgentHost", "MonAgentLauncher")

$intervalSeconds = 900

$outputDirectory = "C:\var\log"
#outputDirectory = "C:\opt\amalogswindows\scripts\powershell"
$outputFile = "$outputDirectory\MemoryUsageLog.csv"

# Ensure the directory exists, create it if it doesn't
if (!(Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory
}

"Timestamp,ProcessName,WorkingSet(MB)" | Out-File -FilePath $outputFile -Encoding UTF8 -Force

while ($true) {
    foreach ($processName in $processNames) {
        $process = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($process) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $memoryUsageMB = [math]::Round($process.WorkingSet / 1MB, 2)
            "$timestamp,$processName,$memoryUsageMB" | Out-File -FilePath $outputFile -Encoding UTF8 -Append
        }
    }
    Start-Sleep -Seconds $intervalSeconds
}