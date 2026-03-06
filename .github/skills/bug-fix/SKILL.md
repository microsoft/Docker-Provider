# Bug Fix

## Purpose
Diagnoses and fixes defects in the Container Insights agent, covering Fluent Bit Go plugins (input/output), Fluentd Ruby plugins, shell-based configuration scripts, and PowerShell Windows agent scripts. Ensures telemetry collection, log forwarding, and metric emission continue to function correctly on AKS and Arc-enabled Kubernetes clusters.

USE FOR: "fix bug", "resolve issue", "patch error", "crash fix", "data gap", "missing metrics", "log loss", "nil pointer", "exception in plugin", "OOMKill", "agent restart loop"
DO NOT USE FOR: Adding new telemetry sources (use feature-development), updating dependencies without a bug (use dependency-update), security vulnerability remediation (use security-patch)

## When to Use
- A GitHub issue reports incorrect, missing, or duplicated telemetry data
- Agent pods are crash-looping or OOM-killed in customer clusters
- Log Analytics workspace shows data gaps for Container Insights tables (Perf, ContainerLog, KubeEvents, etc.)
- An exception or error pattern is found in agent logs (fluent-bit, fluentd, or mdsd)
- A regression is detected after a recent release

## Inputs
- Bug report or issue number with reproduction steps
- Affected component: Go plugin (`source/plugins/go/src/` or `source/plugins/go/input/`), Ruby plugin (`source/plugins/ruby/`), shell script (`scripts/`), or PowerShell (`kubernetes/windows/`)
- Cluster environment: AKS, Arc-enabled K8s, Windows node pool, Linux node pool
- Agent version exhibiting the bug (from `ReleaseNotes.md`)

## Outputs
- Code fix in the affected source files
- Unit test covering the bug scenario (regression test)
- Passing CI pipeline (pr-checker.yml, run_unit_tests.yml, codeql-analysis.yml)
- Updated `ReleaseNotes.md` entry documenting the fix (if shipping in next release)

## Steps
1. Reproduce the issue locally or identify the root cause from logs and stack traces
2. Locate the affected source file(s):
   - Go output plugins: `source/plugins/go/src/` (e.g., OMI, ADX, MDSD output)
   - Go input plugins: `source/plugins/go/input/` (e.g., container log input)
   - Ruby Fluentd plugins: `source/plugins/ruby/` (e.g., `in_kube_events.rb`, `in_kube_podinventory.rb`, `KubernetesApiClient.rb`, `out_mdm.rb`)
   - Configuration/startup scripts: `scripts/`, `kubernetes/linux/`, `kubernetes/windows/`
3. Implement the fix with minimal blast radius — change only what is necessary
4. Add or update unit tests:
   - Go tests: add test cases alongside the fixed code, run with `test/unit-tests/run_go_tests.sh`
   - Ruby tests: add test cases in `test/unit-tests/`, run with `test/unit-tests/run_ruby_tests.sh`
   - Shell tests: use `test/unit-tests/test_main.sh`
   - PowerShell tests: use `test/unit-tests/test_main.ps1`
5. Build the agent image: `make` in `build/linux/Makefile` for Linux, verify `kubernetes/windows/Dockerfile` for Windows
6. Run the full unit test suite to check for regressions
7. If the fix affects Helm-deployed configuration, validate chart templates in `charts/azuremonitor-containers/` render correctly
8. Update `ReleaseNotes.md` with a concise description of the fix

## Validation
- Regression test fails before the fix and passes after
- `bash test/unit-tests/run_go_tests.sh` passes
- `bash test/unit-tests/run_ruby_tests.sh` passes
- `bash test/unit-tests/test_main.sh` passes
- `pwsh test/unit-tests/test_main.ps1` passes (if Windows code changed)
- PR checks green: pr-checker.yml, run_unit_tests.yml, codeql-analysis.yml, devskim.yml
- No new Trivy findings introduced

## Risks and Guardrails
- **Blast radius**: Bug fixes should be surgical; avoid refactoring unrelated code in the same PR
- **Cross-platform impact**: A fix in shared Ruby/Go code may affect both Linux and Windows agents — test both paths
- **Data loss prevention**: Changes to log forwarding or metric emission plugins must not silently drop data; add error handling that logs failures
- **Helm chart consistency**: If default values change in `charts/*/values.yaml`, ensure existing deployments are not broken by the update
- **Backward compatibility**: Fixes must work with the Kubernetes API versions supported by the current agent (check `KubernetesApiClient.rb`)
- **Constants and configuration**: Changes to `source/plugins/ruby/constants.rb` affect many plugins; review all dependents before modifying

## Examples from This Repo
- Ruby plugin fixes often involve nil-check guards in Kubernetes API response parsing (`KubernetesApiClient.rb`)
- Go plugin fixes frequently address panic recovery, connection retry logic, or data serialization issues
- Shell script fixes typically handle edge cases in environment variable parsing or missing configuration files
- Bug fix commits usually include both the fix and a corresponding unit test addition
