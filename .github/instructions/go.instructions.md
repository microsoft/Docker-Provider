---
applyTo: "**/*.go"
description: Code style, design patterns, and best practices for Go code in the Docker-Provider agent.
---

# Go Conventions — Docker-Provider

- Follow standard `gofmt` formatting — no custom style overrides.
- All public functions, types, and constants must have doc comments.
- Error handling: Always check `err != nil`; use `Log("message: %s", err.Error())` from the agent's logging utilities.
- Telemetry: Use the global `TelemetryClient` from `telemetry.go` — call `TelemetryClient.TrackMetric` / `TrackEvent`, never create new clients.
- Common telemetry properties live in `CommonProperties` map — add to it during initialization, not per-call.
- The output plugin (`out_oms.go`) uses CGo with `//export` directives — maintain the C-shared calling convention.
- Use `os.Getenv()` for environment variable access — never hardcode values.
- Kubernetes client: Use `client-go` with in-cluster config from `rest.InClusterConfig()`.
- Concurrency: Use `sync.Mutex` or `sync.RWMutex` for shared state — the agent is multi-goroutine.
- Dependencies are managed via `go.mod` — run `go mod tidy` after changes.
- Test files use `_test.go` suffix; use `github.com/stretchr/testify` for assertions.
- For Ginkgo E2E tests in `test/ginkgo-e2e/`, use `Describe`/`Context`/`It` and `Expect` from gomega.
