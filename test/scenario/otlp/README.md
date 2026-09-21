# OTLP onboarding and validation

Onboard a cluster for the OTLP receivers, then confirm the data lands in Log Analytics and the
Azure Monitor Workspace. Section 3 has optional synthetic workloads if you don't already have an
instrumented app.

> **Logs/traces and metrics are different pipelines** — different backend, different query
> language. Validate them separately; this is the most common source of confusion.
>
> ```
> logs + traces  ->  ama-logs 28331/28332  ->  DCR routed by microsoft.applicationId
>                ->  Log Analytics, tables OTelLogs / OTelSpans          (KQL)
>
> metrics        ->  ama-metrics-node 28333/28334
>                ->  Azure Monitor Workspace                             (PromQL)
> ```

---

## 1. Onboard the cluster

OpenTelemetry preview support doc: https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-open-protocol

The flags ship in a CLI build that isn't released yet — see
[`AZURE-CLI-BUGBASH.md`](./AZURE-CLI-BUGBASH.md) for install steps (and the `aks-preview`
shadowing gotcha), then:

```bash
# 28331 / 28332 -- OTLP logs and traces. Needs Azure Monitor logs.
az aks update -g <rg> -n <cluster> \
  --enable-azure-monitor-logs --enable-opentelemetry-logs-traces

# 28333 / 28334 -- OTLP metrics. Needs Azure Monitor METRICS, not logs.
az aks update -g <rg> -n <cluster> \
  --enable-azure-monitor-metrics --enable-opentelemetry-metrics
```

Both can be on at once. Omit the port flags to get the 28331-28334 defaults.

**Confirm the host ports appeared** — they only exist once the feature is on:

```bash
kubectl get ds ama-logs -n kube-system \
  -o jsonpath='{range .spec.template.spec.containers[*].ports[*]}{.name}{" -> "}{.hostPort}{"\n"}{end}' \
  | grep otlp

kubectl get ds ama-metrics-node -n kube-system \
  -o jsonpath='{range .spec.template.spec.containers[*].ports[*]}{.name}{" -> "}{.hostPort}{"\n"}{end}' \
  | grep otlp
```

| Host port | DaemonSet | Port name | Container port |
| --- | --- | --- | --- |
| 28331 | `ama-logs` | `otlp-logs` | 4319 |
| 28332 | `ama-logs` | `otlp-logs-grpc` | 4320 |
| 28333 | `ama-metrics-node` | `otlp-http-port` | 56681 |
| 28334 | `ama-metrics-node` | `otlp-grpc-port` | 56680 |

Missing `otlp-logs*` means `--enable-opentelemetry-logs-traces` never applied; missing
`otlp-*-port` means `--enable-opentelemetry-metrics` isn't on. Data starts flowing on its own once
the agent re-rolls with the flag set.

---

## 2. Validate the data

All of this runs in the portal — no CLI needed. Allow **5-10 minutes** after traffic starts;
ingestion latency dominates.

### 2.1 Find the workspace and AMW

App Monitoring provisions a managed resource group per app id, named
`ai_<ai-name>_<app-id>_managed`. Search the portal for your **Application Insights app id** and
open that resource group — it holds everything the data flows into:

| Resource | Used for |
| --- | --- |
| `managed-<name>-ws` | Log Analytics workspace — logs and traces (KQL) |
| `managed-<name>-amw` | Azure Monitor Workspace — metrics (PromQL) |
| `managed-<name>-dce` / `-dcr` | ingestion endpoint and routing rule |

Routing is driven **entirely** by the `microsoft.applicationId` resource attribute on the
telemetry, so the app id decides which workspace the data lands in.

- **Logs and traces** — open `managed-<name>-ws` -> **Logs**, then paste the KQL below.
- **Metrics** — open `managed-<name>-amw` -> **Prometheus explorer** -> **Query** (or a Grafana
  panel pointed at the AMW), then paste the PromQL below.

### 2.2 Logs — Log Analytics (KQL)

> OTLP lands in the **native OTel tables**, not the legacy Application Insights ones. Querying
> `AppTraces` / `AppRequests` returns nothing and looks exactly like total failure. The tables are
> `OTelLogs`, `OTelSpans`, `OTelEvents`, `OTelResources`.

Orient first — what actually arrived:

```kusto
search *
| where TimeGenerated > ago(30m)
| summarize count() by $table
```

