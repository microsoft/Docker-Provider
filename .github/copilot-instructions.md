# Repository Instructions

## Summary
Azure Monitor for Containers (Docker-Provider) is a multi-language monitoring agent that collects container logs, metrics, and inventory data from Kubernetes clusters (AKS, Arc-enabled, ARO). Primary languages: Go (~17%), Ruby (~38%), Shell (~21%), PowerShell (~12%), Python (tests). Built with Fluent Bit (Go output plugin), Fluentd (Ruby input/filter plugins), and Telegraf. Deployed as a DaemonSet via Docker containers on Linux (Azure Linux/Mariner) and Windows (Server Core). Requires Go 1.23+, Ruby with Fluentd 1.14, and Docker for builds.

## General Guidelines
1. **Build:** Run `cd build/linux && make` for Linux, `cd build/windows && .\Makefile.ps1` for Windows.
2. **Test:** Run `./test/unit-tests/test_main.sh` (Bash), `./test/unit-tests/run_go_tests.sh` (Go), `./test/unit-tests/run_ruby_tests.sh` (Ruby), `./test/unit-tests/test_main.ps1` (PowerShell/Pester).
3. **Docker image:** `cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t <tag>`.
4. **Trivy scan:** All images must pass `trivy --severity CRITICAL,HIGH` with no unfixed vulnerabilities.
5. **Commit messages:** Use freeform descriptive messages with PR number suffix, e.g., `Fix endpoint name for bleu (#1496)`.
6. **Branch naming:** Use `<alias>/<feature-description>` pattern (e.g., `longw/networkflow-rename`).
7. If newer commits make prior changes unnecessary, revert them rather than leaving dead code.
8. Always validate changes against the existing CI checks: CodeQL, DevSkim, Trivy scanning, and unit tests.

## Prompting Best Practices
1. Break complex tasks into smaller, focused prompts — one plugin, one test file, one config change at a time.
2. Be specific: reference actual file paths like `source/plugins/go/src/oms.go` or `source/plugins/ruby/in_kube_events.rb`.
3. Provide examples of expected log formats, metric names, or Kubernetes resource shapes when asking for implementations.
4. Open relevant source files before prompting — the agent uses open files as context. Close unrelated files.
5. Start new chat sessions for unrelated tasks to avoid context pollution.
6. Use the explore → plan → code → commit workflow for complex changes (see `AGENTS.md`).
7. Always validate AI-generated code: review for correctness, run unit tests, check Trivy scan results.

## Architecture Overview
- **Go plugins** (`source/plugins/go/src/`): Fluent Bit output plugin — handles ODS/MDSD data routing, network flow logs, ingestion token management, telemetry.
- **Go input plugins** (`source/plugins/go/input/`): Fluent Bit input plugins — container inventory, perf metrics via Calyptia plugin framework.
- **Ruby plugins** (`source/plugins/ruby/`): Fluentd input/filter/output plugins — Kubernetes API scraping (pods, nodes, events, PV, deployments, HPA), cAdvisor metrics, MDM metric generation.
- **Shell scripts** (`build/`, `kubernetes/linux/`): Build system, container setup, agent startup.
- **PowerShell** (`kubernetes/windows/`, `build/windows/`): Windows agent build and setup.
- **Helm charts** (`charts/`): Deployment charts for AKS and Arc clusters.
- **Deployment** (`deployment/`): EV2 / Arc extension release pipelines.
- **Tests** (`test/`): Unit tests (Bash, Go, Ruby, PowerShell), E2E tests (Python/pytest), Ginkgo integration tests.

## Custom Agents
| Agent | Triggers | Description |
|-------|----------|-------------|
| @CodeReviewer | review PR, review code | Reviews code for quality, security, telemetry |
| @SecurityReviewer | security review, threat assessment | Deep security analysis with STRIDE |
| @ThreatModelAnalyst | threat model, security architecture | Generates STRIDE threat models |
| @DocumentWriter | write docs, update documentation | Maintains repo documentation |

## Task-Specific Skills
| Skill | Trigger | Description |
|-------|---------|-------------|
| `dependency-update` | update dependencies, bump versions | Update Go modules, Ruby gems, or system packages |
| `bug-fix` | fix bug, resolve issue | Diagnose and fix bugs with proper test coverage |
| `ci-cd-pipeline` | update pipeline, fix CI | Modify GitHub Actions or Azure Pipelines configs |
| `infrastructure` | update helm, modify deployment | Change Helm charts, Bicep, Terraform, or K8s manifests |
| `security-review` | security check, CVE scan | Review code for security issues using STRIDE |
| `fix-critical-vulnerabilities` | fix CVE, patch vulnerability | Patch critical/high CVEs in dependencies or base images |
| `telemetry-authoring` | add telemetry, add metrics | Instrument code with Application Insights telemetry |
| `test-authoring` | write tests, add test coverage | Create unit/integration tests following repo patterns |
| `release-management` | prepare release, update version | Prepare release notes, chart versions, and image tags |
