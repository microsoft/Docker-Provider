---
applyTo: "**/*.go"
description: Go code style and Fluent Bit plugin conventions for this repository.
---

# Go / Fluent Bit Plugin Conventions

- Build output plugins as C-shared libraries: `go build -buildmode=c-shared -o out_oms.so .`
- Always check `err != nil` and log errors via the telemetry client or `Log()` function.
- Use `appinsights` SDK (`github.com/microsoft/ApplicationInsights-Go/appinsights`) for telemetry.
- Use package-level variables for telemetry counters (e.g., `FlushedRecordsCount`, `FlushedRecordsSize`).
- Use `sync.Mutex` or `sync.RWMutex` for thread-safe access to shared state.
- Do not use `fmt.Println` for production logging — use structured telemetry or the Fluent Bit log API.
- CGO is required for Fluent Bit plugin interface; ARM64 cross-compilation uses `aarch64-linux-gnu-gcc`.
- Run tests with `go test -cover -race -coverprofile=coverage.txt -covermode=atomic`.
- E2E tests use Ginkgo/Gomega framework in `test/ginkgo-e2e/`.
- Environment variables drive configuration — never hardcode connection strings or keys.