Are logs arriving, and through which receiver:

```kusto
OTelLogs
| where TimeGenerated > ago(30m)
| summarize Records=count(),
            Transport=any(tostring(Attributes['otlp.transport'])),
            Port=any(tostring(Attributes['otlp.target.port']))
    by ServiceName, ServiceNamespace
```

Read actual records:

```kusto
OTelLogs
| where TimeGenerated > ago(30m)
| project TimeGenerated, ServiceName, ServiceNamespace, SeverityText, Body, Attributes
| order by TimeGenerated desc
| take 50
```

Ingestion over time — a flat or dropping line means the flow stopped:

```kusto
OTelLogs
| where TimeGenerated > ago(1h)
| summarize count() by bin(TimeGenerated, 1m), ServiceName
| render timechart
```

Per-node coverage. Resource attributes are dropped on this pipeline, so node identity only
survives inside the log body (this form matches the section 3 workloads):

```kusto
OTelLogs
| where TimeGenerated > ago(30m)
| extend Node = extract('from (.+)$', 1, Body)
| summarize Records=count() by ServiceName, Node
```

### 2.3 Traces — Log Analytics (KQL)

Are spans arriving:

```kusto
OTelSpans
| where TimeGenerated > ago(30m)
| summarize Spans=count(), Traces=dcount(TraceId),
            Transport=any(tostring(Attributes['otlp.transport']))
    by ServiceName, ServiceNamespace
```

Span shape — parent/child kinds should both appear:

```kusto
OTelSpans
| where TimeGenerated > ago(30m)
| summarize count() by ServiceName, Name, Kind
```

Walk a single trace end to end:

```kusto
OTelSpans
| where TimeGenerated > ago(30m)
| take 1
| project TraceId
```

```kusto
OTelSpans
| where TimeGenerated > ago(30m)
| where TraceId == "<paste-trace-id>"
| project TimeGenerated, Name, Kind, SpanId, ParentSpanId, Duration
| order by TimeGenerated asc
```

Using the section 3 workloads, `Spans` should land around **4x** `Traces` — telemetrygen emits
one parent plus three children per trace.

> Spans carry no node identity downstream, so per-node attribution isn't available for traces.

### 2.4 Metrics — Azure Monitor Workspace (PromQL)

Metrics never reach Log Analytics. Substitute your own metric name; the section 3 workloads
produce `otlp_{http,grpc}_{gauge,sum,histogram}`.

```promql
count(otlp_http_gauge)                                  # series count = node count
count by ("k8s.node.name") (otlp_http_gauge)            # which nodes report
time() - timestamp(otlp_http_gauge)                     # freshness, healthy < ~60s
sum(rate(otlp_http_sum[5m]))                            # ingestion rate
sum by ("k8s.node.name") (otlp_http_histogram)          # histogram, per node
count by ("otlp.transport","otlp.target.port") (otlp_http_gauge)   # which receiver handled it
count by ("microsoft.appresourceid") (otlp_http_gauge)  # routing proof
absent(otlp_http_gauge)                                 # 1 when missing -- alert-shaped
```

> **Two AMW-specific syntax rules.** Dotted label names must be quoted —
> `sum by ("k8s.node.name")` — or you get `parse error: unexpected character inside braces: '.'`.
> And `__name__` only supports `=`, never `=~`, so discovery queries like `{__name__=~"otlp_.*"}`
> fail; name each metric explicitly.

> Query histograms by their **base name**. They're stored as a single series, so `_count` /
> `_sum` / `_bucket` resolve to nothing — and with no `le` buckets,
> **`histogram_quantile()` silently returns meaningless numbers** rather than erroring.

---

## 3. Optional: synthetic test workloads

Four DaemonSets covering the **signal x transport** matrix, each pushing telemetry at its own
node and tagged so you can prove which receiver handled it. The generator is
[`telemetrygen`](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/telemetrygen).

| Workload | Namespace | Signals | Transport | Target | Receiver |
| --- | --- | --- | --- | --- | --- |
| `01-otlp-http-logs-traces.yaml` | `otlp-http` | logs, traces | HTTP/protobuf | `<nodeIP>:28331` | `ama-logs` |
| `02-otlp-grpc-logs-traces.yaml` | `otlp-grpc` | logs, traces | gRPC | `<nodeIP>:28332` | `ama-logs` |
| `03-otlp-http-metrics.yaml` | `otlp-http` | metrics | HTTP/protobuf | `<nodeIP>:28333` | `ama-metrics-node` |
| `04-otlp-grpc-metrics.yaml` | `otlp-grpc` | metrics | gRPC | `<nodeIP>:28334` | `ama-metrics-node` |

