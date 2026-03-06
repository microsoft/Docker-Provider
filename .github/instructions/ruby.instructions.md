---
applyTo: "**/*.rb"
description: Ruby code style and Fluentd plugin conventions for this repository.
---

# Ruby / Fluentd Plugin Conventions

- Always include `frozen_string_literal: true` at the top of every Ruby file.
- Use `require_relative` for files in the same plugin directory, `require` for gems.
- Register Fluent plugins with `Fluent::Plugin.register_filter/input/output('name', self)`.
- Use class variables (`@@`) for shared module-level state (e.g., `@@isWindows`, `@@os_type`).
- Use `ApplicationInsightsUtility` for telemetry — never instantiate a new telemetry client.
- Gate telemetry calls with `$in_unit_test` to prevent telemetry during tests.
- Use `OMS::Common` for shared utility methods (hostname, proxy configuration).
- Log errors via `@log.warn`/`@log.error` from `omslog.rb`, not `puts` or `STDOUT`.
- Handle environment variables defensively: check `.nil?` and `.empty?` before use.
- JSON is the standard data interchange format between plugins.
- Test files follow the pattern `*_test.rb` alongside source in `source/plugins/ruby/`.
