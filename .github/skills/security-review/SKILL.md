# Skill: Security Review

## Overview
Perform STRIDE-based security reviews of changes to the Docker-Provider monitoring agent. This agent runs as a privileged DaemonSet on every Kubernetes node, collecting logs, metrics, and inventory data — making security review critical for every change.

## STRIDE Threat Analysis

### Spoofing
**Kubernetes ServiceAccount tokens**: The agent authenticates to the K8s API using the `ama-logs` ServiceAccount in `kube-system`. Review changes to:
- `kubernetes/ama-logs.yaml` — ServiceAccount definition
- `charts/azuremonitor-containers/templates/ama-logs-rbac.yaml` — RBAC bindings, time-bound token support

**IMDS metadata access**: The agent may query Azure Instance Metadata Service for identity. Verify that:
- IMDS calls use the correct audience and resource parameters
- Token caching does not persist tokens beyond their lifetime
- Arc K8s identity requests (`azureclusteridentityrequests`) in the ClusterRole are scoped appropriately

**Ingestion token auth**: `APPLICATIONINSIGHTS_AUTH` is a base64-encoded instrumentation key set in Dockerfiles. Verify:
- The key is not logged in plaintext
- Token refresh logic (in `telemetry.go` `InitializeTelemetryClient`) handles errors without exposing credentials

### Tampering
**Config integrity**: Review changes to ConfigMaps and Fluentd configuration in `kubernetes/ama-logs.yaml` for:
- Unauthorized data collection sources
- Modified collection intervals that could exfiltrate data
- Altered log routing destinations

**Helm values**: Changes to `values.yaml` can alter image tags, enable features, or change security settings. Verify:
- Image tags reference trusted MCR registry (`mcr.microsoft.com/azuremonitor/containerinsights/ciprod`)
- No new `hostPath` volume mounts that expose sensitive host directories
- Feature flags don't bypass security controls

**Container image provenance**: Dockerfiles should only pull from:
- `mcr.microsoft.com/` (Microsoft Container Registry)
- Verified upstream sources for build tools (golang, ruby-build)

### Repudiation
**Audit logging via Application Insights**: The agent sends telemetry to Application Insights. Review that:
- Error conditions trigger `SendException()` (Go) or `sendExceptionTelemetry()` (Ruby)
- Security-relevant events (auth failures, config changes) are logged
- Telemetry includes sufficient dimensions for correlation: `computer`, `controller_type`, `container_type`

**Structured logging**: Go plugins use `Log()` function, Ruby plugins use `$log.warn/error/info`. Ensure:
- Log messages include structured context (pod name, namespace, error codes)
- No sensitive data (tokens, keys, PII) appears in log messages
- Log rotation is configured (`kubernetes/linux/logrotate.conf`)

### Information Disclosure
**APPLICATIONINSIGHTS_AUTH**: This base64-encoded key is set as an environment variable in both Linux and Windows Dockerfiles. Review that:
- It is not printed in log output or error messages
- `AZMON_COLLECT_ENV=False` remains set (prevents collecting environment variables from monitored containers)
- The key is not included in telemetry custom properties

**Connection strings in logs**: Review changes to logging statements for:
- Workspace IDs, connection strings, or API keys in error messages
- Stack traces that expose internal URLs or credentials
- Debug logging that dumps request/response bodies

**Error message review**: Check that error handlers do not expose:
- File system paths from the host (via `HOST_MOUNT_PREFIX=/hostfs`)
- Kubernetes API responses containing secrets
- Internal service endpoints or IP addresses

### Denial of Service
**Container resource limits**: Review that:
- `MALLOC_ARENA_MAX=2` remains set to limit Go memory arena allocation
- `CONTAINER_MEMORY_LIMIT_IN_BYTES` is populated via `resourceFieldRef` in DaemonSet templates
- Fluent-Bit buffer settings (`FBIT_TAIL_BUFFER_MAX_SIZE`) prevent unbounded memory growth

