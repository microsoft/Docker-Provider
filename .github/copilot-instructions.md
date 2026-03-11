# Copilot Instructions — Docker-Provider

## Summary

Azure Monitor for Containers — a Fluent-Bit plugin-based K8s monitoring agent. Runs as DaemonSet + Deployment collecting logs, metrics, and inventory. Go/Ruby plugins route data to Log Analytics, ADX, and Geneva/MDSD. Languages: Ruby 43%, Shell 24%, Go 19%, PowerShell 3%, Python 2%.

## Guidelines

- **Go:** `camelCase` funcs, `UPPER_CASE` consts, always `if err != nil`. Output plugin is `c-shared`.
- **Ruby:** `snake_case` methods, `PascalCase` classes, `begin/rescue` with AppInsights telemetry.
- **Shell:** `set -e`, `UPPER_CASE` vars, quote all variables.
- **PRs:** Target `ci_prod`. Freeform commits with PR refs (`#XXXX`). Run all tests first.

## Prompting Tips

1. Break tasks by language (Go vs Ruby vs Shell).
2. Specify data type constant (e.g., `CONTAINER_LOG_BLOB`).
3. State deployment context: DaemonSet vs ReplicaSet.
4. Validate msgpack serialization and MDSD socket writes.
5. Follow existing patterns: `in_kube_nodes.rb` for Ruby, `out_oms.go` for Go.

## Build & Test

```bash
cd build/linux && make                        # Linux build
docker build -f kubernetes/linux/Dockerfile.multiarch -t ciprod:dev .
./test/unit-tests/test_main.sh                # Bash tests
./test/unit-tests/run_go_tests.sh             # Go tests
./test/unit-tests/run_ruby_tests.sh           # Ruby tests
./test/unit-tests/test_main.ps1               # PowerShell (Windows)
pytest test/e2e/                              # E2E tests
ginkgo ./test/ginkgo-e2e/*                    # Ginkgo E2E
```

## Skills

| Skill | Key Files |
|---|---|
| `dependency-update` | `go.mod` files, `Dockerfile.multiarch` |
| `bug-fix` | `source/plugins/go/src/`, `source/plugins/ruby/` |
| `test-authoring` | `test/unit-tests/`, `test/e2e/`, `test/ginkgo-e2e/` |
| `feature-development` | `source/plugins/go/`, `source/plugins/ruby/` |
| `code-refactoring` | `source/plugins/` |
| `documentation` | `README.md`, `Dev Guide.md`, `ReleaseNotes.md` |
| `ci-cd-pipeline` | `.github/workflows/`, `.pipelines/` |
| `infrastructure` | `charts/`, `kubernetes/`, `deployment/` |
| `security-patch` | `Dockerfile.multiarch`, `.trivyignore` |
| `performance-optimization` | `oms.go`, Ruby plugins |
| `security-review` | `ingestion_token_utils.go`, `proxy_utils.rb` |
| `telemetry-authoring` | `telemetry.go`, `ApplicationInsightsUtility.rb` |
| `fix-critical-vulnerabilities` | `Dockerfile.multiarch`, `go.mod` |

## Gotchas

- **Multi-arch:** Dockerfile branches on `TARGETARCH`. Ruby/cmetrics install differs per arch.
- **Go c-shared:** `out_oms.go` exports C functions — never change signatures.
- **Ruby plugins:** Register with `Fluent::Plugin.register_input`. Use `$in_unit_test = true` in tests.
- **MDSD protocol:** msgpack over Unix sockets (Linux) / named pipes (Windows). Schema changes break ingestion.
- **Routing:** `PostDataHelper()` branches on `AZMON_CONTAINER_LOGS_ROUTE`, `GENEVA_LOGS_INTEGRATION`, `AAD_MSI_AUTH_MODE`.
- **Two Go modules:** `source/plugins/go/src/go.mod` + `source/plugins/go/input/go.mod`. Update both for shared changes.
