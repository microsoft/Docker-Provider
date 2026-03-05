---
applyTo: "**/*.go"
description: Go coding conventions for Fluent Bit plugins and Kubernetes monitoring agent code.
---

# Go Code Guidelines

1. Use `PascalCase` for exported constants and types, `camelCase` for unexported variables and function-scoped vars.
2. Group imports in three blocks: stdlib, external packages, internal/local packages (e.g., `Docker-Provider/source/plugins/go/src/extension`).
3. Always check errors immediately after function calls — use `if err != nil { ... }` pattern.
4. Use `github.com/stretchr/testify/assert` for test assertions, not bare `if` comparisons.
5. Telemetry: use `appinsights.TelemetryClient` and `appinsights.NewMetricTelemetry()` — never create new telemetry client instances, reuse the global `TelemetryClient`.
6. Guard test-only code with `os.Getenv("GOUNITTEST") == "true"` to prevent telemetry calls during tests.
7. Constants for data types and env var names should be declared in `const` blocks at package level.
8. Use `lumberjack.v2` for log rotation — do not use raw `os.File` for log output.
9. Kubernetes client usage: use `k8s.io/client-go` with in-cluster config (`rest.InClusterConfig()`).
10. Use `sync.Mutex` or `sync.RWMutex` for concurrent access to shared state — this is a multi-goroutine plugin.
