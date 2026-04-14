---
name: test-telegraf-upgrade
description: "Test a Telegraf upgrade end-to-end on a live AKS cluster. Validates config parsing, placeholder substitution, plugin loading, data flow, and feature parity across daemonset, replicaset, and sidecar containers for both custom and default configurations. Use when someone says 'test telegraf upgrade', 'validate telegraf', 'telegraf regression test', or 'verify telegraf version'."
argument-hint: "Provide the cluster context name or YAML file path for the target cluster"
---

# Test Telegraf Upgrade

Validates that a new Telegraf version works correctly across all container types (daemonset, replicaset, sidecar) and all feature areas (default metrics, custom prometheus scraping, integrations, process metrics).

## Data Flow Overview

Telegraf has **three distinct output pipelines** in this repo:

| Pipeline | Port | Listener | Config | Purpose |
|----------|------|----------|--------|---------|
| DS perf metrics | `25226` | fluent-bit (ama-logs) | `telegraf.conf` | Disk, diskio, net, kubelet metrics → InsightsMetrics |
| MDM custom metrics | `25228` | **fluentd** (ama-logs) | `telegraf.conf` / `telegraf-rs.conf` | Custom MDM metrics via `container-cm.conf` |
| Sidecar prom metrics | `25229` | fluent-bit (ama-logs-prometheus) | `telegraf-prom-side-car.conf` | Custom prometheus scraping → InsightsMetrics |
| Process metrics | N/A | **Application Insights** (direct) | `telegraf-ama-logs-process-metrics.conf` | `inputs.procstat` → `outputs.application_insights` |

## Required Inputs

| Input | Description | Default |
|-------|-------------|---------|
| **Cluster context** | kubectl context for the AKS cluster | Current context |
| **YAML file path** | Helm values file (to extract cluster resource ID and workspace ID) | `./../azuremonitor-containerinsights-for-prod-clusters/values.yaml` |
| **Wait time** | Minutes to wait for data ingestion after each validation | `15` |

## Derived Values

Parse automatically from the YAML file — do not ask the user.

| Value | Source |
|-------|--------|
| **Cluster Resource ID** | `OmsAgent.aksResourceID` |
| **Log Analytics Workspace ID** | `OmsAgent.workspaceID` |
| **Cluster Name** | Last segment of the cluster resource ID |

## General Rules

- Save the output of **each test** to `TelegrafTestOutput.md` in the repo root. Always append new results at the end. Mark each test as PASS / FAIL / SKIP with details.
- Run tests in the order listed. Some tests depend on earlier steps confirming pods are healthy.
- If a test fails, continue with remaining tests and report all results at the end.
- Use `az monitor log-analytics query -w <workspaceId>` for Kusto queries.

---

## Phase 1: Pre-flight Checks

### Test 1.1: Verify Telegraf Version

Check the telegraf binary version in each container type.

```bash
# Daemonset
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- /opt/telegraf --version

# Replicaset
kubectl exec -n kube-system <ama-logs-rs-pod> -c ama-logs -- /opt/telegraf --version

# Sidecar
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- /opt/telegraf --version
```

**Expected**: All report the same new version. Record the version.

### Test 1.2: Verify Pod Health

```bash
kubectl get pods -n kube-system | grep ama-logs
```

**Expected**: All ama-logs pods are `Running` with `0` restarts. Record pod names for each type:
- `ama-logs-*` (daemonset, 3/3 containers: addon-token-adapter, ama-logs, ama-logs-prometheus)
- `ama-logs-rs-*` (replicaset, 2/2 containers: addon-token-adapter, ama-logs)
- `ama-logs-windows-*` (windows daemonset, if present)

### Test 1.3: Verify Telegraf Processes Running

Check that telegraf is running in each container that should have it:

```bash
# Daemonset - ama-logs container (runs telegraf for DS metrics)
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- ps aux | grep telegraf | grep -v grep

# Sidecar - ama-logs-prometheus container (runs telegraf for custom prom scraping)
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- ps aux | grep telegraf | grep -v grep

# Replicaset - ama-logs container (may be disabled if no custom RS config)
kubectl exec -n kube-system <ama-logs-rs-pod> -c ama-logs -- ps aux | grep telegraf | grep -v grep
```

