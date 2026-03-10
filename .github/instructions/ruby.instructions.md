---
applyTo: "**/*.rb"
description: "Ruby code style and Fluentd plugin conventions for this repository."
---

# Ruby Conventions — Docker-Provider

1. Classes use `PascalCase`, methods use `snake_case`, constants use `UPPER_CASE` or `@@camelCase` class vars.
2. All plugins inherit from `Fluent::Plugin::Input`, `Filter`, or `Output` — register with `Fluent::Plugin.register_*`.
3. Implement the full plugin lifecycle: `initialize`, `configure`, `start`, `shutdown`.
4. Use `config_param` DSL for configuration parameters — do not parse configs manually.
5. Emit records via `router.emit(tag, time, record)` — never write directly to output streams.
6. Error handling: wrap API calls in `begin/rescue/ensure` blocks; log via `$log.warn`/`$log.error`.
7. Telemetry: use `ApplicationInsightsUtility.sendCustomEvent` or `sendMetricTelemetry` — never create raw AI clients.
8. Kubernetes API calls go through `KubernetesApiClient` utility class — do not call the API directly.
9. Use `require_relative` for local dependencies, `require` for gems.
10. Environment variables: read via `ENV["VAR_NAME"]`; never hardcode cluster-specific values.
11. Include `# frozen_string_literal: true` at the top of new files.
12. Keep chunk sizes configurable (e.g., `PODS_CHUNK_SIZE` env var) for large-scale clusters.
