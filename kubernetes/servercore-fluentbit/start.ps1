# Startup script for Fluent Bit on Server Core
Write-Host "Starting Windows log agent on Server Core"

# Set basic environment variables
$env:Path = "C:\opt\fluent-bit\bin;$env:Path"
$env:CONTAINER_RUNTIME = "containerd" # Default value

Write-Host "Container Runtime: $env:CONTAINER_RUNTIME"

# Add diagnostic information to check for files
Write-Host "Checking for Fluent Bit executable..."
$fluentBitExe = "C:\opt\fluent-bit\bin\fluent-bit.exe"

# Check for Fluent Bit executable
if (Test-Path $fluentBitExe) {
    Write-Host "Found Fluent Bit executable at $fluentBitExe"
} else {
    Write-Host "ERROR: Fluent Bit executable not found at $fluentBitExe"
    Get-ChildItem -Path "C:\opt\fluent-bit\" -Recurse | Select-Object FullName
}

# Check directory contents
Write-Host "Contents of C:\opt\fluent-bit\bin:"
Get-ChildItem -Path "C:\opt\fluent-bit\bin" -Force | Format-Table Name, Length

# Run dependency analysis before starting fluent-bit
Write-Host "Running dependency analysis before starting Fluent Bit..."
$analyzeScript = "C:\opt\amalogswindows\scripts\analyze-dependencies.ps1"
if (Test-Path $analyzeScript) {
    & $analyzeScript $fluentBitExe
} else {
    Write-Host "WARNING: Dependency analysis script not found at $analyzeScript"
}

# Check if the config file exists
$configFile = "C:/etc/fluent-bit/fluent-bit.conf"
if (Test-Path $configFile) {
    Write-Host "Found Fluent Bit config at $configFile"
    Write-Host "===== Fluent Bit Configuration ====="
    Get-Content $configFile | Write-Host
    Write-Host "=================================="
} else {
    Write-Host "ERROR: Fluent Bit config not found at $configFile"
}

Write-Host "Starting Fluent Bit in foreground mode with visible output..."

# Run Fluent Bit with direct output to console for better visibility
try {
    # Start Fluent Bit in a way that shows output directly in the console
    # Use -v flag for verbose output
    Write-Host "Running Fluent Bit with command: $fluentBitExe -c $configFile -v"
    
    # Use Start-Process with -NoNewWindow to capture output in the current window
    $process = Start-Process -FilePath $fluentBitExe -ArgumentList "-c $configFile -v" -NoNewWindow -PassThru
    $processId = $process.Id
    Write-Host "Fluent Bit started with process ID: $processId"
    
    # Keep the script running while monitoring the Fluent Bit process
    Write-Host "Monitoring Fluent Bit process..."
    
    # Create a background job to monitor the log file
    $monitorJob = Start-Job -ScriptBlock {
        param($logFile)
        $lastPosition = 0
        while ($true) {
            if (Test-Path $logFile) {
                $content = Get-Content -Path $logFile -Raw
                if ($content.Length -gt $lastPosition) {
                    $newContent = $content.Substring($lastPosition)
                    Write-Output $newContent
                    $lastPosition = $content.Length
                }
            }
            Start-Sleep -Seconds 2
        }
    } -ArgumentList "C:/opt/amalogswindows/state/fluent-bit.log"
    
    # Monitor for 60 seconds then continue with the script
    $timeout = 60
    $timer = [Diagnostics.Stopwatch]::StartNew()
    
    while ($timer.Elapsed.TotalSeconds -lt $timeout) {
        if ($process.HasExited) {
            Write-Host "Fluent Bit process exited unexpectedly with code: $($process.ExitCode)"
            break
        }
        
        # Get job output
        $jobOutput = Receive-Job -Job $monitorJob
        if ($jobOutput) {
            Write-Host $jobOutput
        }
        
        Start-Sleep -Seconds 1
    }
    
    # Check if Fluent Bit is still running
    if (!$process.HasExited) {
        Write-Host "Fluent Bit is now running stably. Continuing with background monitoring..."
    }
    
} catch {
    Write-Host "Error starting Fluent Bit: $_"
    
    # We already ran the analysis at startup, but run it again for additional context on the error
    Write-Host "Running additional dependency analysis after error..."
    & "C:\opt\amalogswindows\scripts\analyze-dependencies.ps1" $fluentBitExe
}

# Container continues running
Write-Host "Container will continue running and monitoring Fluent Bit..."
while ($true) {
    # Check if Fluent Bit is still running every 10 seconds
    Start-Sleep -Seconds 10
    
    # Try to find the Fluent Bit process
    $fluentBitProcess = Get-Process -Name "fluent-bit" -ErrorAction SilentlyContinue
    
    if ($fluentBitProcess) {
        # Display some log entries periodically
        Write-Host "$(Get-Date) - Fluent Bit is running (PID: $($fluentBitProcess.Id))"
        
        # Show recent log entries if the log file exists
        $logFile = "C:/opt/amalogswindows/state/fluent-bit.log"
        if (Test-Path $logFile) {
            Write-Host "Recent log entries:"
            Get-Content -Path $logFile -Tail 5 | Write-Host
        }
    } else {
        Write-Host "$(Get-Date) - Fluent Bit is not running. Attempting to restart..."
        
        # Attempt to restart Fluent Bit
        try {
            $process = Start-Process -FilePath $fluentBitExe -ArgumentList "-c $configFile -v" -NoNewWindow -PassThru
            Write-Host "Fluent Bit restarted with process ID: $($process.Id)"
        } catch {
            Write-Host "Failed to restart Fluent Bit: $_"
        }
    }
}