**Expected**: Telegraf process running in DS and sidecar containers. RS telegraf may be disabled if no custom RS prom config is set — check `TELEMETRY_RS_TELEGRAF_DISABLED` env var. If RS telegraf is disabled, mark RS-specific tests as SKIP.

---

## Phase 2: Config Parsing Tests

These tests verify that the ruby config parsers correctly substitute all placeholders and that telegraf can parse the result.

### Test 2.1: Daemonset Telegraf Config — No Raw Placeholders

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  grep '\$AZMON' /etc/opt/microsoft/docker-cimprov/telegraf.conf
```

**Expected**: No output (exit code 1). Placeholders that must be substituted:
- `$AZMON_DS_PROM_INTERVAL` → interval value (default: `1m`)
- `$AZMON_DS_PROM_URLS` → URL array (default: `[]`)
- `$AZMON_DS_PROM_FIELDPASS` → field array (default: `[]`)
- `$AZMON_DS_PROM_FIELDDROP` → field array (default: `[]`)
- `$AZMON_INTEGRATION_NPM_METRICS_URL_LIST_NODE` → URL array (default: `[]`)
- `$AZMON_INTEGRATION_SUBNET_IP_USAGE_METRICS_URL_LIST_NODE` → URL array (default: `[]`)

### Test 2.2: Sidecar Telegraf Config — No Raw Placeholders

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  grep '\$AZMON' /etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf
```

**Expected**: No output. Placeholders that must be substituted:
- `$AZMON_TELEGRAF_CUSTOM_PROM_INTERVAL` → interval (default: `1m`)
- `$AZMON_TELEGRAF_CUSTOM_PROM_MONITOR_PODS` → `monitor_kubernetes_pods = true/false`
- `$AZMON_TELEGRAF_CUSTOM_PROM_SCRAPE_SCOPE` → `pod_scrape_scope = 'node'`
- `$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_LABEL_SELECTOR` → `kubernetes_label_selector = ''`
- `$AZMON_TELEGRAF_CUSTOM_PROM_KUBERNETES_FIELD_SELECTOR` → `kubernetes_field_selector = ''`
- `$AZMON_TELEGRAF_CUSTOM_PROM_FIELDPASS` → field array (default: `[]`)
- `$AZMON_TELEGRAF_CUSTOM_PROM_FIELDDROP` → field array (default: `[]`)
- `$AZMON_TELEGRAF_CUSTOM_PROM_PLUGINS_WITH_NAMESPACE_FILTER` → empty or plugin blocks
- `$AZMON_TELEGRAF_OSM_PROM_PLUGINS` → empty or OSM plugin blocks

### Test 2.3: Replicaset Telegraf Config — No Raw Placeholders

```bash
kubectl exec -n kube-system <ama-logs-rs-pod> -c ama-logs -- \
  grep '\$AZMON' /etc/opt/microsoft/docker-cimprov/telegraf-rs.conf
```

**Expected**: No output. Same custom prom placeholders as sidecar, plus:
- `$AZMON_TELEGRAF_CUSTOM_PROM_URLS` → URL array (default: `[]`)
- `$AZMON_TELEGRAF_CUSTOM_PROM_K8S_SERVICES` → services array (default: `[]`)
- `$AZMON_INTEGRATION_NPM_METRICS_URL_LIST_CLUSTER` → URL array (default: `[]`)
- `$AZMON_INTEGRATION_NPM_METRICS_DROP_LIST_CLUSTER` → drop list (default: `[]`)
- `$AZMON_TELEGRAF_OSM_PROM_PLUGINS` → empty or OSM plugin blocks

### Test 2.4: Telegraf Config Test Mode

Verify that telegraf can parse its config file in test mode (the same check that `main.sh` runs at startup):

