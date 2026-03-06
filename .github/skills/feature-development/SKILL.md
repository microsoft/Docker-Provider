# Feature Development

## Purpose
Implements new telemetry collection capabilities, monitoring features, and agent functionality for Azure Monitor Container Insights. This includes new Fluent Bit input/output Go plugins, new Fluentd Ruby plugins, new Kubernetes resource inventory collectors, and new metric/log pipelines.

USE FOR: "add new feature", "new telemetry source", "new plugin", "new metric", "new inventory type", "support new resource", "add collection for", "new data table", "new ConfigMap option"
DO NOT USE FOR: Fixing broken existing features (use bug-fix), updating existing dependency versions (use dependency-update), CI/CD workflow changes (use ci-cd-pipeline)

## When to Use
- Product requirement to collect a new Kubernetes resource type (e.g., new inventory, new event type)
- Adding a new output destination for telemetry data (e.g., new ADX table, new LA table)
- Introducing a new agent configuration option via ConfigMap or Helm values
- Adding new prometheus scraping targets or metric pipelines
- Implementing new container log filtering or transformation capabilities

## Inputs
- Feature specification or GitHub issue describing the new capability
- Target Kubernetes resource types or data sources
- Output schema (Log Analytics table schema, ADX schema, or MDM metric dimensions)
- Configuration surface (ConfigMap keys, Helm values, environment variables)
- Whether the feature applies to Linux, Windows, or both

## Outputs
- New or modified plugin source files (Go and/or Ruby)
- Updated configuration templates and default values
- Helm chart updates (`charts/azuremonitor-containers/`, `charts/azuremonitor-containers-geneva/`)
- Unit tests covering the new functionality
- Updated `ReleaseNotes.md` documenting the new feature
- Documentation updates if user-facing configuration changes

## Steps
1. Design the data flow: identify source (Kubernetes API, container runtime, node metrics) → processing (Ruby/Go plugin) → output (Log Analytics, ADX, MDM)
2. If adding a new Go plugin:
   - Create source files under `source/plugins/go/src/` (output) or `source/plugins/go/input/` (input)
   - Register the plugin in the appropriate plugin registry
   - Update `source/plugins/go/src/Makefile` if new build targets are needed
   - Add any new Go dependencies with `go get` and `go mod tidy`
3. If adding a new Ruby plugin:
   - Create the plugin file in `source/plugins/ruby/` following the `in_*.rb` or `out_*.rb` naming convention
   - Add constants to `source/plugins/ruby/constants.rb`
   - Use `KubernetesApiClient.rb` patterns for Kubernetes API interactions
4. If the feature requires new configuration:
   - Add ConfigMap keys to the appropriate configuration scripts in `scripts/`
   - Add Helm values to `charts/azuremonitor-containers/values.yaml` and `charts/azuremonitor-containers-geneva/values.yaml`
   - Update chart templates if new environment variables or volume mounts are needed
5. Update container startup scripts:
   - Linux: scripts referenced in `kubernetes/linux/Dockerfile.multiarch`
   - Windows: PowerShell scripts in `kubernetes/windows/`
6. Write unit tests:
   - Go: test files alongside source in the appropriate module
   - Ruby: test files in `test/unit-tests/`
   - Shell/PowerShell: `test/unit-tests/test_main.sh` or `test/unit-tests/test_main.ps1`
7. Build and verify:
   - `make` in `source/plugins/go/src/Makefile` and `build/linux/Makefile`
   - Docker build with `kubernetes/linux/Dockerfile.multiarch`
8. Update `ReleaseNotes.md` with the new feature description
9. If the feature introduces a new Helm chart parameter, bump the chart version in `charts/*/Chart.yaml`

## Validation
- New plugin loads successfully in fluent-bit/fluentd configuration
- Unit tests pass for all test suites (`run_go_tests.sh`, `run_ruby_tests.sh`, `test_main.sh`)
- Docker image builds successfully for both Linux (`Dockerfile.multiarch`) and Windows (`Dockerfile`) if applicable
- Helm template rendering produces valid Kubernetes manifests: `helm template charts/azuremonitor-containers/`
- PR CI checks pass: pr-checker.yml, run_unit_tests.yml, codeql-analysis.yml
- No new Trivy HIGH/CRITICAL vulnerabilities from added dependencies
- Feature can be enabled/disabled via ConfigMap without agent restart issues

## Risks and Guardrails
- **Resource consumption**: New collection features increase agent CPU/memory footprint; profile resource usage before merging
- **API rate limiting**: New Kubernetes API calls must respect watch/list patterns and caching to avoid API server throttling
- **Data volume**: New log or metric sources can significantly increase data ingestion costs; features should be configurable and off by default if high-volume
- **Schema compatibility**: New fields in output plugins must be backward-compatible with existing Log Analytics table schemas
- **Multi-platform**: Features must work on both Linux and Windows node pools unless explicitly scoped; test both Dockerfiles
- **Helm backward compatibility**: New Helm values must have sensible defaults so existing `helm upgrade` commands continue to work
- **Geneva vs public charts**: Features may need to be added to both `azuremonitor-containers` and `azuremonitor-containers-geneva` chart variants

## Examples from This Repo
- New inventory collectors follow the pattern of existing `in_kube_podinventory.rb`, `in_kube_events.rb` plugins
- Go input plugins are registered in the Fluent Bit input plugin framework under `source/plugins/go/input/`
- Feature flags are typically controlled through ConfigMap values parsed in Ruby via `constants.rb`
- New Helm chart parameters are added to both `values.yaml` and documented in the chart's `README.md`
