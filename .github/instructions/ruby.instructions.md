---
applyTo: "**/*.rb"
description: "Ruby coding conventions for Fluentd plugins in this repository."
---

# Ruby Conventions

- Always include `# frozen_string_literal: true` as the second line (after shebang if present).
- Fluentd plugins must register with `Fluent::Plugin.register_input/filter/output('name', self)`.
- Use `require_relative` for project files (e.g., `require_relative "ApplicationInsightsUtility"`), `require` for gems.
- Use `ApplicationInsightsUtility.sendExceptionTelemetry(e)` for error telemetry — never create new telemetry clients.
- Class variables (`@@`) are the standard pattern for shared state within plugin classes.
- Wrap external API calls (Kubernetes, MDM) in `begin/rescue` blocks and log errors via `$log.warn` or `$log.error`.
- Use the `KubernetesApiClient` utility for all Kubernetes API interactions — do not create raw HTTP clients.
- Configuration comes from env vars (`ENV["VAR_NAME"]`) — never hardcode cluster-specific values.
- Chunked processing: use `PODS_CHUNK_SIZE`, `NODES_CHUNK_SIZE` env vars for batch sizes.
- Constants go in `constants.rb` — reference `require_relative "constants"`.
