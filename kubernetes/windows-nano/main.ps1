# Main orchestration script for Windows Nano Server Azure Monitor Agent
Write-Host "Starting Azure Monitor Agent on Windows Nano Server 2025..."

# Function to test if a TCP port is listening
function Test-TcpPort {
    param (
        [string]$Host = "127.0.0.1",
        [int]$Port,
        [int]$TimeoutSeconds = 5
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($Host, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutSeconds * 1000, $false)
        
        if ($wait) {
            $tcpClient.EndConnect($asyncResult)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    }
    catch {
        return $false
    }
}

# Function to wait for Fluent Bit TCP listener
function Wait-ForFluentBitTcpListener {
    param (
        [int]$Port = 25229,
        [int]$MaxWaitSeconds = 30
    )
    
    Write-Host "Waiting for Fluent Bit TCP listener on port $Port..."
    $waitTime = 0
    $retryInterval = 2
    
    while ($waitTime -lt $MaxWaitSeconds) {
        if (Test-TcpPort -Port $Port) {
            Write-Host "✓ Fluent Bit TCP listener is ready on port $Port"
            return $true
        }
        
        Start-Sleep -Seconds $retryInterval
        $waitTime += $retryInterval
        Write-Host "Waiting... ($waitTime/$MaxWaitSeconds seconds)"
    }
    
    Write-Host "⚠ Fluent Bit TCP listener not ready after $MaxWaitSeconds seconds"
    return $false
}

# Start Fluent Bit as background job
Write-Host "Starting Fluent Bit..."
try {
    $fluentBitJob = Start-Job -ScriptBlock {
        Write-Host "Fluent Bit starting..."
        & "C:\opt\fluent-bit\bin\fluent-bit.exe" -i dummy -o stdout
    }
    Write-Host "✓ Fluent Bit started as background job (ID: $($fluentBitJob.Id))"
}
catch {
    Write-Error "Failed to start Fluent Bit: $($_.Exception.Message)"
    exit 1
}

# Wait a moment for Fluent Bit to initialize
Start-Sleep -Seconds 5

# Start Telegraf as background job
Write-Host "Starting Telegraf..."
try {
    $telegrafJob = Start-Job -ScriptBlock {
        Write-Host "Telegraf starting..."
        & "C:\opt\telegraf\bin\telegraf.exe" --config "C:\etc\telegraf\telegraf.conf"
    }
    Write-Host "✓ Telegraf started as background job (ID: $($telegrafJob.Id))"
}
catch {
    Write-Error "Failed to start Telegraf: $($_.Exception.Message)"
    # Continue without Telegraf - Fluent Bit can still work
}

# Monitor running jobs
Write-Host "`nMonitoring running services..."
Write-Host "Press Ctrl+C to stop all services"

try {
    while ($true) {
        # Check job status
        $jobs = Get-Job
        $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
        $failedJobs = $jobs | Where-Object { $_.State -eq 'Failed' }
        
        if ($failedJobs) {
            Write-Host "⚠ Failed jobs detected:"
            foreach ($job in $failedJobs) {
                Write-Host "  - Job $($job.Id): $($job.Name) - $($job.State)"
                # Get job output for debugging
                $jobOutput = Receive-Job -Job $job
                if ($jobOutput) {
                    Write-Host "    Output: $jobOutput"
                }
            }
        }
        
        if ($runningJobs.Count -eq 0) {
            Write-Host "⚠ No services are running. Exiting..."
            break
        }
        
        Write-Host "✓ Services running: $($runningJobs.Count) ($(Get-Date -Format 'HH:mm:ss'))"
        
        # Wait before next check
        Start-Sleep -Seconds 30
    }
}
catch {
    Write-Host "Monitoring interrupted: $($_.Exception.Message)"
}
finally {
    # Cleanup: Stop all background jobs
    Write-Host "`nStopping all services..."
    $jobs = Get-Job
    foreach ($job in $jobs) {
        if ($job.State -eq 'Running') {
            Write-Host "Stopping job $($job.Id): $($job.Name)"
            Stop-Job -Job $job
        }
        Remove-Job -Job $job -Force
    }
    Write-Host "All services stopped."
}