```bash
# Daemonset
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  /opt/telegraf --config /etc/opt/microsoft/docker-cimprov/telegraf.conf --input-filter file -test

# Sidecar
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  /opt/telegraf --config /etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf --input-filter file -test

# Replicaset
kubectl exec -n kube-system <ama-logs-rs-pod> -c ama-logs -- \
  /opt/telegraf --config /etc/opt/microsoft/docker-cimprov/telegraf-rs.conf --input-filter file -test
```

**Expected**: Exit code `0` for all. Deprecation warnings are acceptable but should be recorded:
- `DeprecationWarning: Option "fieldpass" deprecated since version 1.29.0` (expected until migrated to `fieldinclude`)

### Test 2.5: Startup Log and Error File Check

Check container logs AND telegraf error log files for errors:

```bash
# Daemonset container logs
kubectl logs -n kube-system <ama-logs-ds-pod> -c ama-logs | grep -iE "(telegraf|error|failed)" | grep -v "DeprecationWarning"

# Sidecar container logs
kubectl logs -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus | grep -iE "(telegraf|error|failed)" | grep -v "DeprecationWarning"

# Sidecar telegraf error log file (telegraf may log errors here instead of stdout)
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  cat /var/opt/microsoft/docker-cimprov/log/telegraf_error.log 2>/dev/null

# Daemonset telegraf error log file
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  cat /var/opt/microsoft/docker-cimprov/log/telegraf_error.log 2>/dev/null
```

**Expected**: No errors related to telegraf config loading or startup. Acceptable messages:
- `DeprecationWarning` for `fieldpass` → `fieldinclude`
- `Strict environment variable handling is the new default` (informational)

**FAIL if any of these appear**:
- `error parsing data: line NNN: invalid TOML syntax` — unsubstituted placeholder
- `loading config file ... failed` — config parse failure

---

## Phase 3: Default Feature Tests

These validate the built-in metrics that telegraf collects without any custom configuration.

### Test 3.1: Kubelet Metrics (Daemonset)

The daemonset collects kubelet metrics via `inputs.prometheus` from the node's kubelet endpoint.

```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace == "container.azm.ms/prometheus"
| where _ResourceId =~ '<clusterResourceId>'
| extend parsedTags = parse_json(Tags)
| where tostring(parsedTags['scrapeUrl']) contains "10250"
| summarize Count=count() by Name
| order by Count desc
```

**Expected**: Data for these metrics (collected from kubelet `/metrics` endpoint):
- `volume_manager_total_volumes`
- `kubelet_runtime_operations_total` (or `kubelet_runtime_operations`)
- `kubelet_running_pods` (or `kubelet_running_pod_count`)
- `process_resident_memory_bytes`
- `process_cpu_seconds_total`
- `kubelet_node_config_error`

### Test 3.2: Disk Metrics (Daemonset)

```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace == "container.azm.ms/disk"
| where _ResourceId =~ '<clusterResourceId>'
| summarize Count=count() by Name
| order by Count desc
```

**Expected**: Disk metrics present (e.g., `used_percent`, `free`, `used`, `total`).

### Test 3.3: Disk IO Metrics (Daemonset)

```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace == "container.azm.ms/diskio"
| where _ResourceId =~ '<clusterResourceId>'
| summarize Count=count() by Name
| order by Count desc
```

**Expected**: DiskIO metrics present (e.g., `read_bytes`, `write_bytes`, `reads`, `writes`).

### Test 3.4: Network Metrics (Daemonset)

```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace == "container.azm.ms/net"
| where _ResourceId =~ '<clusterResourceId>'
| summarize Count=count() by Name
| order by Count desc
```

**Expected**: Network metrics present (e.g., `bytes_sent`, `bytes_recv`, `err_in`, `err_out`).

### Test 3.5: Network Loopback Filter

Verify loopback interface metrics are filtered out (regression introduced in telegraf 1.34.3):

```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace == "container.azm.ms/net"
| where _ResourceId =~ '<clusterResourceId>'
| extend parsedTags = parse_json(Tags)
| where tostring(parsedTags['interface']) == "lo"
| summarize Count=count()
```

**Expected**: Count is `0` — loopback data should be filtered by the `tagdrop` rule in the telegraf config.

