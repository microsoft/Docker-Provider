# Basic startup script for Fluent Bit on Nano Server
Write-Host "Starting Windows log agent on Nano Server POC"

# Set basic environment variables
$env:Path = "C:\opt\fluent-bit\bin;$env:Path"
$env:CONTAINER_RUNTIME = "containerd" # Default value

Write-Host "Container Runtime: $env:CONTAINER_RUNTIME"
Write-Host "Starting Fluent Bit..."

# Try to start Fluent Bit
try {
    & C:\opt\fluent-bit\bin\fluent-bit.exe -c C:/etc/fluent-bit/fluent-bit.conf
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Fluent Bit exited with code: $LASTEXITCODE"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Failed to start Fluent Bit: $_"
    exit 1
}