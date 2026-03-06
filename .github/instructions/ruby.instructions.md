---
applyTo: "**/*.rb"
description: Ruby coding conventions for the Azure Monitor container agent Fluentd plugins.
---

# Ruby Conventions

- Add `# frozen_string_literal: true` at the top of every Ruby file.
- Fluentd plugin naming: `in_*.rb` (input), `filter_*.rb` (filter), `out_*.rb` (output).
- Plugin classes extend `Fluent::Input`, `Fluent::Filter`, or `Fluent::Output` with `Fluent::Plugin.register_*`.
- Class names: `PascalCase` (e.g., `CAdvisorMetricsAPIClient`, `KubernetesApiClient`).
- Method names: `camelCase` (e.g., `getContainerLogs`, `parseNodeLimits`).
- Class-level variables: `@@VariableName` (e.g., `@@hostName`, `@@os_type`).
- Telemetry: use the `ApplicationInsightsUtility` singleton from `ApplicationInsightsUtility.rb`:
  - `ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)` for errors
  - `ApplicationInsightsUtility.sendCustomEvent(eventName, properties)` for events
  - `ApplicationInsightsUtility.sendMetricTelemetry(name, value, props)` for metrics
  - `ApplicationInsightsUtility.sendAPIResponseTelemetry(...)` for API response tracking
- Wrap all external calls (Kubernetes API, cAdvisor) in `begin/rescue/end` with exception telemetry.
- Logging: use `$log.warn`, `$log.info`, `$log.error` (Fluentd logger) — never `puts` or `print`.
- Environment variables: access via `ENV["VAR_NAME"]`; never hardcode keys or endpoints.
- JSON handling: use `require "json"` and `JSON.parse` / `JSON.generate`.
