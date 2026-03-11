---
applyTo: "**/*.go"
---

# Go Coding Instructions

- Follow existing camelCase for functions, PascalCase for exported types, UPPER_CASE for constants
- Group imports: stdlib, then external packages, then internal (Docker-Provider/source/...)
- Always handle errors with `if err != nil` — log with Log() and return/continue
- Use ApplicationInsights-Go SDK for telemetry (track_metric, track_exception) via existing helpers
- Fluent-Bit Go plugins use C-shared build mode — exported functions must have //export comments
- Use k8s.io/client-go for Kubernetes API interactions — follow existing clientset patterns
- Use msgp for MessagePack serialization (MDSD protocol)
- Use testify/assert for test assertions, testify/mock for mocking
- Run tests: `go test -cover -race -coverprofile=coverage.txt ./...`
- Do not introduce new logging frameworks — use existing Log() function in oms.go
- Environment variables for config — never hardcode connection strings or keys
