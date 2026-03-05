---
applyTo: "**/*.rb"
description: Ruby coding conventions for Fluentd plugins in the Azure Monitor container monitoring agent.
---

# Ruby Code Guidelines

1. Always include `# frozen_string_literal: true` as the second line (after shebang).
2. Use `require_relative` for local file dependencies within `source/plugins/ruby/`, use `require` for gem dependencies.
3. Fluentd plugin naming: `in_<name>.rb` (input), `out_<name>.rb` (output), `filter_<name>.rb` (filter). Register with `Fluent::Plugin.register_input/output/filter`.
4. Use class variables (`@@`) for module-level configuration constants (env var names, mount paths, tags).
5. Telemetry: use `ApplicationInsightsUtility.sendMetricTelemetry` / `sendCustomEvent` — never import the App Insights SDK directly.
6. Logging: use `$log.info/warn/error` for standard logging, `OMS::Log.warn_once` / `error_once` for deduplication.
7. Environment variable access: always use `ENV["VAR_NAME"]` with nil checks before use.
8. Constructor injection pattern: plugins accept test doubles via constructor params (e.g., `kubernetesApiClient`, `applicationInsightsUtility`) defaulting to real implementations.
9. Test guard: check `$in_unit_test` before performing telemetry or network operations.
10. Use `begin/rescue => e` for error handling — log the exception message and class.
