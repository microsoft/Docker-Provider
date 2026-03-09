# AGENTS.md — Docker-Provider (Azure Monitor for Containers)

## Project Overview
Azure Monitor for Containers agent collects logs, metrics, and inventory from Kubernetes clusters. It runs as a DaemonSet on Linux (Azure Linux/Mariner) and Windows (Server Core) nodes, supporting AKS, Azure Arc-enabled Kubernetes, and ARO clusters.

## Repository Structure
```
Docker-Provider/
├── source/plugins/
│   ├── go/src/          # Fluent Bit output plugin (Go) — ODS routing, MDSD, telemetry
│   ├── go/input/        # Fluent Bit input plugins (Go) — container inventory, perf
│   └── ruby/            # Fluentd plugins (Ruby) — K8s API scraping, cAdvisor, MDM
├── build/
│   ├── linux/           # Linux build system (Makefile, installer scripts)
│   ├── windows/         # Windows build system (PowerShell, .NET cert generator)
│   └── common/          # Shared installer configs and scripts
├── kubernetes/
│   ├── linux/           # Linux Dockerfile, setup.sh, agent config
│   └── windows/         # Windows Dockerfile, setup.ps1, agent config
├── charts/              # Helm charts (prod clusters, standard, geneva)
├── deployment/          # EV2 / Arc extension release pipelines
├── scripts/             # Onboarding, troubleshooting, and preview scripts
├── test/
│   ├── unit-tests/      # Bash, Go, Ruby, PowerShell unit tests
│   ├── e2e/             # Python/pytest E2E tests
│   ├── ginkgo-e2e/      # Ginkgo integration tests (Go)
│   └── scenario/        # Scenario test configs
├── alerts/              # Recommended alert ARM templates
└── Documentation/       # User and internal docs
```

## Setup Commands

### Prerequisites
- Go 1.23+ (`go version`)
- Ruby with Fluentd 1.14 (`gem install fluentd -v 1.14.2`)
- Docker for image builds
- Make and build-essential (Linux)
- .NET Core SDK (Windows certificate generator)
- PowerShell 7+ with Pester 5.3 (Windows tests)

### Build
```bash
# Linux build
cd build/linux && make

# Windows build (PowerShell)
cd build/windows && .\Makefile.ps1

# Docker image (Linux)
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t <tag>

# Docker image (Windows)
cd kubernetes/windows && docker build . --file Dockerfile -t <tag> --build-arg WINDOWS_VERSION=ltsc2019
```

## Testing Instructions

### Unit Tests
```bash
# Run all unit tests (CI command)
./test/unit-tests/test_main.sh       # Bash tests
./test/unit-tests/run_go_tests.sh    # Go tests
./test/unit-tests/run_ruby_tests.sh  # Ruby tests

# PowerShell tests (Windows)
./test/unit-tests/test_main.ps1
```

### Go Tests (standalone)
```bash
cd source/plugins/go/src && go test -v ./...
cd source/plugins/go/input && go test -v ./...
```

### E2E Tests
```bash
cd test/e2e/src && python -m pytest tests/ -v
```

### Ginkgo Integration Tests
```bash
cd test/ginkgo-e2e/livenessprobe && go test -v ./...
cd test/ginkgo-e2e/querylogs && go test -v ./...
cd test/ginkgo-e2e/containerstatus && go test -v ./...
```

### Security Scanning
```bash
# Trivy container scan (used in CI)
trivy image --severity CRITICAL,HIGH --vuln-type os,library --exit-code 1 --ignore-unfixed <image-tag>
```

## Code Style

### Go (`source/plugins/go/`)
- Package `main` for Fluent Bit plugins
- PascalCase for exported types and functions, camelCase for unexported
- Constants use PascalCase (e.g., `MaxRetries`, `ContainerNetworkLogsStreamName`)
- Structs use JSON tags with `json:"fieldName"` and msgpack tags where applicable
- Error handling: check `err != nil` immediately after each call
- Use `sync.Mutex` for concurrent access to shared state
- Logging via custom `Log()` function or `fmt.Fprintf(os.Stderr, ...)`
- Tests use `testify` assertions (`assert`, `require`)

