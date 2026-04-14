---
name: test-telegraf-upgrade
description: "Test a Telegraf upgrade end-to-end on a live AKS cluster. Deploys prod image baseline, then test image, compares data in Log Analytics across multiple configmap scenarios. Use when someone says 'test telegraf upgrade', 'validate telegraf', 'telegraf regression test', or 'verify telegraf version'."
argument-hint: "Provide the branch name with the telegraf upgrade, or 'current' to test what's already deployed"
---

# Test Telegraf Upgrade

Validates a Telegraf upgrade by comparing data between the **production image** (baseline) and the **test image** (with the new telegraf version) in Log Analytics. Tests multiple configmap scenarios to cover all telegraf features.

## Approach

1. Deploy the **production image** → collect baseline data from Log Analytics
2. Deploy the **test image** → collect test data from Log Analytics
3. **Compare** data volume per table — they should match
4. If any mismatch is found, **then** investigate internal data flow (telegraf config, processes, ports)
5. Repeat with **different configmap scenarios** to cover all features

## Required Inputs

Check with the user if they want to use the default values or provide new ones.

| Input | Description | Default |
|-------|-------------|---------|
| **Branch name** | Git branch with the telegraf upgrade | Current branch |
| **Current production image** | Production image tag | `ciprod:3.1.35` |
| **YAML file path** | Helm values file for deployment | `./../azuremonitor-containerinsights-for-prod-clusters/values.yaml` |

## Derived Values

Parse automatically from the YAML file — do not ask the user.

| Value | Source |
|-------|--------|
| **Cluster Resource ID** | `OmsAgent.aksResourceID` |
| **Log Analytics Workspace ID** | `OmsAgent.workspaceID` |
| **Cluster Name** | Last segment of the cluster resource ID |
| **Subscription ID** | Extracted from the cluster resource ID |
| **Resource Group** | Extracted from the cluster resource ID |

## General Rules

- Save the output of **each step** to `TelegrafTestOutput.md` in the repo root. Always append new results at the end.
- Only investigate internal data flow (telegraf processes, configs, ports) **if data comparison fails**.
- Before each scenario, **back up the original configmap** so it can be restored.
- After all scenarios complete, **restore the original configmap and production image**.

---

## Configmap Scenarios

Each scenario tests a different configmap configuration. Run the full deploy-collect-compare cycle for **each scenario**.

### Scenario 1: Default Configuration (No Custom Prometheus)

**Purpose**: Tests default telegraf behavior — kubelet metrics, disk, diskio, net.

**Configmap settings** (`prometheus-data-collection-settings`):
```toml
[prometheus_data_collection_settings.cluster]
    interval = "1m"
    monitor_kubernetes_pods = false

[prometheus_data_collection_settings.node]
    interval = "1m"
```

**Tables to compare**:
- `InsightsMetrics` (namespaces: `container.azm.ms/prometheus`, `container.azm.ms/disk`, `container.azm.ms/diskio`, `container.azm.ms/net`)
- `Perf`

**Additional checks**:
- Verify loopback interface is filtered: no `InsightsMetrics` with `container.azm.ms/net` namespace where `Tags` contains `"interface":"lo"`.

### Scenario 2: Pod-level Prometheus Scraping (monitor_kubernetes_pods)

**Purpose**: Tests the sidecar's ability to discover and scrape annotated pods.

**Configmap settings** (`prometheus-data-collection-settings`):
```toml
[prometheus_data_collection_settings.cluster]
    interval = "1m"
    monitor_kubernetes_pods = true

[prometheus_data_collection_settings.node]
    interval = "1m"
```

**Pre-requisite**: Deploy the prometheus reference app:
```bash
kubectl create namespace prom-test --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f test/prometheus-scraping/prometheus-reference-app.yaml -n prom-test
```

**Tables to compare**:
- `InsightsMetrics` (all namespaces)
- `Perf`

**Additional checks**:
- Verify reference app metrics appear: `InsightsMetrics` where `Tags` contains `scrapeUrl` with port `2112`.
- Compare reference app metric counts between prod and test.

### Scenario 3: Namespace-scoped Prometheus Scraping

