---
applyTo: "**/*.rb"
description: "Ruby coding conventions for Docker-Provider Fluentd plugins."
---

# Ruby Code Standards

- Always include `# frozen_string_literal: true` at the top of every file.
- Use `snake_case` for methods and variables, `PascalCase` for classes.
- Use `@@ClassVariable` for class-level shared state following existing plugin patterns.
- Error handling: wrap risky operations in `begin/rescue => e` blocks.
- Report exceptions via `ApplicationInsightsUtility.sendExceptionTelemetry(e)`.
- Log via the custom `@log` logger (OMS logger), not `puts` or `$stdout`.
- Use `require_relative` for local files, `require` for gems.
- Fluentd plugin API: inherit from `Fluent::Input`, `Fluent::Output`, or `Fluent::Filter`.
- Configuration via `ENV["VARIABLE_NAME"]` — never hardcode secrets or endpoints.
- Test files follow `*_test.rb` naming in `source/plugins/ruby/`.
- Run Ruby tests: `./test/unit-tests/run_ruby_tests.sh` (requires `fluentd` gem).
