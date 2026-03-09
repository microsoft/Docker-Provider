# Docker-Provider — Project Prompt

## Tech Stack
- **Go 1.23+** — Fluent Bit output/input plugins for data routing, telemetry, container inventory
- **Ruby** — Fluentd input/filter/output plugins for Kubernetes API scraping, cAdvisor metrics, MDM
- **Shell/Bash** — Linux build system, installer scripts, container setup
- **PowerShell** — Windows build system, agent setup, Pester unit tests
- **Python** — E2E test framework (pytest)
- **Docker** — Container images (Azure Linux/Mariner 3.0 for Linux, Windows Server Core)
- **Kubernetes** — DaemonSet deployment, Helm charts, K8s API integration
- **Terraform/Bicep** — Infrastructure-as-code for onboarding and deployment
- **Azure Pipelines + GitHub Actions** — CI/CD (build, scan, test, release)

## Architecture
Azure Monitor for Containers agent runs as a Kubernetes DaemonSet collecting:
- **Container logs** via Fluent Bit (Go plugins) → ODS/MDSD/AMACore
- **Kubernetes inventory** via Fluentd (Ruby plugins) → ODS
- **Performance metrics** via cAdvisor + Telegraf → MDM
- **Network flow logs** via Retina integration → MDSD

Data pipeline: Fluent Bit/Fluentd → Go/Ruby plugins → ODS/MDSD endpoints → Azure Monitor backend

## Environment Variables
- `CONTROLLER_TYPE` — Agent controller type (DaemonSet, ReplicaSet)
- `CONTAINER_RUNTIME` — Container runtime (docker, containerd)
- `ISTEST` — Test mode flag
- `TELEMETRY_APPLICATIONINSIGHTS_KEY` — App Insights instrumentation key
- `DOMAIN` — Azure cloud domain (opinsights.azure.com, etc.)
- `customRegion` / `customResourceId` — Custom cluster identification
- `AKSREGION` — AKS cluster region
- `CLUSTER` — Cluster name for telemetry dimensions
- `NODE_IP` — Node IP address
- `HOSTNAME` — Node hostname

## Conventions
- Commit messages: freeform descriptive with `(#PR_NUMBER)` suffix
- Branch naming: `<alias>/<feature-description>`
- Release versioning: `3.1.x` semver-like pattern
- Release cadence: every 2-4 weeks
- PR targets: `ci_dev` (development) or `ci_prod` (production)
- Trivy scanning mandatory on all container images
- CodeQL and DevSkim security analysis on all PRs

## Key Entry Points
- `source/plugins/go/src/out_oms.go` — Main Fluent Bit output plugin entry
- `source/plugins/go/input/containerinventory/` — Container inventory input plugin
- `source/plugins/go/input/perf/` — Performance metrics input plugin
- `kubernetes/linux/setup.sh` — Linux container startup script
- `kubernetes/windows/main.ps1` — Windows container entry point
- `build/linux/Makefile` — Linux build entry point
