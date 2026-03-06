---
applyTo: "**/*.go"
description: Go code style and conventions for the Container Insights agent plugins.
---

# Go Conventions

- Use `PascalCase` for exported types, functions, constants; `camelCase` for unexported.
- Constants group related values with descriptive names (e.g., `ContainerLogDataType`, `ResourceIdEnv`).
- Always check `err != nil` immediately after function calls; log errors before returning.
- Use the `ApplicationInsights-Go` SDK (`appinsights.TelemetryClient`) for telemetry — never introduce a new telemetry library.
- Use `lumberjack` for log rotation (`gopkg.in/natefinfile/lumberjack.v2`).
- Use `k8s.io/client-go` for Kubernetes API interactions; create clients via `rest.InClusterConfig()`.
- Gate test-only code paths with `os.Getenv("GOUNITTEST") == "true"` or `os.Getenv("ISTEST") == "true"`.
- Run `go generate` before `go test` in `source/plugins/go/src/`.
- Import order: stdlib, third-party, internal (`Docker-Provider/source/plugins/go/...`).
- Use `sync.Mutex` or `sync.RWMutex` for concurrent data access; avoid global mutable state where possible.
- Use `context.Context` for cancellation propagation in Kubernetes API calls.
- Fluent Bit plugins must implement `FLBPluginRegister`, `FLBPluginInit`, `FLBPluginFlush`, `FLBPluginExit`.
