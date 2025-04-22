# Basic startup script for Fluent Bit on Nano Server
Write-Host "Starting Windows log agent on Nano Server POC"

# Set basic environment variables
$env:Path = "C:\opt\fluent-bit\bin;$env:Path"
$env:CONTAINER_RUNTIME = "containerd" # Default value

Write-Host "Container Runtime: $env:CONTAINER_RUNTIME"

# Add diagnostic information to check for files
Write-Host "Checking for Fluent Bit executable and DLLs..."
$fluentBitExe = "C:\opt\fluent-bit\bin\fluent-bit.exe"
$requiredDlls = @(
    "C:\Windows\System32\msvcp140.dll",
    "C:\Windows\System32\vcruntime140.dll", 
    "C:\Windows\System32\vccorlib140.dll"
)

# Check for Fluent Bit executable
if (Test-Path $fluentBitExe) {
    Write-Host "Found Fluent Bit executable at $fluentBitExe"
} else {
    Write-Host "ERROR: Fluent Bit executable not found at $fluentBitExe"
    Get-ChildItem -Path "C:\opt\fluent-bit\" -Recurse | Select-Object FullName
}

# Check for required DLLs
foreach ($dll in $requiredDlls) {
    if (Test-Path $dll) {
        Write-Host "Found required DLL: $dll"
    } else {
        Write-Host "WARNING: Required DLL not found: $dll"
    }
}

# Check directory contents
Write-Host "Contents of C:\opt\fluent-bit\bin:"
Get-ChildItem -Path "C:\opt\fluent-bit\bin" -Force | Format-Table Name, Length

Write-Host "Starting Fluent Bit..."

# Try to start Fluent Bit with more detailed error handling
try {
    # Try using .NET's Process class to get more error details
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $fluentBitExe
    $psi.Arguments = "-c C:/etc/fluent-bit/fluent-bit.conf"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    
    # Register event handlers for output
    $stdoutEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
        Write-Host "Fluent Bit Output: $($EventArgs.Data)"
    }
    $stderrEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
        Write-Host "Fluent Bit Error: $($EventArgs.Data)"
    }
    
    # Start the process
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    
    # Wait for process to exit
    $process.WaitForExit()
    
    # Clean up event handlers
    Unregister-Event -SourceIdentifier $stdoutEvent.Name
    Unregister-Event -SourceIdentifier $stderrEvent.Name
    
    # Check exit code
    if ($process.ExitCode -ne 0) {
        Write-Host "Exit Code: $($process.ExitCode) (0x$('{0:X}' -f $process.ExitCode))"
        
        # Run detailed dependency analysis
        Write-Host "Running detailed dependency analysis..."
        $analyzerPath = "C:\opt\amalogswindows\scripts\analyze-dependencies.ps1"
        
        if (Test-Path $analyzerPath) {
            & $analyzerPath $fluentBitExe
        } else {
            # If the script isn't installed yet, let's copy it from our current location
            $scriptPath = Join-Path -Path (Get-Location) -ChildPath "analyze-dependencies.ps1"
            if (Test-Path $scriptPath) {
                # Create directory if it doesn't exist
                $targetDir = "C:\opt\amalogswindows\scripts"
                if (-not (Test-Path $targetDir)) {
                    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                }
                
                # Copy the script
                Copy-Item -Path $scriptPath -Destination $analyzerPath -Force
                
                # Run the analysis
                & $analyzerPath $fluentBitExe
            } else {
                Write-Warning "Dependency analyzer script not found."
            }
        }
        
        Write-Error "Fluent Bit exited with code: $($process.ExitCode)"
        exit $process.ExitCode
    }
} catch {
    Write-Error "Failed to start Fluent Bit: $_"
    # exit 1
}

# Container continues running even if Fluent Bit fails
Write-Host "Container will continue running..."
while ($true) {
    Start-Sleep -Seconds 600
}
