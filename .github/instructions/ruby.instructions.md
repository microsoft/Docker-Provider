---
applyTo: "source/plugins/ruby/**/*.rb"
description: "Ruby Fluentd plugin coding conventions for the Container Insights agent."
---

# Ruby Plugin Guidelines

- Always include `# frozen_string_literal: true` at the top of every file.
- Use `require_relative` for local module imports, `require` for gems.
- Telemetry: use `ApplicationInsightsUtility` singleton — never create new telemetry clients.
- Logging: use `$log.info`, `$log.warn`, `$log.error` (Fluentd logger). Never use `puts` or `print` in production code.
- Environment variables: access via `ENV["VAR_NAME"]` or injected `@env` in testable classes.
- Error handling: wrap external API calls (Kubernetes API, telemetry) in `begin/rescue` blocks. Log exceptions with `$log.warn` and send to `ApplicationInsightsUtility.sendExceptionTelemetry`.
- Constants: define in `constants.rb` using `UPPER_SNAKE_CASE`.
- Class variables (`@@var`): use for shared state across instances; initialize in constructor.
- Instance variables (`@var`): use `camelCase` naming (matching existing code).
- Testability: accept dependencies via constructor injection (e.g., `kubernetesApiClient`, `applicationInsightsUtility`, `env`) to enable unit testing with Minitest mocks.
- Chunks and batching: use `CHUNK_SIZE` and `EMIT_STREAM_BATCH_SIZE` env vars for pagination; never load unbounded API responses into memory.
- Tags: use `oneagent.containerInsights.*` prefix for Fluentd routing tags.