### Ruby (`source/plugins/ruby/`)
- Fluentd plugin pattern: `class <Name> < Fluent::Input` / `Fluent::Filter` / `Fluent::Output`
- PascalCase for class names, snake_case for methods and variables
- ApplicationInsightsUtility for telemetry
- KubernetesApiClient for K8s API interactions
- File naming: `in_*.rb` (input), `filter_*.rb` (filter), `out_*.rb` (output)

### Shell (`build/`, `kubernetes/linux/`)
- Bash scripts with error checking
- Environment variables in UPPER_SNAKE_CASE
- Functions use snake_case
- Config files in `/etc/amalogsagent/` (Linux) or `c:/etc/amalogsagent/` (Windows)

### PowerShell (`build/windows/`, `kubernetes/windows/`)
- PascalCase for function names (Verb-Noun pattern)
- Pester 5.3 for unit tests with `Describe`/`Context`/`It` blocks
- PSScriptAnalyzer for linting

### YAML/Helm (`charts/`, `kubernetes/`)
- 2-space indentation
- Helm chart values follow standard Kubernetes naming

## PR Instructions
- PRs target `ci_dev` or `ci_prod` branches
- Commit messages: freeform descriptive with PR number suffix, e.g., `Fix endpoint name for bleu (#1496)`
- Branch naming: `<alias>/<feature-description>`
- CI checks must pass: CodeQL, DevSkim, Trivy scan, unit tests (Bash, Go, Ruby, PowerShell)
- Image versioning follows `3.1.x` pattern with release notes in `ReleaseNotes.md`

## Recommended AI Workflow
1. **Explore:** Understand the affected area — which plugin type (Go/Ruby), which platform (Linux/Windows), which deployment target (AKS/Arc/ARO).
2. **Plan:** Identify all files that need changes. For Go plugins, check both `src/` and `input/` modules. For Ruby plugins, check related input/filter/output files.
3. **Code:** Make changes following the code style above. Add or update unit tests.
4. **Build:** Run `cd build/linux && make` to verify compilation.
5. **Test:** Run the appropriate unit test suite. For Go: `cd source/plugins/go/src && go test ./...`. For Ruby: `./test/unit-tests/run_ruby_tests.sh`.
6. **Validate:** Build Docker image and run Trivy scan for security compliance.
7. **Commit:** Use descriptive commit message with context about what changed and why.

### Tool Selection Guidance
| Task | Recommended Tool |
|------|-----------------|
| Understand code flow | Copilot Chat (Ask mode) with relevant files open |
| Find usages of a function | grep/ripgrep across `source/plugins/` |
| Generate boilerplate plugin code | Copilot inline suggestions with existing plugin as context |
| Write unit tests | Copilot Chat (Edit mode) with source + test file open |
| Debug CI failures | Read CI workflow YAML + build logs |
| Security review | CodeQL + DevSkim + Trivy results |

## Key Configuration Files
- `kubernetes/linux/setup.sh` — Linux container agent startup and configuration
- `kubernetes/windows/setup.ps1` — Windows container agent startup
- `build/common/installer/conf/` — Fluentd/Fluent Bit configuration templates
- `charts/azuremonitor-containers/values.yaml` — Helm chart defaults
- `.github/workflows/` — CI/CD workflows (CodeQL, DevSkim, unit tests, PR build+scan)

## Important Patterns
- **Telemetry:** ApplicationInsights-Go SDK (`microsoft/ApplicationInsights-Go`) for Go plugins, `ApplicationInsightsUtility.rb` for Ruby plugins
- **Kubernetes API:** `KubernetesApiClient.rb` wraps K8s REST API calls, `k8s.io/client-go` used in Go
- **Data routing:** Fluent Bit → Go output plugin → ODS/MDSD/AMACore. Fluentd → Ruby plugins → MDM/ODS
- **Multi-tenancy:** Supported for Arc clusters with tenant-specific configuration
- **Network flow logs:** Retina integration via `network_flow_logs.go`
- **Auth modes:** IMDS tokens, Arc K8s MSI, Federated Identity Credentials (FIC), Geneva workload identity
