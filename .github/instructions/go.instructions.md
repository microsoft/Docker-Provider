---
applyTo: "**/*.go"
description: Go coding conventions for the Azure Monitor container agent Go plugins.
---

# Go Conventions

- Build with `-buildmode=c-shared` — all plugin code is in package `main` and produces `.so` files loaded by Fluent Bit.
- Constants use `PascalCase`: `ContainerLogDataType`, `ResourceIdEnv`, `TelegrafMetricOriginPrefix`.
- Use `os.Getenv("ENV_VAR")` for configuration — never hardcode values.
- Error handling: always check `err != nil` immediately; log with `Log()` or `fmt.Sprintf` and return appropriate Fluent Bit return codes (`output.FLB_OK`, `output.FLB_ERROR`, `output.FLB_RETRY`).
- Telemetry: use the `appinsights.TelemetryClient` singleton initialized in `telemetry.go`. Call `SendEvent()` for custom events; do not create new `TelemetryClient` instances.
- Use `sync.Mutex` / `sync.RWMutex` for shared state protection — the Fluent Bit plugin callbacks run concurrently.
- Import ordering: stdlib → third-party (`github.com/...`) → internal (`Docker-Provider/source/plugins/go/src/...`).
- Use `msgp` for MessagePack serialization and `ugorji/go/codec` for encoding — follow existing patterns in `oms.go`.
- Unit tests go in `*_test.go` files in the same directory; run with `go test -cover -race`.
- Do not use `fmt.Println` for production logging — use the structured logging helpers or `Log()`.
- Respect the `GOUNITTEST` environment variable guard to skip telemetry emission during tests.