### Test 3.6: All Telegraf Namespace Summary

Verify all telegraf-sourced namespaces have data flowing:

```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where _ResourceId =~ '<clusterResourceId>'
| where Namespace startswith "container.azm.ms/"
| where Namespace !contains "kubestate"
| summarize
    MinTime = min(TimeGenerated),
    MaxTime = max(TimeGenerated),
    Count = count()
  by Namespace
| extend LatencyMinutes = datetime_diff('minute', now(), MaxTime)
| order by Count desc
```

**Expected namespaces** (all telegraf-sourced):
- `container.azm.ms/prometheus` (kubelet + custom prom metrics)
- `container.azm.ms/disk`
- `container.azm.ms/diskio`
- `container.azm.ms/net`

All should have `LatencyMinutes` < 15 and non-zero count.

> **Note**: `container.azm.ms/kubestate` is NOT a telegraf metric — it comes from fluent kubestate plugins. Do not include it in telegraf validation.

---

## Phase 4: Custom Feature Tests

These validate telegraf features enabled through the agent configmap.

### Test 4.1: Pod-level Prometheus Scraping (Sidecar)

Deploy the prometheus reference app:

```bash
kubectl create namespace prom-test --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f test/prometheus-scraping/prometheus-reference-app.yaml -n prom-test
```

Verify the pod has correct annotations and is running:
```bash
kubectl get pod -n prom-test -l app=prometheus-reference-app \
  -o jsonpath='{.items[0].metadata.annotations}'
```

**Expected annotations**:
- `prometheus.io/scrape: "true"`
- `prometheus.io/port: "2112"`

Verify the reference app pod is on the same node as one of the ama-logs daemonset pods (required for `pod_scrape_scope = "node"`):
```bash
kubectl get pod -n prom-test -o wide
kubectl get pods -n kube-system -o wide | grep ama-logs
```

Check the sidecar telegraf config has `monitor_kubernetes_pods = true`:
```bash
kubectl exec -n kube-system <ama-logs-ds-pod-on-same-node> -c ama-logs-prometheus -- \
  grep "monitor_kubernetes_pods" /etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf
```

Wait for data (15 min ingestion latency), then query:
```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace == "container.azm.ms/prometheus"
| where _ResourceId =~ '<clusterResourceId>'
| extend parsedTags = parse_json(Tags)
| where tostring(parsedTags['scrapeUrl']) contains "2112"
| summarize Count=count() by bin(TimeGenerated, 5m), Name
| order by TimeGenerated desc
| take 20
```

**Expected**: Metrics from the reference app (weather-related metrics from the golang container on port 2112).

### Test 4.2: Pod Scrape Scope

Verify `pod_scrape_scope` is set correctly:
```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  grep "pod_scrape_scope" /etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf
```

**Expected**: `pod_scrape_scope = "node"` for sidecar (each daemonset scrapes pods on its own node).

### Test 4.3: Namespace Filtering

If `monitor_kubernetes_pods_namespaces` is configured in the configmap, verify namespace-scoped prometheus input plugins are generated:

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  grep "monitor_kubernetes_pods_namespace" /etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf
```

**Expected**: If namespace filtering is configured, each namespace gets its own `[[inputs.prometheus]]` block with `monitor_kubernetes_pods_namespace = "<ns>"`. If not configured, the single plugin block scrapes all namespaces.

### Test 4.4: Field Filtering

Verify `fieldpass` and `fielddrop` are valid TOML arrays (not raw placeholder strings):

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  grep -E "fieldpass|fielddrop" /etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf

kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  grep -E "fieldpass|fielddrop" /etc/opt/microsoft/docker-cimprov/telegraf.conf
```

**Expected**: Values are valid TOML arrays like `[]` or `["metric1","metric2"]`, not raw `$AZMON_*` strings.

### Test 4.5: TLS and Authentication Settings

Verify TLS settings are present in prometheus input blocks:

