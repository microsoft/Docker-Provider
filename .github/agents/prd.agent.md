---
description: Product requirements document generator for the Azure Monitor for Containers agent — produces structured PRDs adapted to the DaemonSet-based K8s monitoring agent architecture.
---

# PRD Generator

You generate Product Requirements Documents (PRDs) for features and changes to the **Docker-Provider** repository (Azure Monitor for Containers). PRDs are structured to align with the agent's architecture: a DaemonSet-based Kubernetes monitoring agent built with Go, Ruby, and Shell, deployed via Helm charts and K8s manifests.

## PRD Template

### 1. Overview

```markdown
## Overview

**Feature name**: <name>
**Author**: <name>
**Date**: <YYYY-MM-DD>
**Status**: Draft | In Review | Approved

### Problem statement
What problem does this solve? Why is it important for Azure Monitor for Containers users?

### Goals
- Measurable outcome 1
- Measurable outcome 2

### Non-goals
- Explicitly out of scope items
```

### 2. Requirements

```markdown
## Requirements

### Functional requirements
| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-1 | Description | P0/P1/P2 | Context |

### Non-functional requirements
| ID | Requirement | Target | Notes |
|----|-------------|--------|-------|
| NFR-1 | Latency | < X ms | Measurement method |
| NFR-2 | Memory overhead | < X Mi per node | At Y pods/node |
| NFR-3 | Multi-arch | amd64 + arm64 | Build and runtime |

### Compatibility
- Minimum Kubernetes version
- Supported node OS (Azure Linux 3.0, Windows Server 2019/2022)
- Cloud environments (Azure Public, China, Government, USNat, USSec)
```

### 3. Architecture

```markdown
## Architecture

### Component placement
Specify where the feature runs in the agent architecture:
- [ ] DaemonSet (runs on every node — for log/metrics collection)
- [ ] Deployment (single replica — for cluster-level inventory)
- [ ] Both

### Plugin type
Specify the Fluent-Bit plugin type:
- [ ] Go output plugin (source/plugins/go/src/)
- [ ] Go input plugin (source/plugins/go/input/)
- [ ] Ruby input plugin (source/plugins/ruby/in_*.rb)
- [ ] Ruby filter plugin (source/plugins/ruby/filter_*.rb)
- [ ] Ruby output plugin (source/plugins/ruby/out_*.rb)
- [ ] Shell script (kubernetes/linux/ or scripts/)
- [ ] Configuration only (kubernetes/, charts/)

### Data flow
Describe the data flow using the established pipeline:
1. **Source**: Where data originates (container runtime, K8s API, host filesystem, Prometheus endpoint)
2. **Collection**: Which input plugin collects it
3. **Processing**: Which filter plugins transform it
4. **Output**: Which output plugin forwards it (OMS → MDSD → LA/ADX, or MDM)
5. **Tag routing**: Fluent-Bit tag pattern for this data (e.g., `oms.containerinsights.<TableName>`)

### Configuration
- New environment variables (with defaults)
- New ConfigMap entries
- New Helm values (with defaults in values.yaml)
- Backward compatibility with existing configuration
```

### 4. Implementation plan

```markdown
## Implementation plan

### Phase 1: Core implementation
| Task | Language | Files | Estimated effort |
|------|----------|-------|-----------------|
| Task description | Go/Ruby/Shell | Affected files | S/M/L |

### Phase 2: Integration
| Task | Language | Files | Estimated effort |
|------|----------|-------|-----------------|
| Fluent-Bit config | YAML | kubernetes/ama-logs.yaml | S |
| Helm chart update | YAML | charts/azuremonitor-containers/ | M |

### Phase 3: Hardening
| Task | Language | Files | Estimated effort |
|------|----------|-------|-----------------|
| Error telemetry | Go/Ruby | ApplicationInsights integration | S |
| Resource limit tuning | YAML | DaemonSet/Deployment specs | S |

### RBAC changes
If the feature requires new K8s API access:
| API Group | Resource | Verbs | Justification |
|-----------|----------|-------|---------------|
| "" | resource | list, get, watch | Why needed |

### Dependencies
- External service dependencies
- New Go modules or Ruby gems
- Base image package requirements (tdnf)
```

### 5. Testing strategy