**Purpose**: Tests namespace filtering — only scrapes pods in specified namespaces.

**Configmap settings** (`prometheus-data-collection-settings`):
```toml
[prometheus_data_collection_settings.cluster]
    interval = "1m"
    monitor_kubernetes_pods = true
    monitor_kubernetes_pods_namespaces = ["prom-test"]

[prometheus_data_collection_settings.node]
    interval = "1m"
```

**Pre-requisite**: Same reference app in `prom-test` namespace from Scenario 2.

**Tables to compare**:
- `InsightsMetrics` (all namespaces)
- `Perf`

**Additional checks**:
- Verify reference app metrics still appear from the `prom-test` namespace.
- Verify no pods from other namespaces are scraped (no scrapeUrls from non-prom-test pods).

### Scenario 4: Custom Prometheus URLs (Daemonset node-level)

**Purpose**: Tests daemonset custom URL scraping.

**Configmap settings** (`prometheus-data-collection-settings`):
```toml
[prometheus_data_collection_settings.cluster]
    interval = "1m"
    monitor_kubernetes_pods = false

[prometheus_data_collection_settings.node]
    interval = "1m"
    urls = ["http://localhost:9100/metrics"]
```

> **Note**: Use a URL that is expected to exist or be unreachable — the goal is to verify telegraf processes the config correctly without crashing, not that the endpoint exists. If a reachable endpoint is available on the node, verify data appears.

**Tables to compare**:
- `InsightsMetrics` (all namespaces)
- `Perf`

### Scenario 5: Field Filtering (fieldpass / fielddrop)

**Purpose**: Tests that fieldpass and fielddrop correctly filter metrics.

**Configmap settings** (`prometheus-data-collection-settings`):
```toml
[prometheus_data_collection_settings.cluster]
    interval = "1m"
    monitor_kubernetes_pods = true
    fieldpass = ["weather_temperature", "weather_humidity"]

[prometheus_data_collection_settings.node]
    interval = "1m"
```

**Pre-requisite**: Reference app deployed (has weather metrics).

**Tables to compare**:
- `InsightsMetrics` (all namespaces)

**Additional checks**:
- Verify only `weather_temperature` and `weather_humidity` metric names appear from pod scraping (not other reference app metrics).
- Default kubelet/disk/net metrics should still flow normally.

### Scenario 6: Label and Field Selectors

**Purpose**: Tests kubernetes_label_selector and kubernetes_field_selector.

**Configmap settings** (`prometheus-data-collection-settings`):
```toml
[prometheus_data_collection_settings.cluster]
    interval = "1m"
    monitor_kubernetes_pods = true
    kubernetes_label_selector = "app=prometheus-reference-app"

[prometheus_data_collection_settings.node]
    interval = "1m"
```

**Tables to compare**:
- `InsightsMetrics` (all namespaces)

**Additional checks**:
- Verify only the reference app's metrics appear from pod scraping (label selector filters to only matching pods).

### Scenario 7: High Log Scale + Process Metrics (if supported)

**Purpose**: Tests process metrics collection via `inputs.procstat` → `outputs.application_insights`.

**Configmap settings** (`agent-settings`):
```toml
[agent_settings.high_log_scale]
  enabled = false

[agent_settings.collect_ama_logs_process_metrics]
  enabled = true
```

**Tables to compare**:
- `InsightsMetrics` (all namespaces)
- `Perf`

**Additional checks** (only if comparison fails):
- Verify process metrics telegraf config exists and parses: `telegraf --config telegraf-ama-logs-process-metrics.conf --input-filter file -test`
- Verify procstat targets: `mdsd`, `fluent-bit`, `telegraf`, `ruby`, `crond`, `inotifywait`, `fluentd`, `main.sh`

> **Note**: Process metrics use `outputs.application_insights` (direct send), NOT the `socket_writer`/fluent-bit pipeline. They won't appear in Log Analytics InsightsMetrics — check Application Insights instead if available.

---

## Workflow Per Scenario

For each scenario, follow this workflow:

### Step 1: Back Up Current Configmap

```bash
kubectl get configmap container-azm-ms-agentconfig -n kube-system -o yaml > /tmp/configmap-backup.yaml
```

