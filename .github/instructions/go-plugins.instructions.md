---
applyTo: "source/plugins/go/**/*.go"
---
# Go Plugin Development Instructions

## Code Style
- Package `main` for Fluent Bit output plugins in `source/plugins/go/src/`
- Use PascalCase for exported identifiers, camelCase for unexported
- Constants: PascalCase grouped in `const()` blocks
- Structs: always include JSON tags (`json:"fieldName"`) and msgpack tags where needed
- Error handling: always check `err != nil` immediately, never ignore errors
- Thread safety: use `sync.Mutex` for shared state (see `NetworkFlowTelemetryMutex` pattern)

## Dependencies
- Fluent Bit Go SDK: `github.com/fluent/fluent-bit-go`
- Calyptia plugin: `github.com/calyptia/plugin` (for input plugins)
- Kubernetes client: `k8s.io/client-go`, `k8s.io/api`, `k8s.io/apimachinery`
- Telemetry: `github.com/microsoft/ApplicationInsights-Go`
- Testing: `github.com/stretchr/testify`, `github.com/golang/mock`
- Serialization: `github.com/tinylib/msgp`, `github.com/ugorji/go/codec`

## Module Structure
- `source/plugins/go/src/go.mod` — output plugin module
- `source/plugins/go/input/go.mod` — input plugin module (uses `replace` directive for `../src`)
- When adding dependencies, update the correct `go.mod` and run `go mod tidy`

## Testing
- Test files: `*_test.go` in the same package
- Run: `cd source/plugins/go/src && go test -v ./...`
- Use `testify/assert` for assertions, `golang/mock` for mocking
- Platform-specific files: `*_linux.go`, `*_windows.go`

## Build
- Linux: `cd build/linux && make`
- The Makefile compiles Go plugins into shared libraries loaded by Fluent Bit

## Patterns
- Data flows through Fluent Bit: input plugin → filter → output plugin (`out_oms.go`)
- Network flow logs: `PostNetworkFlowRecords()` in `network_flow_logs.go`
- Token management: IMDS, Arc K8s MSI, FIC auth in `ingestion_token_utils.go`
- Telemetry: `telemetry.go` for App Insights integration
