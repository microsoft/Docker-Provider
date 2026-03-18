---
applyTo: "source/plugins/go/**/*.go,test/ginkgo-e2e/**/*.go"
description: "Go Fluent Bit plugin and E2E test coding conventions."
---

# Go Plugin Guidelines

- Use standard `gofmt` formatting — no custom formatter.
- Constants: `PascalCase` with descriptive names (e.g., `ContainerLogV2DataType`).
- Error handling: always check `err != nil` — never silently discard errors. Log with `Log(msg)` helper or `log.Printf`.
- Telemetry: use `github.com/microsoft/ApplicationInsights-Go/appinsights` package. Track metrics via `TelemetryClient.TrackMetric` and events via `TelemetryClient.TrackEvent`.
- Serialization: use `github.com/tinylib/msgp` for MessagePack, `encoding/json` for JSON. Prefer msgp for Fluent Bit inter-plugin communication.
- Test gating: check `os.Getenv("GOUNITTEST") == "true"` or `os.Getenv("ISTEST") == "true"` to skip production-only code paths in tests.
- Tests: use `github.com/stretchr/testify/assert` for assertions. Test files named `*_test.go` alongside source.
- Build: the output plugin builds as a C-shared library (`buildmode=c-shared`) producing `out_oms.so`.
- Dependencies: use Go modules. Run `go mod tidy` after dependency changes.
- Kubernetes client: use `k8s.io/client-go` with in-cluster config (`rest.InClusterConfig()`).
- Concurrency: protect shared state with `sync.Mutex`. Use contexts for cancellation.
- No CGO in tests — unit tests run with standard `go test`.