### 3.1 Set your Application Insights app id

Get this wrong and data silently goes to someone else's backend, or nowhere. Each namespace ships
with a default that you must replace — `AI_APP_ID` is the only place the value is written, so one
substitution per file is enough:

```bash
cd test/scenario/otlp
sed -i 's/dc577961-1e7f-4715-a9fd-5fb35ae76911/<your-http-app-id>/g' \
  01-otlp-http-logs-traces.yaml 03-otlp-http-metrics.yaml
sed -i 's/cfcfab17-8114-4a2f-94a6-a0ae5f186c14/<your-grpc-app-id>/g' \
  02-otlp-grpc-logs-traces.yaml 04-otlp-grpc-metrics.yaml
```

Using two different app ids lets you prove the agent keeps the namespaces separate (3.3).

If you changed the receiver ports in section 1, update `--otlp-endpoint` and the
`otlp.target.port` attribute in the YAMLs to match.

### 3.2 Deploy

```bash
kubectl apply -f test/scenario/otlp/00-namespaces.yaml
kubectl apply -f test/scenario/otlp/

kubectl get pods -n otlp-http -o wide
kubectl get pods -n otlp-grpc -o wide
```

Expect one pod per Linux node per DaemonSet, `Running`, `0` restarts. The metrics DaemonSets run
**three containers** each (`gauge`, `sum`, `histogram`).

> Pods stay `Running` even when nothing is listening — every generator sets
> `--allow-export-failures`. **Green pods are not evidence of working ingestion**; confirm with
> section 2.

### 3.3 Confirm the namespaces stay separate

The point of two app ids is proving the agent doesn't cross-wire them. Run each check against the
*other* backend and expect nothing back.

In the `otlp-http` workspace (and the mirror image in the `otlp-grpc` one) — expect `0`:

```kusto
OTelLogs
| where TimeGenerated > ago(30m)
| where ServiceNamespace == 'otlp-grpc'
| count
```

In the Prometheus explorer, each AMW must not see the other's series — `No data` is the pass:

```promql
otlp_grpc_gauge    # on the otlp-http AMW -> must return No data
otlp_http_gauge    # on the otlp-grpc AMW -> must return No data
```

---

## 4. Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| No host ports on the DaemonSet | feature not enabled — recheck section 1 |
| Pods `Running`, no data anywhere | receiver not listening; `--allow-export-failures` hides it |
| Data in the wrong workspace | wrong app id; check `microsoft.appresourceid` on the metrics side |
| `AppTraces` / `AppRequests` empty | wrong tables — use `OTelLogs` / `OTelSpans` |
| `OTelLogs` empty shortly after deploy | ingestion lag; wait 5-10 min |
| Metric query returns 0 series | use the base name; `_count`/`_sum`/`_bucket` don't resolve |
| PromQL parse error inside braces | dotted label needs quoting — `{"k8s.node.name"="..."}` |
| `Metric name only support equality(=) filter` | `__name__` can't take a regex in AMW |
| `ResourceAttributes` is `None` on logs/traces | expected — that pipeline drops resource attributes |

---

## 5. Clean up

```bash
kubectl delete ns otlp-http otlp-grpc
```

---

## Notes

- Generators default to `--rate=5`/sec with `--workers=1` and run forever. Raise them (and the CPU
  limit) via `kubectl edit -n otlp-http ds/otlp-http-logs-gen` for more volume.
- `telemetrygen` publishes **Linux-only** images, so every workload pins
  `nodeSelector: kubernetes.io/os: linux`. Windows receivers must be driven from a Linux generator
  aimed at the Windows node IP.
- `telemetrygen` does **not** read `OTEL_RESOURCE_ATTRIBUTES` — it's a synthetic client, not
  SDK-instrumented. That env var exists so the workload looks instrumented to the admission
  webhook; what reaches the wire comes from `--otlp-attributes` / `--service`. **Keep the two in
  sync when editing**, or validation will disagree with the manifest.
- Clusters with Azure Policy image restrictions emit a `k8sazurev2customcontainerallow` warning for
  the `ghcr.io` image — a warning unless the policy denies, in which case mirror the image.