```bash
# Sidecar config
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  grep -E "tls_ca|insecure_skip_verify|timeout" /etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf

# Daemonset config
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  grep -E "bearer_token|tls_ca|insecure_skip_verify|timeout" /etc/opt/microsoft/docker-cimprov/telegraf.conf
```

**Expected for sidecar** (bearer_token is commented out in the sidecar template):
- `tls_ca = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"`
- `insecure_skip_verify = true`
- `timeout = "15s"`

**Expected for daemonset**:
- `bearer_token = "/var/run/secrets/kubernetes.io/serviceaccount/token"`
- `tls_ca = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"`
- `insecure_skip_verify = true`

### Test 4.6: Kubernetes Label and Field Selectors

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  grep -E "kubernetes_label_selector|kubernetes_field_selector" /etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf
```

**Expected**: Both selectors present with valid string values (empty string `""` by default).

### Test 4.7: Daemonset Custom URL Scraping

Check if custom URLs are configured in the DS telegraf config:

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  grep -A2 "AZMON_DS_PROM" /etc/opt/microsoft/docker-cimprov/telegraf.conf || \
  grep "urls = " /etc/opt/microsoft/docker-cimprov/telegraf.conf | head -5
```

If custom URLs are configured (not `[]`), verify data is flowing for those endpoints:

```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace == "container.azm.ms/prometheus"
| where _ResourceId =~ '<clusterResourceId>'
| extend parsedTags = parse_json(Tags)
| where tostring(parsedTags['scrapeUrl']) !contains "10250"
| summarize Count=count() by tostring(parsedTags['scrapeUrl'])
| order by Count desc
```

**Expected**: If custom URLs are configured, data should appear from those scrape URLs. If `urls = []`, mark as SKIP.

### Test 4.8: Replicaset Custom Config

Check if RS has custom prometheus configuration:

```bash
kubectl exec -n kube-system <ama-logs-rs-pod> -c ama-logs -- \
  grep -E "urls = |kubernetes_services = " /etc/opt/microsoft/docker-cimprov/telegraf-rs.conf | head -5
```

If `urls` or `kubernetes_services` are configured (not `[]`), and RS telegraf is running, verify data flows. Mark as SKIP if RS telegraf is disabled.

---

## Phase 5: Integration Tests

### Test 5.1: OSM Placeholder Substitution

Verify `$AZMON_TELEGRAF_OSM_PROM_PLUGINS` is substituted in both sidecar and RS configs:

```bash
# Sidecar
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  grep "AZMON_TELEGRAF_OSM" /etc/opt/microsoft/docker-cimprov/telegraf-prom-side-car.conf

# Replicaset
kubectl exec -n kube-system <ama-logs-rs-pod> -c ama-logs -- \
  grep "AZMON_TELEGRAF_OSM" /etc/opt/microsoft/docker-cimprov/telegraf-rs.conf
```

**Expected**: No output (placeholder has been replaced with empty string or OSM plugin blocks).

If OSM namespaces are configured, verify OSM data is flowing:
```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where Namespace startswith "container.azm.ms.osm/"
| where _ResourceId =~ '<clusterResourceId>'
| summarize Count=count() by Name
| order by Count desc
```

### Test 5.2: NPM Integration

Check substitution:
```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  grep "AZMON_INTEGRATION_NPM" /etc/opt/microsoft/docker-cimprov/telegraf.conf

kubectl exec -n kube-system <ama-logs-rs-pod> -c ama-logs -- \
  grep "AZMON_INTEGRATION_NPM" /etc/opt/microsoft/docker-cimprov/telegraf-rs.conf
```

**Expected**: No output (all NPM placeholders substituted).

If NPM metrics are enabled (check `TELEMETRY_NPM_INTEGRATION_METRICS_BASIC` or `TELEMETRY_NPM_INTEGRATION_METRICS_ADVANCED` env vars), verify data flow:
```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- bash -c 'echo $TELEMETRY_NPM_INTEGRATION_METRICS_BASIC'
```

