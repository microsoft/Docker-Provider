# .\build-multi-all.ps1 -Push -CreateManifest
# Multi-Platform Docker Build Script for Fake SDK (Windows + Linux)
# This script builds Docker images for Windows (2022, 2019) and Linux (amd64, arm64)
# and creates a single unified manifest that works across all platforms
param(
    [string]$ImageName = "appmonitoring.azurecr.io/dotnet-fake",
    [string]$Tag = "latest",
    [switch]$Push
)

$ErrorActionPreference = "Stop"

# Use temporary tags for individual platform images
$localImage2022 = "${ImageName}:temp-win2022"
$localImage2019 = "${ImageName}:temp-win2019"
$linuxImageAmd64 = "${ImageName}:temp-linux-amd64"
$linuxImageArm64 = "${ImageName}:temp-linux-arm64"
$manifestTag = "${ImageName}:${Tag}"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Multi-Platform Fake SDK Image Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Image name: $ImageName" -ForegroundColor White
Write-Host "Tag: $Tag" -ForegroundColor White
Write-Host ""

# Step 1: Build Windows images
Write-Host "[1/3] Building Windows images..." -ForegroundColor Green
Write-Host "Switching to Windows containers..." -ForegroundColor Cyan
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchWindowsEngine
Start-Sleep -Seconds 3

Write-Host "Building Windows Server 2022 image..." -ForegroundColor Cyan
docker build -f Dockerfile.windows --target final-2022 -t $localImage2022 .
if ($LASTEXITCODE -ne 0) { throw "Failed to build Windows 2022 image" }

Write-Host "Building Windows Server 2019 image..." -ForegroundColor Cyan
docker build -f Dockerfile.windows --target final-2019 -t $localImage2019 .
if ($LASTEXITCODE -ne 0) { throw "Failed to build Windows 2019 image" }

Write-Host "✓ Windows images built successfully" -ForegroundColor Green
Write-Host ""

# Step 2: Build Linux images
Write-Host "[2/3] Building Linux images..." -ForegroundColor Green
Write-Host "Switching to Linux containers..." -ForegroundColor Cyan
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchLinuxEngine
Start-Sleep -Seconds 3

Write-Host "Building multi-architecture Linux images (amd64 + arm64)..." -ForegroundColor Cyan
if ($Push) {
    # Build and push Linux images as a combined multi-arch image with temporary tag
    docker buildx build --platform linux/amd64,linux/arm64 `
        -f Dockerfile.linux `
        -t "${ImageName}:temp-linux" `
        --push .
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to build and push Linux images" }
    Write-Host "✓ Linux multi-arch image built and pushed successfully" -ForegroundColor Green
} else {
    # Just build for local testing (amd64 only for local)
    docker buildx build --platform linux/amd64 `
        -f Dockerfile.linux `
        -t "${ImageName}:temp-linux" `
        --load .
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to build Linux image" }
    Write-Host "✓ Linux image built successfully (local amd64 only)" -ForegroundColor Green
}
Write-Host ""

if ($Push) {
    # Step 3: Push Windows images
    Write-Host "[3/3] Pushing Windows images and creating unified manifest..." -ForegroundColor Green
    
    # Switch back to Windows to push Windows images
    Write-Host "Switching to Windows containers for push..." -ForegroundColor Cyan
    & "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchWindowsEngine
    Start-Sleep -Seconds 3
    
    Write-Host "Pushing Windows Server 2022 image..." -ForegroundColor Cyan
    docker push $localImage2022
    if ($LASTEXITCODE -ne 0) { throw "Failed to push Windows 2022 image" }
    
    Write-Host "Pushing Windows Server 2019 image..." -ForegroundColor Cyan
    docker push $localImage2019
    if ($LASTEXITCODE -ne 0) { throw "Failed to push Windows 2019 image" }
    
    Write-Host "✓ Windows images pushed successfully" -ForegroundColor Green
    Write-Host ""
    
    # Step 4: Create unified manifest for ALL platforms (Windows + Linux)
    Write-Host "Creating unified manifest for ALL platforms (Windows 2019, 2022, Linux amd64, arm64)..." -ForegroundColor Yellow
    
    # Remove existing manifest if it exists
    docker manifest rm $manifestTag 2>$null
    
    # Get the individual platform digests from the Linux manifest
    Write-Host "Retrieving Linux platform digests..." -ForegroundColor Cyan
    $linuxManifest = docker manifest inspect "${ImageName}:temp-linux" | ConvertFrom-Json
    $linuxAmd64Digest = ($linuxManifest.manifests | Where-Object { $_.platform.architecture -eq "amd64" -and $_.platform.os -eq "linux" }).digest
    $linuxArm64Digest = ($linuxManifest.manifests | Where-Object { $_.platform.architecture -eq "arm64" -and $_.platform.os -eq "linux" }).digest
    
    Write-Host "  Linux amd64 digest: $linuxAmd64Digest" -ForegroundColor Gray
    Write-Host "  Linux arm64 digest: $linuxArm64Digest" -ForegroundColor Gray
    
    # Create manifest with ALL platform images using digests for Linux
    Write-Host "Creating manifest with all platform images..." -ForegroundColor Cyan
    docker manifest create $manifestTag `
        --amend $localImage2022 `
        --amend $localImage2019 `
        --amend "${ImageName}@${linuxAmd64Digest}" `
        --amend "${ImageName}@${linuxArm64Digest}"
    
    if ($LASTEXITCODE -ne 0) { throw "Failed to create unified manifest" }
    
    Write-Host "✓ Unified manifest created successfully" -ForegroundColor Green
    Write-Host ""
    
    # Push the unified manifest
    Write-Host "Pushing unified manifest..." -ForegroundColor Cyan
    docker manifest push $manifestTag
    if ($LASTEXITCODE -ne 0) { throw "Failed to push manifest" }
    
    Write-Host "✓ Manifest pushed successfully" -ForegroundColor Green
    Write-Host ""
    
    # Clean up temporary tags
    Write-Host "Cleaning up temporary tags..." -ForegroundColor Cyan
    docker manifest rm $localImage2022 2>$null
    docker manifest rm $localImage2019 2>$null
    docker manifest rm "${ImageName}:temp-linux" 2>$null
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Build and Push Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Single unified image: $manifestTag" -ForegroundColor Green
    Write-Host ""
    Write-Host "Supported platforms:" -ForegroundColor White
    Write-Host "  ✓ Windows Server 2022 (LTSC 2022)" -ForegroundColor Cyan
    Write-Host "  ✓ Windows Server 2019 (LTSC 2019)" -ForegroundColor Cyan
    Write-Host "  ✓ Linux amd64" -ForegroundColor Cyan
    Write-Host "  ✓ Linux arm64" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage in Kubernetes:" -ForegroundColor Yellow
    Write-Host "  image: $manifestTag" -ForegroundColor White
    Write-Host "  (Automatically selects correct OS and architecture)" -ForegroundColor Gray
} else {
    Write-Host "[3/3] Skipping push (use -Push to push images)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Local Build Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Built images (local):" -ForegroundColor White
    Write-Host "  - $localImage2022" -ForegroundColor Cyan
    Write-Host "  - $localImage2019" -ForegroundColor Cyan
    Write-Host "  - ${ImageName}:temp-linux" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Note: To create the unified manifest, use -Push to push to registry first." -ForegroundColor Yellow
}

# Switch back to Linux containers
Write-Host ""
Write-Host "Switching back to Linux containers..." -ForegroundColor Cyan
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchLinuxEngine
Start-Sleep -Seconds 2
Write-Host "✓ Switched back to Linux containers" -ForegroundColor Green
