# Multi-Windows Version Docker Build Script
# This script builds Docker images for both Windows 2022 and Windows 2019

param(
    [string]$ImageName = "appmonitoring.azurecr.io/demoaks-dotnet-app-win",
    [string]$Tag = "latest",
    [switch]$Push,
    [switch]$CreateManifest
)

$ErrorActionPreference = "Stop"

Write-Host "Building multi-Windows Docker images..." -ForegroundColor Green
Write-Host "Image Name: $ImageName" -ForegroundColor Yellow
Write-Host "Tag: $Tag" -ForegroundColor Yellow

# Switch to Windows containers
Write-Host "Switching to Windows containers..." -ForegroundColor Cyan
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchWindowsEngine

# Build Windows 2022 image
Write-Host "Building Windows 2022 image..." -ForegroundColor Cyan
$localImage2022 = "local-win2022-$(Get-Random)"
docker build -f Dockerfile.windows --target final-2022 -t $localImage2022 .
if ($LASTEXITCODE -ne 0) {
    throw "Failed to build Windows 2022 image"
}

# Build Windows 2019 image
Write-Host "Building Windows 2019 image..." -ForegroundColor Cyan
$localImage2019 = "local-win2019-$(Get-Random)"
docker build -f Dockerfile.windows --target final-2019 -t $localImage2019 .
if ($LASTEXITCODE -ne 0) {
    throw "Failed to build Windows 2019 image"
}

Write-Host "Successfully built both images:" -ForegroundColor Green
Write-Host "  - $localImage2022" -ForegroundColor Yellow
Write-Host "  - $localImage2019" -ForegroundColor Yellow

