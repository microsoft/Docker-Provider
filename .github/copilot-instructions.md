# Repository Instructions

## Summary

Docker-Provider is the Azure Monitor Container Insights agent. It collects container logs, metrics, and inventory from Kubernetes clusters (AKS, Arc-enabled, hybrid) and forwards telemetry to Azure Monitor / Log Analytics. Primary languages are **Ruby** (Fluentd input/filter plugins), **Go** (Fluent Bit output plugin + Kubernetes API clients), **Bash** (Linux build/deployment scripts), **PowerShell** (Windows build/test), and **Python** (E2E tests). Runs as a DaemonSet/ReplicaSet on Linux (Mariner) and Windows (Server Core).

## General Guidelines

1. Follow the existing code conventions per language — see `.github/instructions/` for language-specific rules.
2. Break complex tasks into smaller, focused prompts (one module, one function, one test at a time).
3. Be specific: reference actual file paths, function names, and patterns from this repo.
4. Always validate AI-generated code: review for correctness, run tests, and check CI.
5. If newer commits make prior changes unnecessary, revert them.
6. Use the explore → plan → code → commit workflow for multi-file changes (see `AGENTS.md`).
7. Open relevant files before prompting — Copilot uses open files as context.

## Build Instructions

```bash
# Linux Build (requires build-essential, Go 1.23.8+)
cd build/linux && make

# Unit Tests
./test/unit-tests/test_main.sh          # Bash tests
./test/unit-tests/run_go_tests.sh       # Go tests (Go 1.23.8)
./test/unit-tests/run_ruby_tests.sh     # Ruby tests (Fluentd 1.14.2)
./test/unit-tests/test_main.ps1         # PowerShell tests (Pester 5.3.3)

# Docker Image Build
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t <tag>
```

## Custom Agents

| Agent | Triggers | Description |
|-------|----------|-------------|
| @CodeReviewer | review PR, review code | Code review against repo conventions, STRIDE security, telemetry gaps |
| @SecurityReviewer | security review, threat model | Deep STRIDE security analysis, attack surface review |
| @ThreatModelAnalyst | threat model analysis | Generate persistent threat model artifacts with Mermaid diagrams |
| @DocumentWriter | write docs, update README | Documentation following repo conventions |
| @prd | create PRD, write requirements | Generate Product Requirements Documents |

## Task-Specific Skills

| Skill | Triggers | Description |
|-------|----------|-------------|
| security-review | security review, STRIDE analysis, credential scan | STRIDE-based security review with credential detection |
| telemetry-authoring | add telemetry, add metrics, instrument code | Add telemetry following existing ApplicationInsights patterns |
| fix-critical-vulnerabilities | fix CVE, trivy fix, patch vulnerability | Fix critical/high CVEs using repo scanning tools |
| dependency-update | update dependency, bump package | Safe dependency updates (go.mod, gems) with testing |
| bug-fix | fix bug, resolve issue, hotfix | Structured bug fix with regression test |
| feature-development | add feature, implement, new plugin | New feature scaffolding with tests |
| test-authoring | add test, write test | Create tests following multi-framework conventions |
| ci-cd-pipeline | update pipeline, CI change | Modify GitHub Actions or Azure DevOps pipelines |
| infrastructure | update Helm, update Dockerfile, update Bicep | Infrastructure and deployment changes |

## Known Patterns & Gotchas

- Local computer build may be broken — see README note. CI build is the source of truth.
- Ruby plugins require Fluentd 1.14.2 gem installed for local testing.
- Go plugins use CGo (Fluent Bit plugin SDK) — requires `build-essential` on Linux.
- Windows builds use a separate `build/windows/Makefile.ps1` path.
- Helm chart is in `charts/azuremonitor-containers/` — version must be bumped in `Chart.yaml`.
- Multiple `go.mod` files exist — ensure the right one is updated for dependency changes.
- `.trivyignore` must include justification comments for any new CVE suppressions.
