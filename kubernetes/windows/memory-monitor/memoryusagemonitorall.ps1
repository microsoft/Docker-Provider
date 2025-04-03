# Monitor memory usage of all processes

$intervalSeconds = 900

$outputDirectory = "C:\var\log"
$outputFile = "$outputDirectory\MemoryUsageLog.csv"

# Ensure the directory exists, create it if it doesn't
if (!(Test-Path -Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory
}

"Timestamp,ProcessName,WorkingSet(MB),ProcessId" | Out-File -FilePath $outputFile -Encoding UTF8 -Force

while ($true) {
    $processes = Get-Process
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    foreach ($process in $processes) {
        $memoryUsageMB = [math]::Round($process.WorkingSet / 1MB, 2)
        "$timestamp,$($process.Name),$memoryUsageMB,$($process.Id)" | Out-File -FilePath $outputFile -Encoding UTF8 -Append
    }
    
    Start-Sleep -Seconds $intervalSeconds
}