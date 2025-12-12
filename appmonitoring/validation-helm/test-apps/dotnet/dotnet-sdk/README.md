# Fake SDK Image for Testing

This directory contains a minimal fake SDK image used for testing the app monitoring webhook mutations on both Windows and Linux nodes.

## Contents

The image contains a single file: `payload.txt` with test content.

## Directory Structure

```
dotnet-sdk/
├── Dockerfile.windows       # Windows multi-version Dockerfile (2019 & 2022)
├── Dockerfile.linux         # Linux multi-arch Dockerfile (amd64 & arm64)
├── build-multi-windows.ps1  # Build script for Windows images only
├── build-multi-all.ps1      # Build script for all platforms (Windows + Linux)
└── README.md               # This file
```

## Building Images

### Option 1: Build All Platforms (Recommended)

Build and push images for Windows (2019, 2022) and Linux (amd64, arm64):

```powershell
.\build-multi-all.ps1 -Push
```

This creates:
- Windows manifest: `appmonitoring.azurecr.io/dotnet-fake:latest` (includes Win2019 & Win2022)
- Linux multi-arch: `appmonitoring.azurecr.io/dotnet-fake:linux-latest` (includes amd64 & arm64)

### Option 2: Build Windows Only

Build and push Windows images only:

```powershell
.\build-multi-windows.ps1 -Push -CreateManifest
```

### Option 3: Build Linux Only

Build and push Linux multi-arch images:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Dockerfile.linux \
  -t appmonitoring.azurecr.io/dotnet-fake:linux-latest \
  --push .
```

### Local Testing (No Push)

Build locally without pushing:

```powershell
# Windows images
.\build-multi-windows.ps1

# All platforms (Linux will be local amd64 only)
.\build-multi-all.ps1

# Linux only (local amd64)
docker buildx build --platform linux/amd64 -f Dockerfile.linux -t dotnet-fake:linux-test --load .
```

## Custom Tags and Names

```powershell
# Custom image name and tag
.\build-multi-all.ps1 -ImageName "myregistry.azurecr.io/my-fake-sdk" -Tag "v1.0" -Push

# Windows only with custom values
.\build-multi-windows.ps1 -ImageName "myregistry.azurecr.io/my-fake-sdk" -Tag "v1.0" -Push -CreateManifest
```

## Using in Kubernetes

The webhook mutations will reference these images as init containers. For testing:

**Windows Nodes:**
```yaml
image: appmonitoring.azurecr.io/dotnet-fake:latest
```
The manifest will automatically select the correct Windows version (2019 or 2022) based on the node's OS version.

**Linux Nodes:**
```yaml
image: appmonitoring.azurecr.io/dotnet-fake:linux-latest
```
The multi-arch manifest will automatically select the correct architecture (amd64 or arm64).

## Image Details

**Workdir:** `/dotnet-tracer-home` (Linux) or `C:\dotnet-tracer-home` (Windows)

**Contents:** Single file `payload.txt` containing: "This is a fake SDK payload for testing"

**Base Images:**
- Windows 2022: `mcr.microsoft.com/windows/nanoserver:ltsc2022`
- Windows 2019: `mcr.microsoft.com/windows/nanoserver:1809`
- Linux: `scratch` (minimal)

## Prerequisites

- Docker Desktop with Windows containers support
- Access to `appmonitoring.azurecr.io` registry (or configure your own)
- For Linux builds: Buildx enabled (`docker buildx ls`)

## Troubleshooting

**"Failed to switch to Windows containers"**
- Ensure Docker Desktop is running with Windows containers enabled
- Run: `& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchWindowsEngine`

**Buildx not found**
- Enable Docker Buildx: `docker buildx create --use`

**Push permission denied**
- Login to ACR: `az acr login --name appmonitoring`
