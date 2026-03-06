---
applyTo: "**/*.go"
description: Go coding conventions for Fluent Bit plugins and test utilities in this repository.
---

# Go Conventions

- Use `gofmt` formatting — no manual style overrides.
- Check every error return: `if err != nil { ... }`. Never discard errors silently.
- Use the existing `TelemetryClient` (from `appinsights` package) for telemetry — never create new clients.
- Guard test-only code with `os.Getenv("GOUNITTEST") == "true"` or `os.Getenv("ISTEST") == "true"`.
- Constants use PascalCase: `ContainerLogDataType`, `InsightsMetricsDataType`.
- Group imports: stdlib, then external (`github.com/...`), then internal (`Docker-Provider/...`).
- Shared state uses `sync.Mutex` — protect concurrent access to global variables.
- Log using the Fluent Bit logger or `log.Printf` — avoid `fmt.Println` in production paths.
- Go plugins compile as C shared objects — always use `CGO_ENABLED=1` and test with `go test .`.
- For input plugins under `source/plugins/go/input/`, follow the `calyptia/plugin` pattern.
