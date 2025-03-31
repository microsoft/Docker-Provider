# Start Windows exporter with the required collectors
$windowsExporterPath = "C:\opt\windows_exporter\windows_exporter.exe"

# Check if Windows exporter exists, download if not
if (!(Test-Path $windowsExporterPath)) {
    Write-Host "Windows exporter not found. Downloading first..."
    
    # In container environment, the download script will be in the same directory
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    $downloadScript = Join-Path $scriptPath "download_windows_exporter.ps1"
    
    # If script exists, run it
    if (Test-Path $downloadScript) {
        Write-Host "Using download script at $downloadScript"
        & $downloadScript
    } else {
        # Fallback if download script not found in same directory
        $containerDownloadScript = "C:\opt\amalogswindows\scripts\powershell\windows_exporter\download_windows_exporter.ps1"
        if (Test-Path $containerDownloadScript) {
            Write-Host "Using download script at $containerDownloadScript"
            & $containerDownloadScript
        } else {
            Write-Error "Windows exporter download script not found. Cannot proceed."
            exit 1
        }
    }
    
    # Verify download was successful
    if (!(Test-Path $windowsExporterPath)) {
        Write-Error "Windows exporter download failed. Binary not found at $windowsExporterPath"
        exit 1
    }
}

# Use environment variables for configuration if available
$envCollectors = [System.Environment]::GetEnvironmentVariable("WINDOWS_EXPORTER_COLLECTORS", "process")
$envPort = [System.Environment]::GetEnvironmentVariable("WINDOWS_EXPORTER_PORT", "process")

# Define collectors to enable - use env var if available, otherwise use defaults
if (![string]::IsNullOrEmpty($envCollectors)) {
    $collectors = $envCollectors.Split(",")
    Write-Host "Using collectors from environment variable: $envCollectors"
} else {
    $collectors = @(
        "process",
        "memory",
        "cpu",
        "cs",
        "logical_disk",
        "net",
        "os",
        "system",
        "container"
    )
    Write-Host "Using default collectors: $($collectors -join ", ")"
}

# Define metrics endpoint port - use env var if available, otherwise use default
if (![string]::IsNullOrEmpty($envPort)) {
    $port = $envPort
    Write-Host "Using port from environment variable: $port"
} else {
    $port = "9182"
    Write-Host "Using default port: $port"
}

$collectorsArg = "--collectors.enabled=" + ($collectors -join ",")
$webListenAddress = "--web.listen-address=:$port"

# Start Windows exporter
Write-Host "Starting Windows exporter with collectors: $($collectors -join ", ") on port $port"
try {
    Start-Process -NoNewWindow -FilePath $windowsExporterPath -ArgumentList @($collectorsArg, $webListenAddress)
    Write-Host "Windows exporter started successfully on port $port"
} catch {
    Write-Error "Failed to start Windows exporter: $_"
    exit 1
}