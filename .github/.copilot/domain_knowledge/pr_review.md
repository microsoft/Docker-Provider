# PR Review Guidelines

---
## Description of PR

- **Clear explanation of what functionality is changing**: make sure the PR contains details about what functionality is changing and what all scenarios are touched by this change. Include the test scenarios

## Code Quality & Cleanliness

- **Remove unused code, comments, and test data files**: before merging. Do not commit local test data (e.g., JSON fixtures used only on a developer's machine).
- **Remove or resolve all TODO/FIXME comments**: before merge — these indicate incomplete functionality and will be flagged by code scanning.
- **Fix typos** in variable names, log messages, configuration keys, and comments (e.g., `logKubernetesiMetadataIncludeFields` → `logKubernetesMetadataIncludeFields`).
- **Simplify conditionals**: if the `if` branch returns, do not wrap the remaining code in an `else` block — it reduces nesting and improves readability.
- **Extract duplicated strings/values into variables** (e.g., usage info, URLs, paths) to avoid code duplication.
- **Reuse existing structs and types** instead of introducing new ones that duplicate existing functionality (e.g., reuse `MsgPackEntry` in Go plugins).
- **Comments should explain "why" not "what"** — the reasoning behind a design choice is more valuable than describing what the code does, which can be deduced by reading the code itself.
- **Bump version numbers when config schemas change** — increment schema/config version numbers (e.g., 1.0 → 1.1) when configuration formats or XML definitions are modified.

## Configuration & Parameters

- **Values must be parameter-driven, never hardcoded** — especially boolean feature flags. Use ARM template parameters, ConfigMap entries, or environment variables.
- **Default values for tunable settings should be configurable via ConfigMap** to support dynamic workloads without code changes (e.g., flush intervals, poll frequencies).
- **Include unit suffixes in config variable names and values** — e.g., `kube_meta_cache_ttl_secs` not `kube_meta_cache_ttl`, `1s` not `1` for time durations.
- **Validate configuration input types and ranges** — check that numeric config values are the correct type (integer) and within valid ranges (e.g., >= 0) before using them.
- **Configure fluent-bit backpressure settings** (`storage.max_chunks_up`, queue limits) appropriately for high-scale scenarios.
- **Validate configuration input types and ranges** — check that numeric config values are the correct type (integer) and within valid ranges (e.g., >= 0) before using them.
- **Configure fluent-bit backpressure settings** (`storage.max_chunks_up`, queue limits) appropriately for high-scale scenarios.
- **Remove unnecessary plugin/filter configurations** — question whether each fluent-bit filter or grep plugin is actually required.
- **Update file paths promptly** when upstream dependencies (e.g., RP, ACNS) change their output locations.
- **Auto-enable prerequisite modes** when a dependent feature is activated (e.g., enable high log scale mode automatically when network flow logs are enabled).

## Naming Consistency

- **Use consistent naming** across Go code, Ruby scripts, ARM templates, ConfigMaps, and environment variables for the same concept.
- **Exposed parameter names should be user-friendly** and descriptive (e.g., `enableRetinaNetworkFlowLogs` not `enableRetinaNetworkFlags`).

- **Telemetry property names must match their feature names** consistently.

## Cross-Platform (Linux/Windows) Consistency

- **Apply changes to both Linux and Windows** configuration files (`fluent-bit.conf`, `fluent-bit-geneva-logs_*.conf`) when a feature spans platforms.
- **Document platform-specific applicability** in release notes — explicitly state whether a fix/feature applies to Linux, Windows, or both.
- **Match filter and plugin configurations** between `build/linux/installer/conf/` and `build/windows/installer/conf/`.

## Error Handling & Resilience

- **Never skip log record ingestion** due to metadata fetch failures — log the error and continue processing the record.
- **Handle missing ConfigMap gracefully** — avoid infinite crash loops when a ConfigMap hasn't been deployed yet (e.g., guard liveness probes with a startup flag).
- **Add nil/null checks** for configuration values parsed from TOML, JSON, or environment variables.
- **Guard against undefined variables** in scripts — verify variables are defined before use, especially in PowerShell and shell scripts.
- **Handle null/unset environment variables** — validate that environment variables have expected values before using them in switch-case logic.

## Logging & Telemetry

- **Avoid overly verbose logging** — use appropriate log levels (Error for failures, Warning for anomalies). Do not log at Info level inside hot paths.
- **Add logging in else/error paths** for troubleshooting — silent failures make debugging difficult.
- **Do not dump entire file contents to stdout** — the agent's stdout is tailed and large dumps cause noise.
- **Emit telemetry in one place only** — do not duplicate telemetry emission across multiple files (e.g., both `telemetry.go` and `CAdvisorMetricsAPIClient.rb`).
- **Add dashboard tiles** to track new feature adoption when introducing new capabilities.
- **Add aliases on fluent-bit filters** (e.g., `Alias oms_kubernetes_filter`) for metrics collection and troubleshooting.

## Security

- **Use HTTPS URLs only** — HTTP URLs without TLS will be flagged by code scanning.
- **Categorize CVE entries in `.trivyignore`** by component (e.g., group telegraf vulnerabilities under a telegraf section) for tracking.
- **Understand `.trivyignore` behavior**: only CVEs listed there are excluded from the scan; `--ignore-unfixed` excludes CVEs without available patches.
- **Avoid hardcoded paths that include version numbers** — especially for dependencies not installed by the agent (e.g., PowerShell paths on Windows nodes).

## Testing & Validation

- **Test all scenarios and list them in the PR description** — reviewers need evidence of validation scope.
- **Validate cross-feature interactions** — e.g., confirm metadata filtering works with multi-line log mode enabled.
- **Validate multi-node-pool and multi-cluster scenarios** when changes affect node-level aggregation or rollup logic.
- **Respect Azure resource naming character limits** (typically 64 chars) — avoid appending unnecessary suffixes.
- **Check complications due to mixed casing of resource or resource group names.**
- Check complications due to mixed casing of resource or resource groups names
- **Respect Azure resource naming character limits** 
- (typically 64 chars) — avoid appending unnecessary suffixes. 
- Check complications due to mixed casing of resource or resourcegroups names
- **Document resource dependencies** clearly (e.g., DCR depends on DCE for private link; AMPLS links to DCE but not DCR).
- **Follow up with separate PRs** for additional onboarding methods (Bicep, Terraform, Azure Policy) when introducing ARM template changes.
- **Use ARM parameter references** in templates instead of hardcoded string values like `'Microsoft-RetinaNetworkFlowLogs'`.

## YAML & Pipeline Configuration

- **Watch for whitespace and indentation errors for YAML files** in Kubernetes YAML — misaligned fields like `initialDelaySeconds` cause deployment failures.
- **Properly escape special characters** in paths within YAML (e.g., double-backslash for Windows paths).
- **Use variables for URLs and repeated values** in Azure DevOps pipeline YAML (e.g., source ACR URLs).
- **Remove obsolete steps** from pipeline configs when merging or refactoring pipelines.

## Go Plugin Code

- **Reuse existing structs** (e.g., `MsgPackEntry`) rather than introducing duplicate types in new files.
- **Clean up unused imports and dead code** — code scanning flags these.
- **Use `SendException` for error telemetry** instead of silent failures when metadata fetch or processing fails.
- **Keep error messages concise and specific** — e.g., "Error while getting kubernetesMetadata" rather than dumping full context.

## Ruby Plugin Code

- **Add nil checks** before accessing nested configuration values parsed from TOML (e.g., `agent_settings`).
- **Use `require_relative`** explicitly for library files in subdirectories — Ruby only auto-loads from the current folder.
- **Use `StringIO`** for parsing larger payloads in streaming fashion; for small payloads, direct parsing is acceptable.

## Release Notes & Documentation

- **Use precise and accurate wording** in release notes, update vague or incorrect descriptions.
- **Scope release notes to agent/repo changes only** — do not include external RP or other team changes; coordinate with respective teams for their own documentation.
- **Note cross-platform applicability** explicitly (e.g., "Applicable for both Linux and Windows").
- **Clean up unused references** in Dockerfiles and build configs when components are deprecated.
- **Specify context for features** (e.g., "for autonomous resource endpoint", "for Geneva integration") rather than generic descriptions.
- **Add a note when a tool serves dual purposes** (e.g., liveness probe used for both liveness and readiness checks) to avoid confusion.