**Kubernetes API rate limiting**: The agent polls the K8s API at intervals configured in the Fluentd ConfigMap (default 60s for most sources). Review that:
- New data sources don't decrease polling intervals excessively
- `KUBE_CLIENT_BACKOFF_BASE=1` and `KUBE_CLIENT_BACKOFF_DURATION=0` settings are appropriate
- Batch size limits exist for large clusters

**Fluent-Bit buffering**: Buffer chunk and max size are set to 1MB each by default. Review that:
- Buffer increases are justified and paired with memory limit increases
- `FBIT_SERVICE_FLUSH_INTERVAL` is not set too aggressively (default 15s)

### Elevation of Privilege
**Non-root containers**: The DaemonSet runs with `privileged: true` and capabilities `NET_ADMIN`, `NET_RAW`. Review that:
- New changes don't add unnecessary capabilities
- OpenShift SCC (`ama-logs-openshift-scc.yaml`) matches the DaemonSet security context
- No new containers in the pod spec request additional privileges

**Kubernetes RBAC**: The `ama-logs-reader` ClusterRole grants:
- `list`, `get`, `watch` on pods, nodes, events, namespaces, services, PVs
- `list` on replicasets, deployments, HPAs
- `get` on `/metrics` non-resource URL
- Arc K8s: `get`, `create`, `patch`, `list`, `update`, `delete` on `azureclusteridentityrequests`

Review that new permissions follow least-privilege. Reject changes that add:
- `create`, `update`, `delete` on core resources (pods, secrets, configmaps) unless justified
- Access to secrets beyond the specific `container-insights-clusteridentityrequest-token`
- Cluster-admin equivalent permissions

**Security contexts**: Verify changes to `securityContext` blocks in:
- `charts/azuremonitor-containers/templates/ama-logs-daemonset.yaml`
- `charts/azuremonitor-containers/templates/ama-logs-deployment.yaml`
- `kubernetes/ama-logs.yaml`

## Credential Detection Patterns
Scan for these patterns in code changes:
```
# Base64-encoded keys (like APPLICATIONINSIGHTS_AUTH)
/[A-Za-z0-9+\/]{20,}={0,2}/

# Azure connection strings
/(Endpoint|SharedAccessKey|AccountKey)=[^;]+/

# Instrumentation keys (GUID format)
/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/

# Bearer tokens in code
/(Bearer|Authorization)\s+[A-Za-z0-9._-]+/
```

## Language-Specific Weak Patterns

### Go
- `fmt.Sprintf` with credential variables — use structured logging instead
- Unchecked `os.Getenv("APPLICATIONINSIGHTS_AUTH")` — validate before use
- HTTP clients without timeout — can cause goroutine leaks
- `log.Printf` with `%v` on structs containing credentials

### Ruby
- `puts` or `print` with sensitive data — use `$log` with appropriate level
- String interpolation of environment variables in log messages
- Unvalidated external input in Fluentd filter/input plugins
- Missing `$in_unit_test` guards around telemetry calls in test paths

### Shell
- Unquoted variable expansion (`$VAR` vs `"$VAR"`) — injection risk
- `curl` without `--fail` — silent failures on auth endpoints
- Credentials passed as command-line arguments (visible in `/proc`)
- `chmod 777` or overly permissive file permissions

## CI Security Tools
| Tool | Config | Trigger | Output |
|------|--------|---------|--------|
| CodeQL | `.github/workflows/codeql-analysis.yml` | Push/PR to `ci_prod`, weekly | SARIF → GitHub Security tab |
| DevSkim | `.github/workflows/devskim.yml` | Push/PR to `ci_prod`, weekly | SARIF → GitHub Security tab |
| Trivy | Manual / CI | On-demand | Console output, `.trivyignore` for exceptions |

## Review Checklist
1. No new credentials or secrets hardcoded in source
2. No expanded RBAC permissions without documented justification
3. No new `hostPath` mounts or privileged escalation
4. Error handling does not leak sensitive information
5. Telemetry changes include appropriate dimensions for audit
6. Container resource limits remain appropriate
7. Base images and dependencies come from trusted sources
8. `.trivyignore` changes include justification and tracking reference
9. All CI security tools (CodeQL, DevSkim, Trivy) pass
