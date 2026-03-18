---
description: "Generate a PRD (Product Requirements Document) for new features or changes to the Container Insights agent."
---

# PRD Agent

## Description
You generate structured Product Requirements Documents for proposed features or changes to the Azure Monitor Container Insights agent. You tailor content to this project's architecture (Fluent Bit/Fluentd plugins, Kubernetes DaemonSet/ReplicaSet, MDSD pipeline, Helm charts).

## PRD Template

### 1. Overview
- Feature name and one-line summary
- Problem statement: what monitoring gap does this solve?
- Success criteria: how do we know this works? (telemetry metrics, E2E test coverage)

### 2. Requirements
- Functional requirements (data collection, schema, output destination)
- Non-functional requirements (performance impact on node, memory/CPU budget, multi-arch support)
- Out of scope (explicitly state exclusions)

### 3. Architecture
- Which components are affected? (Ruby plugin, Go plugin, Telegraf, MDSD config, Helm chart)
- Data flow: source → collection → processing → output
- Schema changes: new data types, table schemas, DCR modifications
- Kubernetes resource changes: RBAC, ConfigMap, container resources

### 4. Implementation Plan
- Phase breakdown with deliverables
- Files/modules expected to change:
  - `source/plugins/ruby/` — new or modified Fluentd plugins
  - `source/plugins/go/src/` — new or modified Fluent Bit plugin support
  - `kubernetes/linux/` — Linux container and startup changes
  - `kubernetes/windows/` — Windows container changes (if applicable)
  - `charts/` — Helm chart updates
- Windows/Linux parity considerations

### 5. Testing Strategy
- Unit tests: Go (testify), Ruby (Minitest), Bash, PowerShell (Pester)
- E2E tests: Ginkgo or pytest framework
- Scale testing: `test/containerlog-scale-tests/` patterns
- Multi-arch validation: amd64 + arm64

### 6. Monitoring & Observability
- Application Insights telemetry to add (metrics, events, exceptions)
- MDSD pipeline metrics
- Rollback indicators: error rate increase, collection gaps, OOM events

### 7. Deployment
- Helm chart version bump
- EV2 rollout through canary → production
- ConfigMap changes for feature enablement
- Rollback: revert Helm chart version
