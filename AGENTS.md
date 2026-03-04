# AGENTS.md

## Setup Commands

```bash
# Clone and enter the repo
git clone https://github.com/microsoft/Docker-Provider.git
cd Docker-Provider

# Go unit tests require Go 1.23.8+
# Install Go if not present, then:
cd source/plugins/go/src && go mod download && cd -

# Ruby tests require Fluentd
gem install fluentd -v "1.14.2" --no-document
gem install ipaddress --no-document

# Build the Linux Go plugin (requires make, gcc, pkg-config, libssl-dev)
cd build/linux && make && cd -
```

## Code Style

### Ruby (`source/plugins/ruby/`)
- Shebang: `#!/usr/local/bin/ruby` with `# frozen_string_literal: true`
- Fluentd plugin pattern: subclass `Fluent::Plugin::Input`, `Fluent::Plugin::Filter`, or `Fluent::Plugin::Output`
- Classes use `PascalCase`, methods use `snake_case`
- Use `require_relative` for local imports
- Logging via `@log.info`, `@log.warn`, `@log.error` (Fluentd logger)
- Telemetry via `ApplicationInsightsUtility`
- Test files co-located with source: `*_test.rb` next to `*.rb`

### Go (`source/plugins/go/src/`)
- Standard Go conventions: `PascalCase` exports, `camelCase` locals
- Fluent Bit plugin interface: `FLBPluginRegister`, `FLBPluginInit`, `FLBPluginFlush`, `FLBPluginExit`
- Uses `k8s.io/client-go` for Kubernetes API access
- Tests use `testing` package and `testify/assert`
- Mock generation via `golang/mock` and `go generate`
- Environment variable gating: `GOUNITTEST=true ISTEST=true` for test mode

### Shell/Bash (`build/`, `kubernetes/`, `scripts/`)
- Use `#!/bin/bash` or `#!/bin/sh` shebang
- `set -e` at top of scripts for fail-fast behavior
- Source shared env vars from `/opt/env_vars` in container scripts
- Functions use `snake_case`

### PowerShell (`build/windows/`, `test/unit-tests/`)
- Functions use `Verb-Noun` naming (e.g., `Get-ClusterCloudEnvironment`)
- Tests use Pester 5.3.3 framework with `Describe`/`It` blocks
- Script names: `PascalCase` (e.g., `Get-McsEndpoint.ps1`)

## Testing Instructions

### Test Framework
- **Bash**: Custom test framework in `test/unit-tests/test_framework.sh`
- **Go**: `go test` with `testify` assertions
- **Ruby**: Fluentd test driver via `test/unit-tests/test_driver.rb`
- **PowerShell**: Pester 5.3.3

### Running Tests

```bash
# All Bash unit tests
chmod +x test/unit-tests/test_main.sh test/unit-tests/test_framework.sh
find test/unit-tests/test_functions -type f -name "*.sh" -exec chmod +x {} \;
find test/unit-tests/test_cases -type f -name "*.sh" -exec chmod +x {} \;
./test/unit-tests/test_main.sh

# Go unit tests
./test/unit-tests/run_go_tests.sh

# Ruby unit tests
./test/unit-tests/run_ruby_tests.sh

# PowerShell unit tests (Windows only)
./test/unit-tests/test_main.ps1
```

### Test File Locations
| Language | Test Location | Naming Convention |
|----------|---------------|-------------------|
| Go | `source/plugins/go/src/*_test.go` | `*_test.go` |
| Ruby | `source/plugins/ruby/*_test.rb` | `*_test.rb` |
| Bash | `test/unit-tests/test_cases/*.sh` | `test_*.sh` |
| PowerShell | `test/unit-tests/test_cases/*.ps1` | `Test-*.ps1` |
| Ginkgo E2E | `test/ginkgo-e2e/*/` | `*_test.go` (suite pattern) |
| Python E2E | `test/e2e/src/tests/` | `test_*.py` |

### CI Test Plan
GitHub Actions `run_unit_tests.yml` runs on PRs to `ci_dev` and `ci_prod`:
1. Linux Bash Tests → `./test/unit-tests/test_main.sh`
2. Golang Tests → `./test/unit-tests/run_go_tests.sh`
3. Ruby Tests → `./test/unit-tests/run_ruby_tests.sh`
4. Windows PowerShell Tests → `./test/unit-tests/test_main.ps1`

## Dev Environment Tips

- **Primary branches**: `ci_dev` (development), `ci_prod` (production)
- **Go modules**: The `source/plugins/go/src/go.mod` has a `replace` directive for `../input`. Always keep both modules in sync.
- **Ruby development**: Install Fluentd 1.14.2 locally. The `$in_unit_test` global is set by the test harness.
- **Container testing**: Build via `docker build -f kubernetes/linux/Dockerfile.multiarch .` — requires Go and Azure Linux base images.
- **Helm chart testing**: Charts are in `charts/azuremonitor-containers/`. Use `helm template` to validate changes.
- **Version file**: `build/version` contains `CONTAINER_BUILDVERSION_*` variables.
- **Azure Pipelines**: Production CI/CD is in `.pipelines/` (not GitHub Actions).

## PR Instructions

- **Target branches**: PRs should target `ci_dev` or `ci_prod`
- **Required checks**: Unit tests (Bash, Go, Ruby, PowerShell), PR build and Trivy scan, CodeQL, DevSkim
- **Commit messages**: Use descriptive messages. Common patterns: `fix: <description>`, feature PRs reference issue numbers
- **Code owners**: `@microsoft/docker-provider-devs` reviews all changes (see `CODEOWNERS`)
- **Stale policy**: Issues and PRs are marked stale after 7 days of inactivity and closed after 12 days
