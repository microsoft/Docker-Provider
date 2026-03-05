# AGENTS.md

## Setup Commands

```bash
# 1. Clone the repository
git clone https://github.com/microsoft/Docker-Provider.git
cd Docker-Provider

# 2. Install Go 1.23.8+
# (use your preferred method — e.g., https://go.dev/dl/)

# 3. Install Ruby and Fluentd (for Ruby plugin tests)
gem install fluentd -v "1.14.2" --no-document
gem install ipaddress --no-document

# 4. Install PowerShell modules (for Windows tests on Linux/macOS, optional)
# Install-Module -Name Pester -RequiredVersion 5.3.3 -Force
# Install-Module -Name PSScriptAnalyzer -Force

# 5. Install build dependencies (Linux)
sudo apt-get install build-essential -y

# 6. Build
cd build/linux && make
```

## Code Style

### Go
- Package `main` for Fluent Bit plugins in `source/plugins/go/src/`
- Constants use `PascalCase` with descriptive names (e.g., `ContainerLogDataType`, `ResourceIdEnv`)
- Error handling: check `err != nil` immediately, log with `Log(message)` or `fmt.Errorf`
- Use `github.com/stretchr/testify/assert` for test assertions
- Test files: `*_test.go` alongside source (e.g., `oms_test.go`, `utils_test.go`)
- Environment variable guard: `GOUNITTEST=true` to skip telemetry in tests

### Ruby
- Use `# frozen_string_literal: true` at the top of every file
- Class variables (`@@`) for module-level config (e.g., `@@EnvApplicationInsightsKey`)
- Fluentd plugin naming: `in_<name>.rb` (input), `out_<name>.rb` (output), `filter_<name>.rb` (filter)
- Use `require_relative` for local dependencies, `require` for gems
- Logging: use `OMS::Log` for log-once patterns, `$log.info/warn/error` for standard logging
- Test files: `*_test.rb` alongside source (e.g., `in_kube_nodes_test.rb`)
- Test guard: `$in_unit_test = true`

### Shell/Bash
- Use `set -e` for error propagation
- Use `#!/bin/bash` shebang
- Variable references should be quoted: `"$VAR"`
- Functions use snake_case naming

### PowerShell
- Use `param()` blocks for script parameters
- Follow verb-noun naming for functions (e.g., `Get-McsEndpoint`, `Test-IsCanaryRegion`)
- Use Pester 5.3.3 for testing with `Describe`/`It` blocks

## Testing Instructions

### Go Unit Tests
```bash
cd source/plugins/go/src
GOUNITTEST=true ISTEST=true go test .
```
Or via the runner script:
```bash
./test/unit-tests/run_go_tests.sh
```

### Ruby Unit Tests
```bash
./test/unit-tests/run_ruby_tests.sh
```
Test driver at `test/unit-tests/test_driver.rb` auto-discovers `*_test.rb` files in `source/plugins/ruby/` and `build/linux/installer/scripts/`.

### Bash Unit Tests
```bash
./test/unit-tests/test_main.sh
```
Custom test framework in `test/unit-tests/test_framework.sh` with test cases in `test/unit-tests/test_cases/`.

### PowerShell Unit Tests
```powershell
./test/unit-tests/test_main.ps1
```
Uses Pester 5.3.3. Test cases in `test/unit-tests/test_cases/Test-*.ps1`.

### Ginkgo E2E Tests
```bash
cd test/ginkgo-e2e/<suite>  # querylogs, containerstatus, livenessprobe
go test -v ./...
```

### CI Test Pipeline
All four test suites (Bash, Go, Ruby, PowerShell) run on every PR via `.github/workflows/run_unit_tests.yml`.

## Dev Environment Tips

- The project builds Go Fluent Bit plugins as shared libraries (`.so` files)
- Ruby plugins run inside Fluentd — install fluentd gem locally to test
- Container builds use multi-stage Dockerfiles: Go build stage → Azure Linux runtime stage
- Key environment variables for local testing:
  - `GOUNITTEST=true` — disables telemetry in Go tests
  - `ISTEST=true` — enables test mode
  - `$in_unit_test` (Ruby) — set in test_driver.rb to disable telemetry
- Helm charts in `charts/` — use `helm template` to validate changes locally

## PR Instructions

- Target branches: `ci_dev` (development) or `ci_prod` (production)
- PR builds automatically trigger Trivy vulnerability scanning with CRITICAL/HIGH severity checks
- CI runs CodeQL (Go, Python, Ruby) and DevSkim security scanning
- Commit messages: use descriptive messages with PR number reference (e.g., `Fix liveness probe issue (#1530)`)
- Version bumps go in `build/version`, Helm chart versions in `charts/*/Chart.yaml`
- Release notes are maintained in `ReleaseNotes.md`
