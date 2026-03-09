---
applyTo: "build/**/*,kubernetes/**/*,charts/**/*"
---
# Build & Container Instructions

## Linux Build
- Entry point: `build/linux/Makefile`
- Compiles Go plugins, packages Ruby plugins, builds installer
- Run: `cd build/linux && make` (optionally `make arch=arm64` for ARM)
- Requires: Go 1.23+, build-essential, Make

## Windows Build
- Entry point: `build/windows/Makefile.ps1`
- Compiles Go plugins and .NET certificate generator
- Requires: Go, .NET Core SDK, gcc for Windows

## Docker Images
- **Linux:** `kubernetes/linux/Dockerfile.multiarch` — multi-arch (amd64/arm64), based on Azure Linux/Mariner 3.0
- **Windows:** `kubernetes/windows/Dockerfile` — based on Windows Server Core (ltsc2019/ltsc2022)
- Build arg: `IMAGE_TAG` for telemetry tagging, `WINDOWS_VERSION` for Windows base

## Container Setup
- `kubernetes/linux/setup.sh` — Main Linux container entry point (agent config, cert setup, service startup)
- `kubernetes/windows/setup.ps1` / `main.ps1` — Windows container entry point
- Config directory: `/etc/amalogsagent/` (Linux), `c:/etc/amalogsagent/` (Windows)

## Helm Charts
- `charts/azuremonitor-containers/` — Standard deployment chart
- `charts/azuremonitor-containerinsights-for-prod-clusters/` — Production cluster chart
- `charts/azuremonitor-containers-geneva/` — Geneva integration chart

## Security
- All images must pass Trivy scan: `trivy image --severity CRITICAL,HIGH --exit-code 1 --ignore-unfixed`
- CVE exceptions tracked in `.trivyignore` (use sparingly, with comment explaining why)
- No secrets in Dockerfiles — use environment variables or mounted secrets
