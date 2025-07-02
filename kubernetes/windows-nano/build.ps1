# Build script for Windows Nano Server 2025 Azure Monitor Agent
# Run this script on a local Windows PC with Docker Desktop

param(
    [string]$ImageName = "azure-monitor-nano",
    [string]$Tag = "latest",
    [switch]$NoBuildCache,
    [switch]$Verbose
)

Write-Host "Building Windows Nano Server 2025 Azure Monitor Agent..." -ForegroundColor Green

# Check if Docker is running
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker not accessible"
    }
    Write-Host "✓ Docker is running (version: $dockerVersion)" -ForegroundColor Green
}
catch {
    Write-Error "❌ Docker is not running or not installed. Please start Docker Desktop."
    exit 1
}

# Check if we're on Windows
if ($PSVersionTable.Platform -ne "Win32NT" -and $env:OS -ne "Windows_NT") {
    Write-Warning "⚠ This script is designed for Windows. You may encounter issues on other platforms."
}

# Set Docker build context to current directory
$buildContext = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $buildContext

Write-Host "Build context: $buildContext" -ForegroundColor Cyan

# Prepare Docker build arguments
$dockerArgs = @(
    "build"
    "-t", "${ImageName}:${Tag}"
    "."
)

if ($NoBuildCache) {
    $dockerArgs += "--no-cache"
    Write-Host "✓ Build cache disabled" -ForegroundColor Yellow
}

if ($Verbose) {
    $dockerArgs += "--progress=plain"
    Write-Host "✓ Verbose output enabled" -ForegroundColor Yellow
}

# Display build information
Write-Host "`nBuild Information:" -ForegroundColor Cyan
Write-Host "  Image Name: ${ImageName}:${Tag}" -ForegroundColor White
Write-Host "  Build Context: $buildContext" -ForegroundColor White
Write-Host "  No Cache: $NoBuildCache" -ForegroundColor White
Write-Host "  Verbose: $Verbose" -ForegroundColor White

# Confirm before building
$confirmation = Read-Host "`nProceed with build? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Build cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nStarting Docker build..." -ForegroundColor Green
Write-Host "Command: docker $($dockerArgs -join ' ')" -ForegroundColor Cyan

# Execute Docker build
$startTime = Get-Date
& docker @dockerArgs

if ($LASTEXITCODE -eq 0) {
    $endTime = Get-Date
    $buildTime = $endTime - $startTime
    
    Write-Host "`n✅ Build completed successfully!" -ForegroundColor Green
    Write-Host "Build time: $($buildTime.ToString('mm\:ss'))" -ForegroundColor Green
    Write-Host "Image: ${ImageName}:${Tag}" -ForegroundColor Green
    
    # Show image information
    Write-Host "`nImage Information:" -ForegroundColor Cyan
    docker images $ImageName --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
    
    # Provide next steps
    Write-Host "`nNext Steps:" -ForegroundColor Cyan
    Write-Host "  Run the image:     docker run ${ImageName}:${Tag}" -ForegroundColor White
    Write-Host "  Test components:   docker run ${ImageName}:${Tag} pwsh -File C:\opt\scripts\test-components.ps1" -ForegroundColor White
    Write-Host "  Interactive shell: docker run -it ${ImageName}:${Tag} pwsh" -ForegroundColor White
    
} else {
    Write-Error "❌ Build failed with exit code $LASTEXITCODE"
    Write-Host "`nTroubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  1. Ensure Docker Desktop is running and configured for Windows containers" -ForegroundColor White
    Write-Host "  2. Check your internet connection for downloading components" -ForegroundColor White
    Write-Host "  3. Try building with --no-cache flag: .\build.ps1 -NoBuildCache" -ForegroundColor White
    Write-Host "  4. Enable verbose output: .\build.ps1 -Verbose" -ForegroundColor White
    exit 1
}
