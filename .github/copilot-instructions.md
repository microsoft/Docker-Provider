# Repository Instructions

## Summary

Docker-Provider (aka Azure Monitor Container Insights agent) is an open-source Kubernetes monitoring agent that collects container logs, metrics, inventory, and events from AKS, Arc-enabled, and on-premises Kubernetes clusters. The codebase is primarily **Ruby** (Fluentd input/filter/output plugins), **Go** (Fluent Bit output/input plugins), **Shell/Bash** (Linux scripts), and **PowerShell** (Windows scripts). It builds multi-arch Linux container images on Azure Linux (Mariner) and Windows container images, deployed via Helm charts and EV2.

## General Guidelines

1. Follow the language-specific instructions in `.github/instructions/` — they auto-activate when you open matching files.
2. Always run tests before committing: Bash (`./test/unit-tests/test_main.sh`), Go (`./test/unit-tests/run_go_tests.sh`), Ruby (`./test/unit-tests/run_ruby_tests.sh`), PowerShell (`./test/unit-tests/test_main.ps1`).
3. If newer commits make prior changes unnecessary, revert them — do not leave dead code.
4. Never hardcode secrets or instrumentation keys. Use environment variables (e.g., `APPLICATIONINSIGHTS_AUTH`, `AKS_RESOURCE_ID`).
5. Container images use Azure Linux 3.0 distroless base — keep the dependency footprint minimal.

## Prompting Best Practices

1. Break complex tasks into smaller prompts — one plugin, one function, one test at a time.
2. Be specific: reference actual file paths like `source/plugins/ruby/in_kube_nodes.rb` or `source/plugins/go/src/oms.go`.
3. Provide example inputs/outputs when asking for implementations (e.g., sample Kubernetes API responses).
4. Open relevant source files before prompting — Copilot uses open files as context.
5. Start new chat sessions for unrelated tasks to avoid context pollution.
6. Use the explore → plan → code → commit workflow for multi-file changes (see `AGENTS.md`).
7. Always validate AI-generated code: review for correctness, run tests, and check for secrets leakage.

## Build Instructions

| Task | Command |
|------|---------|
| **Build Go plugins** | `cd source/plugins/go/src && make fbplugin` |
| **Build full Linux agent** | `cd build/linux && make` |
| **Run Go unit tests** | `./test/unit-tests/run_go_tests.sh` |
| **Run Ruby unit tests** | `./test/unit-tests/run_ruby_tests.sh` (requires `fluentd` gem v1.14.2) |
| **Run Bash unit tests** | `./test/unit-tests/test_main.sh` |
| **Run PowerShell tests** | `./test/unit-tests/test_main.ps1` (requires Pester 5.3.3) |
| **Build Linux container** | `docker build -f kubernetes/linux/Dockerfile.multiarch .` |
| **Build Windows container** | `docker build -f kubernetes/windows/Dockerfile .` |

## Task-Specific Skills

| Skill | Triggers | Description |
|-------|----------|-------------|
| `security-review` | security review, STRIDE analysis, credential leak check | STRIDE-based security review with credential scanning |
| `telemetry-authoring` | add telemetry, add metrics, instrument code | Add telemetry following existing ApplicationInsights patterns |
| `fix-critical-vulnerabilities` | fix CVE, trivy fix, patch vulnerability | Identify and fix critical/high CVEs using Trivy |
| `dependency-update` | update dependency, bump package, upgrade library | Safe dependency updates across Go modules and gems |
| `bug-fix` | fix bug, resolve issue, hotfix | Structured bug fix workflow with regression tests |
| `feature-development` | add feature, implement, new plugin | New feature development with proper test coverage |
| `ci-cd-pipeline` | update pipeline, fix CI, modify workflow | CI/CD pipeline changes for GitHub Actions and Azure Pipelines |
| `infrastructure` | update Dockerfile, modify Helm chart, update deployment | Infrastructure and deployment configuration changes |

## Known Patterns & Gotchas

- Go tests require `GOUNITTEST=true ISTEST=true` environment variables.
- Ruby tests need the `fluentd` gem v1.14.2 and `ipaddress` gem installed.
- The Go output plugin is a C-shared library (`.so`) built with `buildmode=c-shared`.
- Helm charts live in `charts/` with three variants: standard, prod-clusters, and Geneva.
- EV2 deployment configs are in `deployment/` with multiple service group roots.
- The `ci_prod` branch is the default/production branch — not `main`.
- Windows and Linux containers are separate builds with different Dockerfiles.
- Trivy is used for vulnerability scanning — `.trivyignore` tracks accepted CVEs.
