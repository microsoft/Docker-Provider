# Windows Nano Server 2025 - Azure Monitor Agent

This directory contains the Windows Nano Server 2025 implementation of the Azure Monitor Agent, designed to be a lightweight alternative to the Windows Server Core version.

## Overview

This implementation provides:
- **Fluent Bit** for container log collection and forwarding
- **Telegraf** for Prometheus metrics scraping
- **PowerShell Core** for orchestration and configuration management
- **Minimal footprint** using Windows Nano Server 2025 as base image

## Architecture

```
Windows Nano Server 2025
├── PowerShell Core 7.3.4 (orchestration)
├── Fluent Bit 4.0.1 (container logs)
├── Telegraf 1.24.2 (Prometheus metrics)
└── Basic configuration files
```

## Files Description

### Installation Scripts
- **`install-fluent-bit.ps1`** - Downloads and installs Fluent Bit binary
- **`install-telegraf.ps1`** - Downloads and installs Telegraf binary
- **`test-components.ps1`** - Verifies component installations
- **`main.ps1`** - Main orchestration script that starts and monitors both services

### Build Scripts
- **`build.ps1`** - Advanced PowerShell build script with options and error handling
- **`build.bat`** - Simple batch file for easy double-click building

### Configuration Files
- **`telegraf-basic.conf`** - Basic Telegraf configuration for metrics collection
- **`Dockerfile`** - Multi-stage build configuration for Nano Server

## Current Status

### ✅ Implemented
- [x] Windows Nano Server 2025 base image
- [x] PowerShell Core 7.3.4 installation
- [x] Fluent Bit 4.0.1 installation and basic setup
- [x] Telegraf 1.24.2 installation and basic configuration
- [x] Component verification testing
- [x] Basic directory structure creation
- [x] Service orchestration script (main.ps1) that starts and monitors both Fluent Bit and Telegraf

### 🚧 Future Enhancements
- [ ] Go-based TOML configuration parsers (to replace Ruby parsers)
- [ ] Windows Azure Monitor Agent integration
- [ ] Certificate generation and authentication
- [ ] Geneva logs integration
- [ ] Multi-tenancy support
- [ ] AAD MSI authentication support

## Building the Image

### Option 1: Using Build Scripts (Recommended for Local Development)

**PowerShell Script (Advanced):**
```powershell
# Basic build
.\build.ps1

# Custom image name and tag
.\build.ps1 -ImageName "my-azure-monitor" -Tag "v1.0"

# Build without cache (for clean build)
.\build.ps1 -NoBuildCache

# Verbose output for troubleshooting
.\build.ps1 -Verbose
```

**Batch File (Simple):**
```batch
# Double-click build.bat or run from command prompt
build.bat
```

### Option 2: Direct Docker Command

```bash
# Build the Windows Nano Server image
docker build -t azure-monitor-nano:latest .
```

### Running the Image

```bash
# Run with both Fluent Bit and Telegraf services
docker run azure-monitor-nano:latest

# Run component tests
docker run azure-monitor-nano:latest pwsh -File C:\opt\scripts\test-components.ps1

# Interactive PowerShell session
docker run -it azure-monitor-nano:latest pwsh
```

## Key Differences from Windows Server Core Version

| Feature | Windows Server Core | Windows Nano 2025 | Status |
|---------|-------------------|------------------|--------|
| Base Image Size | ~4GB | ~100MB | ✅ Implemented |
| Ruby/FluentD | ✅ Included | ❌ Removed | ✅ Implemented |
| Custom Metrics | ✅ Supported | ❌ Deprecated | ✅ Implemented |
| Fluent Bit | ✅ Included | ✅ Included | ✅ Implemented |
| Telegraf | ✅ Included | ✅ Included | ✅ Implemented |
| TOML Parsing | Ruby-based | Go-based (planned) | 🚧 Future |
| Geneva Integration | ✅ Supported | 🚧 Planned | 🚧 Future |
| Certificate Auth | ✅ Supported | 🚧 Planned | 🚧 Future |

## Directory Structure

```
C:\
├── opt\
│   ├── fluent-bit\           # Fluent Bit installation
│   │   └── bin\
│   ├── telegraf\             # Telegraf installation  
│   │   └── bin\
│   └── scripts\              # PowerShell scripts
├── etc\
│   ├── fluent-bit\           # Fluent Bit configurations
│   └── telegraf\             # Telegraf configurations
└── PowerShell\               # PowerShell Core installation
```

## Testing

The image includes a test script that verifies:
- Component installations (Fluent Bit, Telegraf)
- Executable permissions and version checks
- Configuration file presence
- Directory structure creation

Run tests with:
```bash
docker run <image-name> pwsh -File C:\opt\scripts\test-components.ps1
```

## Next Steps

1. **TOML Configuration Parsing**: Implement Go-based parsers to replace Ruby scripts
2. **Windows AMA Integration**: Add Windows Azure Monitor Agent for Geneva support
3. **Orchestration**: Create comprehensive main.ps1 for service management
4. **Authentication**: Implement certificate generation and AAD MSI support
5. **Testing**: Expand test coverage and validation scenarios

## Benefits of Nano Server Approach

- **Reduced Attack Surface**: Minimal OS components
- **Faster Startup**: Smaller image size and fewer dependencies
- **Better Resource Efficiency**: Lower memory and CPU usage
- **Container-Native**: Designed for containerized workloads
- **Simplified Maintenance**: Fewer components to manage and update
