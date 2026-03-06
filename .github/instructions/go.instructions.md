---
applyTo: "**/*.go"
description: "Go coding conventions for Fluent Bit plugins in this repository."
---

# Go Conventions

- Use the custom `Log()` function for all logging — never use `fmt.Println` or `log.Print` in production code.
- Always check `err != nil` after every function call and log the error with context before returning.
- Fluent Bit output plugin exports use `//export FLBPlugin*` CGo comments — follow the existing pattern in `out_oms.go`.
- Use `sync.Mutex` or `sync.Once` for shared state — the plugins run concurrently across goroutines.
- Telemetry: use `appinsights.NewTelemetryClient()` and `appinsights.TrackEvent()`/`TrackMetric()` — reference `telemetry.go` for patterns.
- Environment variables: use `os.Getenv()` for configuration — never hardcode connection strings or keys.
- Build tags: use `//go:build linux` or `//go:build windows` for platform-specific files (e.g., `utils_linux.go`, `utils_windows.go`).
- Dependencies are in `source/plugins/go/src/go.mod` — run `go mod tidy` after any dependency changes.
- Unit tests use `testify` assertions — place `*_test.go` files alongside source.
- The plugin compiles to a shared object (`out_oms.so`) loaded by Fluent Bit — avoid `init()` side effects that break the plugin loader.
