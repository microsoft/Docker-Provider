# Repository Instructions

## Summary
Docker-Provider (aka Container Insights agent / ama-logs) is the Azure Monitor agent for Kubernetes container monitoring. It collects container logs, metrics, and inventory from AKS and Arc-enabled clusters. Primary languages are Ruby (~24%), Go (~11%), Shell (~13%), and PowerShell (~8%), running as Fluent Bit/Fluentd plugins inside a containerized agent deployed via DaemonSet and ReplicaSet on Linux and Windows nodes.

## General Guidelines

1. All code changes must pass CI: CodeQL, DevSkim, Trivy container scan, and unit tests (Bash, Go, Ruby, PowerShell).
2. Never hardcode secrets or instrumentation keys — use environment variables (`APPLICATIONINSIGHTS_AUTH`, `APPLICATIONINSIGHTS_ENDPOINT`).
3. Ruby plugins live in `source/plugins/ruby/`, Go plugins in `source/plugins/go/`. Follow existing patterns in each directory.
4. Gate telemetry calls behind `$in_unit_test` (Ruby) or `GOUNITTEST` (Go) checks to avoid telemetry in tests.
5. Container images are built from `kubernetes/linux/Dockerfile.multiarch` (Linux) and `kubernetes/windows/Dockerfile` (Windows).
6. Helm charts in `charts/` must be kept in sync with Kubernetes manifest changes in `kubernetes/`.
7. If newer commits make prior changes unnecessary, revert them.

## Custom Agents

| Agent | Triggers | Description |
|-------|----------|-------------|
| @CodeReviewer | review code, review PR | Review code for correctness, style, security, and telemetry |
| @SecurityReviewer | security review, threat model | Deep STRIDE security analysis and attack surface review |
| @DocumentWriter | write docs, update README | Create and maintain documentation |
| @prd | create PRD, write requirements | Generate Product Requirements Documents |

## Task-Specific Skills

| Skill | Triggers | Description |
|-------|----------|-------------|
| `security-review` | security review, STRIDE analysis, credential leak check | STRIDE-based security review |
| `telemetry-authoring` | add telemetry, add metrics, instrument code | Add telemetry following existing patterns |
| `fix-critical-vulnerabilities` | fix CVE, trivy fix, patch vulnerability | Fix critical/high vulnerabilities |
| `dependency-update` | update dependency, bump package | Update Go modules and Ruby gems |
| `bug-fix` | fix bug, resolve issue, hotfix | Structured bug fix workflow |
| `feature-development` | add feature, implement, new plugin | New feature development |
| `test-authoring` | add test, write test | Create tests following repo conventions |
| `ci-cd-pipeline` | update pipeline, modify workflow | CI/CD pipeline changes |
| `infrastructure` | update Dockerfile, modify Helm chart | Infrastructure and deployment changes |
| `code-refactoring` | refactor, restructure, rename | Code refactoring workflow |
| `security-patch` | security fix, CVE patch | Security-related fixes |
| `documentation` | update docs, write release notes | Documentation updates |

## Build Instructions

```bash
# Prerequisites: Go 1.23+, Ruby 3.3+, make, Docker

# Build Go Fluent Bit output plugin
cd source/plugins/go/src && make fbplugin

# Build Go Fluent Bit input plugins
cd source/plugins/go/input/containerinventory && make containerinventory
cd source/plugins/go/input/perf && make perf

# Build full Linux package (requires dpkg/rpm tools)
cd build/linux && make all

# Run unit tests
./test/unit-tests/test_main.sh           # Bash tests
./test/unit-tests/run_go_tests.sh        # Go tests
./test/unit-tests/run_ruby_tests.sh      # Ruby tests (requires fluentd gem)
./test/unit-tests/test_main.ps1          # PowerShell tests (Windows)

# Build Docker image
cd kubernetes/linux && docker build -f Dockerfile.multiarch .
```

## Known Patterns & Gotchas

- The `ci_prod` branch is the default integration branch (HEAD). PRs target `ci_dev` or `ci_prod`.
- Ruby gems must be installed before running Ruby tests: `gem install fluentd -v "1.14.2" && gem install ipaddress`.
- Go plugins are built as C-shared libraries (`.so` files) for Fluent Bit.
- ARM64 builds use cross-compilation with `aarch64-linux-gnu-gcc`.
- The `.trivyignore` file contains temporarily ignored CVEs — always check before adding new entries.
- Azure Pipelines in `.pipelines/` handle production builds and deployments; GitHub Actions handle PR checks.
