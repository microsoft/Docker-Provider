---
applyTo: "**/*.go"
---

- Use standard Go formatting (`gofmt`). All Go files follow standard Go conventions.
- Export names with `PascalCase`; keep unexported names in `camelCase`.
- Fluent Bit plugin functions follow the C-binding interface: `FLBPluginRegister`, `FLBPluginInit`, `FLBPluginFlush`, `FLBPluginExit`.
- Use `k8s.io/client-go` for Kubernetes API interactions. Do not use raw HTTP calls.
- Use `testify/assert` and `testify/require` for test assertions.
- Use `golang/mock` with `go generate` for mock generation.
- Gate test-only behavior with `GOUNITTEST` and `ISTEST` environment variables.
- Use `ApplicationInsights-Go` for telemetry reporting via `appinsights` package.
- Use `msgp` for MessagePack serialization in Fluent Bit data exchange.
- Keep `go.mod` `replace` directive in `source/plugins/go/src/go.mod` pointing to `../input` in sync.
- Log using standard patterns: check error returns and log context before returning.