### Test 5.3: Subnet IP Usage Substitution

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  grep "AZMON_INTEGRATION_SUBNET" /etc/opt/microsoft/docker-cimprov/telegraf.conf
```

**Expected**: No output (placeholder substituted).

### Test 5.4: AMA Logs Process Metrics

Check if process metrics collection is enabled:
```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  bash -c 'echo $AZMON_COLLECT_AMA_LOGS_PROCESS_METRICS'
```

If enabled (`true`):

1. Verify config file exists and is valid:
```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  /opt/telegraf --config /etc/opt/microsoft/docker-cimprov/telegraf-ama-logs-process-metrics.conf --input-filter file -test
```

2. Verify the process metrics telegraf process is running:
```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  ps aux | grep "telegraf-ama-logs-process-metrics" | grep -v grep
```

3. Verify it monitors the expected processes via `inputs.procstat`:
```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  grep -E "exe = |pattern = " /etc/opt/microsoft/docker-cimprov/telegraf-ama-logs-process-metrics.conf
```

**Expected monitored processes** (Linux):
- `mdsd`, `fluent-bit`, `telegraf`, `ruby` (fluentd workers), `crond`, `inotifywait`, `fluentd`, `main.sh`

> **Note**: Process metrics use `outputs.application_insights` (direct send), NOT `socket_writer`/fluent-bit. This is a different pipeline from all other telegraf data.

If disabled, mark as SKIP.

---

## Phase 6: Data Flow Tests

### Test 6.1: DS Perf Pipeline — Socket Writer to Fluent-bit (port 25226)

Verify fluent-bit is listening on port 25226 for telegraf DS perf data:

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  bash -c 'netstat -tlnp 2>/dev/null | grep 25226'
```

**Expected**: fluent-bit listening on `0.0.0.0:25226`.

### Test 6.2: MDM Pipeline — Socket Writer to Fluentd (port 25228)

Verify fluentd is listening on port 25228 for telegraf MDM data:

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  bash -c 'netstat -tlnp 2>/dev/null | grep 25228'
```

**Expected**: fluentd (ruby process) listening on `0.0.0.0:25228`.

> **Note**: Port 25228 is consumed by **fluentd** (via `container-cm.conf`), not fluent-bit. This is the MDM custom metrics path.

### Test 6.3: Sidecar Prom Pipeline — Socket Writer to Fluent-bit (port 25229)

Verify fluent-bit is listening on port 25229 for sidecar telegraf prom data:

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  bash -c 'netstat -tlnp 2>/dev/null | grep 25229'
```

**Expected**: fluent-bit listening on `0.0.0.0:25229` with `-e /opt/fluent-bit/bin/out_oms.so`.

### Test 6.4: Fluent-bit Processes Running

Verify fluent-bit is running in the relevant containers:

```bash
# DS ama-logs container
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  ps aux | grep fluent-bit | grep -v grep

# Sidecar container
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus -- \
  ps aux | grep fluent-bit | grep -v grep
```

**Expected**: fluent-bit running in both containers.

### Test 6.5: End-to-End Data Freshness

```kusto
InsightsMetrics
| where TimeGenerated > ago(30m)
| where _ResourceId =~ '<clusterResourceId>'
| where Namespace startswith "container.azm.ms/"
| summarize MaxTime = max(TimeGenerated), Count = count() by Namespace
| extend LatencyMinutes = datetime_diff('minute', now(), MaxTime)
| order by LatencyMinutes asc
```

**Expected**: All telegraf namespaces have `LatencyMinutes` < 15.

### Test 6.6: Perf Table Data

Verify Perf table data flows correctly (separate from InsightsMetrics):

```kusto
Perf
| where TimeGenerated > ago(30m)
| where _ResourceId =~ '<clusterResourceId>'
| summarize Count=count() by ObjectName, CounterName
| order by Count desc
| take 20
```

**Expected**: Perf counters present for CPU (`cpuUsageNanoCores`), memory (`memoryWorkingSetBytes`, `memoryRssBytes`).

---

## Phase 7: Deprecation and Compatibility Checks

### Test 7.1: Check for Breaking Deprecations

```bash
kubectl exec -n kube-system <ama-logs-ds-pod> -c ama-logs -- \
  timeout 10 /opt/telegraf --config /etc/opt/microsoft/docker-cimprov/telegraf.conf --debug 2>&1 | \
  grep -i "deprecat" | sort -u
```

