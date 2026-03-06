---
applyTo: "**/*.rb"
description: Code style, design patterns, and best practices for Ruby code in the Docker-Provider agent.
---

# Ruby Conventions — Docker-Provider

- Always add `# frozen_string_literal: true` as the second line (after shebang if present).
- Use `require_relative` for local file imports within `source/plugins/ruby/`.
- Fluent Bit plugins must inherit from the appropriate base class (`Fluent::Plugin::Input`, `Filter`, or `Output`) and call `register_input`/`register_filter`/`register_output`.
- Use `ApplicationInsightsUtility.sendExceptionTelemetry` for error reporting — never use `puts` or `$stderr` for production error output.
- Guard telemetry calls with `$in_unit_test` check — do not emit telemetry during unit test execution.
- Use `@@` class variables for plugin-level state and `@` instance variables for per-instance state.
- Environment variables are accessed via `ENV["VAR_NAME"]` — always check for nil/empty before use.
- Use `begin/rescue => e` for error handling; log errors with `@log.warn` or `@log.error` (Fluent logger).
- Time handling: Use `DateTime.now.to_time.to_i` for epoch timestamps, `Time.now.utc.iso8601` for ISO format.
- JSON serialization: Use `JSON.parse` / `JSON.generate` from the standard library.
- Do not introduce new gems without updating the build process in `kubernetes/linux/setup.sh`.