if ($Push) {
    if ($CreateManifest) {
        Write-Host "Pushing images with platform-specific tags..." -ForegroundColor Cyan
        
        # Use clear, descriptive platform-specific tags
        $platformTag2022 = "${ImageName}:ltsc2022"
        $platformTag2019 = "${ImageName}:ltsc2019"
        
        # Tag and push Windows 2022 image
        Write-Host "Pushing Windows Server 2022 image..." -ForegroundColor Yellow
        docker tag $localImage2022 $platformTag2022
        docker push $platformTag2022
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push Windows Server 2022 image"
        }
        
        # Tag and push Windows 2019 image
        Write-Host "Pushing Windows Server 2019 image..." -ForegroundColor Yellow
        docker tag $localImage2019 $platformTag2019
        docker push $platformTag2019
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push Windows Server 2019 image"
        }
        
        Write-Host "Successfully pushed platform-specific images:" -ForegroundColor Green
        Write-Host "  - $platformTag2022" -ForegroundColor Yellow
        Write-Host "  - $platformTag2019" -ForegroundColor Yellow
        
        # Extract OS versions from the actual images
        Write-Host "Extracting OS versions from images..." -ForegroundColor Cyan
        
        # Try multiple methods to extract OS version for Windows 2022
        $osVersion2022 = docker image inspect $platformTag2022 --format='{{.Os}}' 2>$null
        if ($osVersion2022 -eq "windows") {
            # Try to get OS version from different possible locations
            $osVersion2022 = docker image inspect $platformTag2022 --format='{{index .Config.Labels "org.opencontainers.image.version"}}' 2>$null
            if (-not $osVersion2022) {
                $osVersion2022 = docker image inspect $platformTag2022 --format='{{.OsVersion}}' 2>$null
            }
            if (-not $osVersion2022) {
                $osVersion2022 = docker image inspect $platformTag2022 --format='{{index .Config.Labels "os.version"}}' 2>$null
            }
            if (-not $osVersion2022) {
                # Try to extract from base image info - look for LTSC2022 pattern
                $imageConfig = docker image inspect $platformTag2022 --format='{{json .}}' | ConvertFrom-Json
                if ($imageConfig.Config.Labels.PSObject.Properties.Name -contains "org.opencontainers.image.base.name") {
                    $baseName = $imageConfig.Config.Labels."org.opencontainers.image.base.name"
                    if ($baseName -match "ltsc2022") {
                        $osVersion2022 = "10.0.20348"
                    }
                }
            }
        }
        
        if (-not $osVersion2022) {
            throw "Could not extract OS version from Windows 2022 image: $platformTag2022. Try: docker image inspect $platformTag2022"
        }
        
        # Try multiple methods to extract OS version for Windows 2019
        $osVersion2019 = docker image inspect $platformTag2019 --format='{{.Os}}' 2>$null
        if ($osVersion2019 -eq "windows") {
            # Try to get OS version from different possible locations
            $osVersion2019 = docker image inspect $platformTag2019 --format='{{index .Config.Labels "org.opencontainers.image.version"}}' 2>$null
            if (-not $osVersion2019) {
                $osVersion2019 = docker image inspect $platformTag2019 --format='{{.OsVersion}}' 2>$null
            }
            if (-not $osVersion2019) {
                $osVersion2019 = docker image inspect $platformTag2019 --format='{{index .Config.Labels "os.version"}}' 2>$null
            }
            if (-not $osVersion2019) {
                # Try to extract from base image info - look for LTSC2019 pattern
                $imageConfig = docker image inspect $platformTag2019 --format='{{json .}}' | ConvertFrom-Json
                if ($imageConfig.Config.Labels.PSObject.Properties.Name -contains "org.opencontainers.image.base.name") {
                    $baseName = $imageConfig.Config.Labels."org.opencontainers.image.base.name"
                    if ($baseName -match "ltsc2019") {
                        $osVersion2019 = "10.0.17763"
                    }
                }
            }
        }
        
        if (-not $osVersion2019) {
            throw "Could not extract OS version from Windows 2019 image: $platformTag2019. Try: docker image inspect $platformTag2019"
        }
        
        Write-Host "Detected OS versions:" -ForegroundColor Green
        Write-Host "  Windows 2022: $osVersion2022" -ForegroundColor Yellow
        Write-Host "  Windows 2019: $osVersion2019" -ForegroundColor Yellow
        
        # Create manifest using platform-specific tag references
        Write-Host "Creating multi-architecture manifest..." -ForegroundColor Cyan
        $manifestName = "${ImageName}:win"
        
        docker manifest create --amend $manifestName $platformTag2022 $platformTag2019
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create manifest"
        }
        
        # Annotate for Windows versions using detected OS versions
        docker manifest annotate $manifestName $platformTag2022 --os windows --arch amd64 --os-version $osVersion2022
        docker manifest annotate $manifestName $platformTag2019 --os windows --arch amd64 --os-version $osVersion2019
        
        # Push manifest
        docker manifest push $manifestName
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push manifest"
        }
        
        Write-Host "Successfully pushed manifest: $manifestName" -ForegroundColor Green
        
        # Clean up local images
        Write-Host "Cleaning up local images..." -ForegroundColor Cyan
        docker rmi $localImage2022 $localImage2019 -f 2>$null
        
        Write-Host "Successfully created and pushed manifest: $manifestName" -ForegroundColor Green
        Write-Host "Platform-specific images:" -ForegroundColor Green
        Write-Host "  - $platformTag2022" -ForegroundColor Yellow
        Write-Host "  - $platformTag2019" -ForegroundColor Yellow
        Write-Host "Multi-platform manifest: $manifestName" -ForegroundColor Green
        
    } else {
        # Traditional push with user-friendly tags
        Write-Host "Pushing images with user-friendly tags..." -ForegroundColor Cyan
        
        $image2022 = "${ImageName}:2022-${Tag}"
        $image2019 = "${ImageName}:2019-${Tag}"
        
        docker tag $localImage2022 $image2022
        docker tag $localImage2019 $image2019
        
        docker push $image2022
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push Windows 2022 image"
        }
        
        docker push $image2019
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push Windows 2019 image"
        }
        
        # Clean up local images
        docker rmi $localImage2022 $localImage2019 -f 2>$null
        
        Write-Host "Successfully pushed both images with user-friendly tags" -ForegroundColor Green
        Write-Host "  - $image2022" -ForegroundColor Yellow
        Write-Host "  - $image2019" -ForegroundColor Yellow
    }
} else {
    # If not pushing, create user-friendly local tags for development
    $image2022 = "${ImageName}:2022-${Tag}"
    $image2019 = "${ImageName}:2019-${Tag}"
    docker tag $localImage2022 $image2022
    docker tag $localImage2019 $image2019
    docker rmi $localImage2022 $localImage2019 -f 2>$null
    
    Write-Host "Tagged images locally:" -ForegroundColor Green
    Write-Host "  - $image2022" -ForegroundColor Yellow
    Write-Host "  - $image2019" -ForegroundColor Yellow
}

# Switch back to Linux containers
Write-Host "Switching back to Linux containers..." -ForegroundColor Cyan
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchLinuxEngine

Write-Host "Build completed successfully!" -ForegroundColor Green