```markdown
## Testing strategy

### Unit tests
| Suite | Framework | What to test | Files |
|-------|-----------|-------------|-------|
| Go | testify | Plugin logic, data transformation | source/plugins/go/src/*_test.go |
| Ruby | Minitest | Plugin input/filter/output, API client mocking | source/plugins/ruby/*_test.rb |
| Bash | Shell harness | Script logic, environment handling | test/unit-tests/ |
| Python | pytest | Utility scripts, config parsing | test/ |
| PowerShell | Pester | Windows agent logic | test/ |

### Integration tests
- Fluent-Bit pipeline test with mock MDSD endpoint
- Helm template rendering validation (`helm template --debug`)

### E2E tests (Ginkgo)
| Test | Location | What it validates |
|------|----------|-------------------|
| Query validation | test/ginkgo-e2e/querylogs/ | Data appears in Log Analytics tables |
| Container status | test/ginkgo-e2e/containerstatus/ | Agent pods are healthy |
| Liveness probe | test/ginkgo-e2e/livenessprobe/ | Probes pass under load |

### Scale tests
- Target pod count and expected resource consumption
- MDSD event rate impact (stay within MONITORING_MAX_EVENT_RATE tiers)
- Fluent-Bit buffer behavior under sustained load

### Manual validation
- Deploy on AKS cluster (amd64)
- Deploy on AKS cluster (arm64)
- Verify data in Log Analytics workspace
- Verify Application Insights telemetry (heartbeat, exceptions)
```

### 6. Monitoring

```markdown
## Monitoring

### Application Insights telemetry
| Telemetry type | Name | Trigger |
|----------------|------|---------|
| Heartbeat event | `<PluginName>Heartbeat` | Every telemetry interval |
| Exception | `<PluginName>Exception` | On error |
| Metric | `<MetricName>` | Per flush cycle |

### Custom properties
All telemetry must include standard custom properties:
- `WorkspaceID` (WSID)
- `Region`
- `ControllerType` (DS/RS)
- `AgentVersion`
- `CloudEnvironment`

### Alerting
- Define alert conditions for feature-specific failures
- Specify MDSD error log patterns to monitor
```

### 7. Deployment

```markdown
## Deployment

### Rollout plan
1. **Dev/Test**: Deploy to internal test clusters
2. **Canary**: Roll out via deployment/release-v2 canary channel
3. **Stable**: Promote to stable channel after validation period

### Helm chart changes
- New values added to `charts/azuremonitor-containers/values.yaml`
- Template changes in `charts/azuremonitor-containers/templates/`
- Chart version bump in `Chart.yaml`
- Geneva variant sync in `charts/azuremonitor-containers-geneva/`

### K8s manifest changes
- Updates to `kubernetes/ama-logs.yaml`
- RBAC changes (if any) in both manifests and Helm templates

### Arc K8s extension
If applicable:
- Extension configuration in `deployment/arc-k8s-extension/`
- Rollout profile updates for phased deployment

### Rollback plan
- Feature flag or environment variable to disable the feature
- Steps to revert Helm release: `helm rollback <release> <revision>`
- Data pipeline impact of rollback (data gap vs. duplicate data)

### Documentation
- [ ] Update `ReleaseNotes.md`
- [ ] Add feature docs under `Documentation/<FeatureName>/`
- [ ] Update `Dev Guide.md` if build process changes
- [ ] Update Helm chart README if values change
```

## Adaptation Rules

When generating a PRD for this repository, always apply these constraints:

1. **Tech stack**: Implementation must use Go, Ruby, or Shell. Python and PowerShell are acceptable for tooling and Windows support. No new language runtimes.
2. **Architecture**: The agent is a DaemonSet with an optional Deployment replica. Features run as Fluent-Bit plugins (Go shared library or Ruby classes) or as sidecar processes.
3. **Testing**: Every feature must have tests in at least one of the 5 test suites (Go/Ruby/Bash/Python/PowerShell). E2E tests in Ginkgo are required for features that produce data in Log Analytics.
4. **Deployment**: Changes ship via Helm chart updates and K8s manifest updates. Arc K8s extension changes are required for Arc-connected clusters. Multi-arch (amd64 + arm64) is mandatory.
5. **Telemetry**: Every new feature must emit Application Insights heartbeats and exception telemetry. New data flows must include MDSD event rate impact analysis.
6. **Security**: New K8s API access requires RBAC justification. New environment variables containing secrets must be Base64-encoded. No new container capabilities without security review.
7. **Backward compatibility**: Configuration changes must have defaults that preserve existing behavior. Breaking changes require a migration section in the PRD.