### Step 2: Apply Scenario Configmap

Update only the relevant settings in the configmap. **Do not change other settings.**

```bash
kubectl apply -f <scenario-configmap>.yaml
```

Wait 2-3 minutes for the agent to pick up the new configmap.

### Step 3: Deploy Production Image

Update YAML with the production image and deploy:
```bash
helm upgrade --install ama-logs <chart-path> -n kube-system
```

Record the **production deployment time** (UTC).

### Step 4: Wait and Collect Production Baseline

Wait **15 minutes** for pod startup + data ingestion. Then verify pods:
```bash
kubectl get pods -n kube-system | grep ama-logs
```

Confirm all pods are Running with 0 restarts. Then collect baseline data for all tables in **1-minute bins** from **(deploy time + 5 min)** to **(deploy time + 10 min)**:

```kusto
<TableName>
| where TimeGenerated between(datetime('<deployTime+5min>') .. datetime('<deployTime+10min>'))
| where _ResourceId =~ '<clusterResourceId>'
| summarize Count=count() by bin(TimeGenerated, 1m)
| order by TimeGenerated asc
```

Run for: `InsightsMetrics` (broken down by `Namespace`), `Perf`.

### Step 5: Deploy Test Image

Update YAML with the test image (from the CI build) and deploy. Record the **test deployment time** (UTC).

### Step 6: Wait and Collect Test Data

Same as Step 4 but for the test image.

### Step 7: Compare Data

Compare production vs test counts **side by side** for each table/namespace:

- For `InsightsMetrics` (per namespace), `Perf`: counts must match **exactly** per minute (excluding first/last minute edge windows). If they differ by even 1, investigate.
- For `ContainerLogV2`: exact match is not required, but check for sustained upward/downward trends.

### Step 8: Investigate If Needed

**Only if comparison shows a mismatch**, investigate the internal data flow:

#### 8a: Check Telegraf Config Parsing
```bash
# Verify no raw $AZMON_* placeholders
kubectl exec -n kube-system <pod> -c <container> -- grep '\$AZMON' <config-file>

# Verify config parses successfully
kubectl exec -n kube-system <pod> -c <container> -- /opt/telegraf --config <config-file> --input-filter file -test
```

#### 8b: Check Telegraf Process
```bash
kubectl exec -n kube-system <pod> -c <container> -- ps aux | grep telegraf | grep -v grep
```

#### 8c: Check Error Logs
```bash
# Container logs
kubectl logs -n kube-system <pod> -c <container> | grep -iE "(telegraf|error|failed)" | grep -v "DeprecationWarning"

# Telegraf error log file
kubectl exec -n kube-system <pod> -c <container> -- cat /var/opt/microsoft/docker-cimprov/log/telegraf_error.log 2>/dev/null
```

#### 8d: Check Data Flow Ports

| Pipeline | Port | Expected Listener |
|----------|------|-------------------|
| DS perf metrics | `25226` | fluent-bit (ama-logs container) |
| MDM custom metrics | `25228` | **fluentd** (ama-logs container) |
| Sidecar prom metrics | `25229` | fluent-bit (ama-logs-prometheus container) |

```bash
kubectl exec -n kube-system <pod> -c <container> -- bash -c 'netstat -tlnp 2>/dev/null | grep -E "25226|25228|25229"'
```

#### 8e: Investigate Data Volume Regression

Follow the same investigation procedure as the backdoor-deployment skill:
1. Break down by `ContainerName` to identify which container(s) are responsible.
2. Compare per-container breakdown between prod and test.
3. Classify as code regression vs cluster workload difference.

---

## Pre-flight Version Check

Before starting any scenario, verify the telegraf version:

```bash
# Linux daemonset
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- /opt/telegraf --version

# Linux sidecar
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- /opt/telegraf --version

# Windows (if present)
kubectl exec -n kube-system <ama-logs-windows-pod> -- powershell -c "C:\opt\telegraf\telegraf.exe --version"
```

Record all versions. Note that Windows may run a **different telegraf version** than Linux.

## Deprecation Check

