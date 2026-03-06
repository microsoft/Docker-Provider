---
applyTo: "**/*.rb"
description: Ruby code style and conventions for Fluentd plugins in this repository.
---

# Ruby Conventions

- Classes use `PascalCase` matching the filename (e.g., `KubernetesApiClient` in `KubernetesApiClient.rb`).
- Use `require_relative` for local imports within the `source/plugins/ruby/` tree.
- Fluentd plugins inherit from `Fluent::Input`, `Fluent::Filter`, or `Fluent::Output`.
- Use the custom `ApplicationInsightsUtility` module in `source/plugins/ruby/ApplicationInsightsUtility.rb` for telemetry.
- Handle exceptions with `begin/rescue/end`; log errors via `$log.warn` or `$log.error` (Fluentd logger).
- Use `JSON.parse` for parsing API responses; handle `JSON::ParserError` explicitly.
- Environment variables for configuration: access via `ENV["VAR_NAME"]`.
- No frozen string literal pragma is enforced — follow existing file patterns.
- Test Ruby plugins via `ruby test/unit-tests/test_driver.rb`.
