---
applyTo: "**/*.rb"
---

- Start files with `#!/usr/local/bin/ruby` shebang and `# frozen_string_literal: true`.
- Fluentd plugins subclass `Fluent::Plugin::Input`, `Fluent::Plugin::Filter`, or `Fluent::Plugin::Output`.
- Use `require_relative` for local file imports within the plugins directory.
- Use `snake_case` for method and variable names; `PascalCase` for class names.
- Log via `@log.info`, `@log.warn`, `@log.error` — these are Fluentd's built-in logger methods.
- Send telemetry through `ApplicationInsightsUtility` helper class.
- Use `KubernetesApiClient` for all Kubernetes API calls; do not use raw HTTP.
- Place test files alongside source files with `_test.rb` suffix (e.g., `in_kube_nodes_test.rb`).
- Guard test-only code paths with `$in_unit_test` global variable.
- Handle exceptions with `begin/rescue` blocks and log errors before re-raising or returning defaults.
