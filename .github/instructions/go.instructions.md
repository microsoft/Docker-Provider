---
applyTo: "**/*.go"
description: "Go code style, patterns, and conventions for Fluent Bit plugins in this repository."
---

# Go Conventions — Docker-Provider

1. Use `PascalCase` for exported functions and `camelCase` for unexported. Constants use `UPPER_CASE`.
2. Group imports: stdlib first, then external packages, then internal `Docker-Provider/source/plugins/go/src/...`.
3. Always check errors with `if err != nil` — never ignore returned errors.
4. Send errors to telemetry via `SendException(err.Error())` before returning.
5. Use the `Log()` function for structured logging — never raw `fmt.Println` in production code.
6. Kubernetes API clients use `k8s.io/client-go` — follow existing patterns in `extension/` and `oms.go`.
7. Plugin entry points follow CGo conventions — exported functions use `//export` directives.
8. Serialization uses `msgp` or `ugorji/go/codec` — match the existing pattern for the data type.
9. Environment variables drive configuration — use `os.Getenv()` and check for empty strings.
10. Unit tests use `testing` package and `testify/assert` — place `*_test.go` alongside source files.
11. The Go plugin compiles to a shared library (`libcontainer.so`) — CGo constraints apply.
12. Do not introduce new telemetry SDKs — use existing `ApplicationInsights-Go` patterns in `telemetry.go`.