**Record all unique deprecation warnings**. Key ones to track:
- `fieldpass` → `fieldinclude` (deprecated since 1.29.0, removal planned for 1.40.0)
- `fielddrop` → `fieldexclude` (same timeline)
- Any **new** deprecations introduced in the upgraded version

### Test 7.2: Strict Environment Variable Handling

Verify no unresolved environment variables cause failures:

```bash
kubectl logs -n kube-system <ama-logs-ds-pod> -c ama-logs | grep -i "strict environment"
kubectl logs -n kube-system <ama-logs-ds-pod> -c ama-logs-prometheus | grep -i "strict environment"
```

**Expected**: At most an informational warning. No actual config loading failures.

---

## Phase 8: Windows Tests (if applicable)

Only run if the cluster has Windows nodes with `ama-logs-windows-*` pods.

### Test 8.1: Windows Telegraf Config — No Raw Placeholders

```bash
kubectl exec -n kube-system <ama-logs-windows-pod> -- \
  powershell -c "Select-String -Path 'C:\etc\telegraf\telegraf.conf' -Pattern 'AZMON'"
```

**Expected**: No output (all placeholders substituted).

### Test 8.2: Windows Telegraf Process

```bash
kubectl exec -n kube-system <ama-logs-windows-pod> -- \
  powershell -c "Get-Process telegraf -ErrorAction SilentlyContinue | Select-Object Id, ProcessName"
```

**Expected**: Telegraf process running.

### Test 8.3: Windows `response_timeout` vs `timeout`

The Windows telegraf config uses `response_timeout` (not `timeout`) because Windows runs an older telegraf version. Verify:

```bash
kubectl exec -n kube-system <ama-logs-windows-pod> -- \
  powershell -c "Select-String -Path 'C:\etc\telegraf\telegraf.conf' -Pattern 'timeout'"
```

**Expected**: Uses `response_timeout`, not bare `timeout`.

### Test 8.4: Windows Telegraf Version

```bash
kubectl exec -n kube-system <ama-logs-windows-pod> -- \
  powershell -c "C:\opt\telegraf\telegraf.exe --version"
```

**Expected**: Reports current Windows telegraf version. Note: Windows and Linux may run **different** telegraf versions.

### Test 8.5: Windows Data Flow

Verify fluent-bit is listening on port 25229 for Windows telegraf data:

```bash
kubectl exec -n kube-system <ama-logs-windows-pod> -- \
  powershell -c "netstat -an | Select-String '25229'"
```

**Expected**: Listening on port 25229.

### Test 8.6: Windows Reference App Scraping

If testing custom prom scraping on Windows, deploy the Windows reference app:

```bash
kubectl apply -f test/prometheus-scraping/win-prometheus-ref-app-ltsc2022.yml
```

Wait for data and query InsightsMetrics for Windows-node scraped metrics. Mark as SKIP if no Windows prom scraping is configured.

---

## Cleanup

After all tests complete:

1. Delete the prometheus reference app if it was deployed for testing:
   ```bash
   kubectl delete -f test/prometheus-scraping/prometheus-reference-app.yaml -n prom-test --ignore-not-found
   kubectl delete namespace prom-test --ignore-not-found
   ```

2. Write the final summary to `TelegrafTestOutput.md`.

---

## Summary Report Format

At the end of all tests, produce a summary table in `TelegrafTestOutput.md`:

