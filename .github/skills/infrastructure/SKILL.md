# Skill: Infrastructure

## Overview
Modify Kubernetes manifests, Helm charts, Dockerfiles, and RBAC configurations for the Docker-Provider monitoring agent. Infrastructure changes affect how the agent is deployed, scheduled, and secured across AKS, Arc-enabled, and on-premises Kubernetes clusters.

## Scope
- **K8s manifests**: `kubernetes/ama-logs.yaml` (ServiceAccount, ClusterRole, ClusterRoleBinding, ConfigMap, DaemonSet)
- **Helm charts**: `charts/azuremonitor-containers/`, `charts/azuremonitor-containers-geneva/`, `charts/azuremonitor-containerinsights-for-prod-clusters/`
- **Dockerfiles**: `kubernetes/linux/Dockerfile.multiarch` (multi-arch Linux), `kubernetes/windows/Dockerfile` (Windows)
- **Startup scripts**: `kubernetes/linux/main.sh`, `kubernetes/linux/setup.sh`
- **RBAC**: ClusterRole `ama-logs-reader`, SecurityContextConstraints for OpenShift

## Procedures

### Kubernetes Manifest Changes (ama-logs.yaml)
The standalone manifest at `kubernetes/ama-logs.yaml` defines:
- **ServiceAccount** `ama-logs` in `kube-system`
- **ClusterRole** `ama-logs-reader` with read access to pods, nodes, events, namespaces, services, replicasets, deployments, HPAs, PVs, and `/metrics`
- **ClusterRoleBinding** linking the ServiceAccount to the ClusterRole
- **ConfigMap** with Fluentd source configurations (KubePodInventory, KubePVInventory, KubeEvents, KubeNodeInventory)

When adding new data collection, update the ClusterRole to grant necessary API permissions and add the corresponding Fluentd source in the ConfigMap.

### Helm Chart Updates
1. **Chart.yaml**: Bump `version` for any chart content change. Current appVersion: `7.0.0-1`.
2. **values.yaml**: Image tags (`3.1.35` Linux, `win-3.1.35` Windows), Fluent-Bit buffer settings (`tailbufchunksizemegabytes`, `tailbufmaxsizemegabytes`), scheduling priority.
3. **Templates**: Mirror manifest changes in the Helm templates:
   - `ama-logs-daemonset.yaml` — Linux DaemonSet with privileged securityContext and NET_ADMIN/NET_RAW capabilities
   - `ama-logs-deployment.yaml` — ReplicaSet-based deployment
   - `ama-logs-rbac.yaml` — RBAC with Arc K8s extensions (azureclusteridentityrequests)
   - `ama-logs-openshift-scc.yaml` — OpenShift SecurityContextConstraints

Keep the standalone manifest and Helm templates in sync for overlapping resources.

### Dockerfile Modifications
**Linux (`kubernetes/linux/Dockerfile.multiarch`):**
- Three build stages: `golang-builder` → `builder` → `distroless_image`
- Base: `mcr.microsoft.com/azurelinux/base/core:3.0` (builder), `mcr.microsoft.com/azurelinux/distroless/base:3.0` (runtime)
- OS packages via `tdnf install` (build-essential, curl, rsyslog, busybox, etc.)
- Environment variables: `MALLOC_ARENA_MAX=2`, `RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=1.0`, `APPLICATIONINSIGHTS_AUTH`

**Windows (`kubernetes/windows/Dockerfile`):**
- Base: `mcr.microsoft.com/windows/servercore` (ltsc2019/ltsc2022)
- Ruby 3.1.1.1 via Chocolatey, Fluentd 1.16.3

When changing base images, review all `tdnf install`/`choco install` lines for package compatibility.

### RBAC and Security Context Changes
- ClusterRole permissions follow least-privilege; only add verbs/resources required by new features.
- DaemonSet pods run privileged with NET_ADMIN and NET_RAW capabilities (required for network monitoring).
- OpenShift deployments use the SCC defined in `ama-logs-openshift-scc.yaml`.

## Validation Checklist
1. **Build**: `cd build/linux && make` — must succeed for both amd64 and arm64
2. **Docker build**: `docker build -f kubernetes/linux/Dockerfile.multiarch .` — verify all stages complete
3. **Helm lint**: `helm lint charts/azuremonitor-containers/` (repeat for each chart)
4. **Helm template**: `helm template charts/azuremonitor-containers/` — review rendered output
5. **YAML validation**: `kubectl apply --dry-run=client -f kubernetes/ama-logs.yaml`
6. **Security scan**: `trivy fs --severity CRITICAL,HIGH --scanners vuln .`
7. **Deploy to test cluster**: Apply to a dev AKS cluster and verify pods reach `Running` state
8. **CI**: Ensure `pr-checker.yml` passes

## Commit Convention
Freeform message describing the infrastructure change. Reference PR number. Example:
```
Add PV metrics collection to ClusterRole and Fluentd config (#1234)
```

## Pitfalls
- Helm templates and standalone `ama-logs.yaml` can drift — always update both.
- Changing ClusterRole permissions requires cluster-admin access to deploy; verify in test cluster.
- Dockerfile `tdnf install` lines without version pins may break on base image updates.
- Windows and Linux Dockerfiles have different Ruby versions and package managers; changes rarely apply to both.
- Chart version in `Chart.yaml` must be bumped for any template or values change, or Helm upgrade will no-op.