After deploying the test image, check for deprecation warnings:

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  timeout 10 /opt/telegraf --config /etc/opt/microsoft/docker-cimprov/telegraf.conf --debug 2>&1 | \
  grep -i "deprecat" | sort -u
```

Record all warnings. Key deprecations to track:
- `fieldpass` → `fieldinclude` (deprecated since 1.29.0, removal planned for 1.40.0)
- `fielddrop` → `fieldexclude` (same timeline)
- Any new deprecations introduced in the upgraded version

---

## Windows Tests

If the cluster has Windows nodes with `ama-logs-windows-*` pods, repeat the comparison workflow for Windows-specific data.

**Additional Windows-specific checks** (only if comparison fails):
- Windows telegraf config uses `response_timeout` instead of `timeout` (older telegraf version)
- Windows config path: `C:\etc\telegraf\telegraf.conf`
- Windows reference app: `test/prometheus-scraping/win-prometheus-ref-app-ltsc2022.yml`

---

## Cleanup

After all scenarios complete:

1. **Restore the original configmap**:
   ```bash
   kubectl apply -f /tmp/configmap-backup.yaml
   ```

2. **Restore the production image** in the YAML file and redeploy.

3. **Delete test resources**:
   ```bash
   kubectl delete -f test/prometheus-scraping/prometheus-reference-app.yaml -n prom-test --ignore-not-found
   kubectl delete namespace prom-test --ignore-not-found
   ```

4. **Remove backup files**:
   ```bash
   rm -f /tmp/configmap-backup.yaml
   ```

---

## Summary Report Format

Write the final summary to `TelegrafTestOutput.md`:

```markdown
## Telegraf Upgrade Test Results

**Prod Image**: <prod image tag>
**Test Image**: <test image tag>
**Telegraf Version (Prod)**: <version>
**Telegraf Version (Test)**: <version>
**Cluster**: <cluster name>
**Date**: <timestamp>

### Scenario Results

| Scenario | Config | InsightsMetrics | Perf | Result | Notes |
|----------|--------|-----------------|------|--------|-------|
| 1. Default | No custom prom | MATCH/DIFF | MATCH/DIFF | PASS/FAIL | details |
| 2. Pod Scraping | monitor_kubernetes_pods=true | MATCH/DIFF | MATCH/DIFF | PASS/FAIL | details |
| 3. Namespace Filter | monitor_kubernetes_pods_namespaces | MATCH/DIFF | MATCH/DIFF | PASS/FAIL | details |
| 4. Custom URLs | node urls | MATCH/DIFF | MATCH/DIFF | PASS/FAIL | details |
| 5. Field Filtering | fieldpass/fielddrop | MATCH/DIFF | MATCH/DIFF | PASS/FAIL | details |
| 6. Label Selectors | kubernetes_label_selector | MATCH/DIFF | MATCH/DIFF | PASS/FAIL | details |
| 7. Process Metrics | collect_ama_logs_process_metrics | MATCH/DIFF | MATCH/DIFF | PASS/FAIL | details |

### Investigation Details (only for failed scenarios)
- Scenario X: <root cause analysis>

### Deprecation Warnings
- List all deprecation warnings with removal timeline

### Overall Result: PASS / FAIL
```

## Important Rules

- **Compare with production baseline** — never evaluate test data in isolation. Always deploy prod first, collect baseline, then deploy test and compare.
- **Only investigate internally on mismatch** — if Log Analytics data matches between prod and test, the upgrade is valid. Don't check telegraf processes, configs, or ports unless something is wrong.
- **Apply different configmaps per scenario** — each scenario tests a different telegraf feature by changing the agent configmap.
- **Restore everything at the end** — configmap, YAML image tags, test namespaces.
- **Windows and Linux may differ** — test and report separately.
- **Ingestion latency** — wait 15 minutes after deployment. Query window is deploy+5 to deploy+10 to capture steady-state data.
- **`container.azm.ms/kubestate`** is NOT a telegraf metric — do not include in telegraf comparison.
- **Port 25228** is consumed by **fluentd**, not fluent-bit — only relevant during investigation.
- **Process metrics** use `outputs.application_insights`, NOT `socket_writer`/fluent-bit — separate pipeline.