```markdown
## Telegraf Upgrade Test Results

**Telegraf Version**: <version>
**Cluster**: <cluster name>
**Date**: <timestamp>

### Test Results

| # | Test | Category | Result | Details |
|---|------|----------|--------|---------|
| 1.1 | Telegraf Version | Pre-flight | PASS/FAIL | version info |
| 1.2 | Pod Health | Pre-flight | PASS/FAIL | restart count |
| 1.3 | Telegraf Processes | Pre-flight | PASS/FAIL | running containers |
| 2.1 | DS Config Placeholders | Config | PASS/FAIL | placeholder count |
| 2.2 | Sidecar Config Placeholders | Config | PASS/FAIL | placeholder count |
| 2.3 | RS Config Placeholders | Config | PASS/FAIL | placeholder count |
| 2.4 | Config Test Mode | Config | PASS/FAIL | exit codes |
| 2.5 | Startup Errors | Config | PASS/FAIL | error details |
| 3.1 | Kubelet Metrics | Default | PASS/FAIL | metric count |
| 3.2 | Disk Metrics | Default | PASS/FAIL | metric count |
| 3.3 | DiskIO Metrics | Default | PASS/FAIL | metric count |
| 3.4 | Network Metrics | Default | PASS/FAIL | metric count |
| 3.5 | Loopback Filter | Default | PASS/FAIL | loopback count |
| 3.6 | Namespace Summary | Default | PASS/FAIL | namespace list |
| 4.1 | Pod Prom Scraping | Custom | PASS/FAIL/SKIP | scrape data |
| 4.2 | Pod Scrape Scope | Custom | PASS/FAIL | scope value |
| 4.3 | Namespace Filtering | Custom | PASS/FAIL/SKIP | filter config |
| 4.4 | Field Filtering | Custom | PASS/FAIL | array format |
| 4.5 | TLS Settings | Custom | PASS/FAIL | setting values |
| 4.6 | Label/Field Selectors | Custom | PASS/FAIL | selector values |
| 4.7 | DS Custom URLs | Custom | PASS/FAIL/SKIP | URL config |
| 4.8 | RS Custom Config | Custom | PASS/FAIL/SKIP | RS config |
| 5.1 | OSM Substitution | Integration | PASS/FAIL | placeholder check |
| 5.2 | NPM Substitution | Integration | PASS/FAIL | placeholder check |
| 5.3 | Subnet IP Substitution | Integration | PASS/FAIL | placeholder check |
| 5.4 | Process Metrics | Integration | PASS/FAIL/SKIP | process list |
| 6.1 | DS Perf Pipeline (25226) | Data Flow | PASS/FAIL | listener check |
| 6.2 | MDM Pipeline (25228) | Data Flow | PASS/FAIL | listener check |
| 6.3 | Sidecar Pipeline (25229) | Data Flow | PASS/FAIL | listener check |
| 6.4 | Fluent-bit Running | Data Flow | PASS/FAIL | process check |
| 6.5 | Data Freshness | Data Flow | PASS/FAIL | latency minutes |
| 6.6 | Perf Table Data | Data Flow | PASS/FAIL | counter count |
| 7.1 | Deprecation Check | Compat | INFO | warning list |
| 7.2 | Strict Env Handling | Compat | PASS/FAIL | error check |
| 8.1-8.6 | Windows Tests | Windows | PASS/FAIL/SKIP | details |

### Deprecation Warnings
- List all deprecation warnings found with removal timeline

### Recommendations
- Any action items based on test results (e.g., migrate fieldpass before version X)
```

## Important Rules

- **Do NOT restart or modify ama-logs pods** — tests are read-only observations.
- **Do NOT modify the agent configmap** — test with the existing configuration.
- **Record all deprecation warnings** — even if tests pass, they indicate future work needed before the next telegraf upgrade.
- **Windows and Linux may run different telegraf versions** — test and report separately.
- **Ingestion latency** — allow 15 minutes for Log Analytics data to appear. If data is missing after 15 minutes, wait an additional 5 minutes before marking as FAIL.
- **The `fieldpass` deprecation** is expected and not a failure. It becomes a blocking issue only when the removal version (1.40.0) is reached.
- **`container.azm.ms/kubestate`** is NOT a telegraf metric — it comes from fluent kubestate plugins. Do not include it in telegraf validation.
- **Process metrics** use `outputs.application_insights`, NOT the `socket_writer`/fluent-bit pipeline. Validate them separately.
- **Port 25228** is consumed by **fluentd** (via `container-cm.conf`), not fluent-bit. Do not confuse with the fluent-bit pipelines on ports 25226 and 25229.
