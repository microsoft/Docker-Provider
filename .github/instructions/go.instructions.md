---
applyTo: "**/*.go"
description: "Go coding conventions for Docker-Provider Fluent Bit plugins and Kubernetes clients."
---

# Go Code Standards

- Use `gofmt` formatting — no custom format overrides.
- Error handling: always check `if err != nil` — never silently ignore errors.
- Use `ApplicationInsights-Go` (`appinsights.TelemetryClient`) for telemetry — never introduce new telemetry SDKs.
- Use `fluent/fluent-bit-go` API for Fluent Bit plugin interfaces (`FLBPluginRegister`, `FLBPluginInit`, `FLBPluginFlush`).
- Kubernetes client-go is used for API calls — follow existing patterns in `source/plugins/go/input/`.
- Configuration comes from environment variables — access via `os.Getenv()`, never hardcode values.
- Use `sync.Mutex` for shared state protection — the plugins run concurrently.
- Log messages use structured format with context fields (computer, container name, etc.).
- Test with `go test ./...` in the relevant module directory.
- Multiple `go.mod` files exist — update the correct one for your change scope.
