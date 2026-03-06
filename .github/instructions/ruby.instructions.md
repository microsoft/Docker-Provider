---
applyTo: "**/*.rb"
description: Ruby coding conventions for Fluentd plugins in this repository.
---

# Ruby Conventions

- Always include `# frozen_string_literal: true` as the second line (after shebang).
- Use `#!/usr/local/bin/ruby` as the shebang line.
- Use `require_relative` for local imports within `source/plugins/ruby/`.
- Class variables (`@@`) are the standard pattern for singleton state in Fluentd plugins.
- Error handling: wrap operations in `begin/rescue/end` and send telemetry in `rescue` blocks using `ApplicationInsightsUtility.sendExceptionTelemetry`.
- Follow the Fluentd plugin pattern: inherit from `Fluent::Plugin::Input`, `Output`, or `Filter`.
- Use dependency injection in constructors for testability (pass `nil` defaults for production, mock objects for tests).
- Use `ENV["VAR_NAME"]` for configuration — never hardcode keys or endpoints.
- snake_case for methods and variables, PascalCase for class names.
- Test files use `_test.rb` suffix and live alongside source in `source/plugins/ruby/`.
