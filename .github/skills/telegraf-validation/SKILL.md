---
name: telegraf-validation
description: "Validate that an ama-logs change preserves telegraf metric collection. Deploys scenario workloads and a controlled config map, renders the config offline through the real parser, captures an A/B snapshot on the OLD then NEW image, and checks structural invariants (custom-prom scraping, fieldpass/fielddrop, $NODE_IP expansion, per-namespace plugins, disk/diskio/net/kubestate, Perf). Use when: validating a telegraf config or template change, tomlparser change, telegraf version upgrade, custom Prometheus scraping change, InsightsMetrics regression check, telegraf A/B test."
argument-hint: "Provide cluster name/resource ID, OLD image tag, NEW image tag, and how the agent is deployed (managed addon or helm)"
---

# Telegraf Collection Validation

Validates that an ama-logs change preserves telegraf-based metric collection: custom
Prometheus scraping (cluster + node sections), the generated telegraf configuration, and
the non-prom telegraf inputs that feed `InsightsMetrics` and `Perf`.

Use it for any change that can touch the telegraf pipeline — a telegraf version bump, an
edit to a `telegraf*.conf` template, a change to `tomlparser-prom-customconfig.rb` or the
config-map schema, or a fluent-bit/mdsd change that could disturb the metrics path.

**Relationship to the other skills**
- `backdoor-deployment` — aggregate data volume and resource consumption. Complementary.
- `multiline-validation` — the fluent-bit multi-line parser. Complementary.
- `upgrade-telegraf` — *makes* a telegraf version change in `dalec-build-defs`. This skill
  *validates* the resulting image.

Run this one whenever a change could alter what telegraf collects or how its config is generated.

## Required Inputs

| Input | Description | Example |
|-------|-------------|---------|
| **Cluster resource ID** | Full ARM ID of the AKS cluster | `/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<name>` |
| **OLD image tag** | Current production image (the baseline) | `ciprod:3.6.0` |
| **NEW image tag** | Test image from the CI build | `cidev:3.6.1-<branch>-<date>-<sha>` |
| **Deployment mode** | Managed addon, or helm release | `addon` / `helm` |

## Derived Values

Resolve these yourself; do not ask the user.

| Value | How |
|-------|-----|
| **Workspace GUID** | `az aks show ... --query addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID` then `az monitor log-analytics workspace show --query customerId` |
| **Subscription / RG / cluster name** | Parse from the cluster resource ID |
| **DCR + DCRA** | `az monitor data-collection rule association list --resource <clusterResourceId>` |
| **Node internal IPs** | `kubectl get nodes -o wide` — needed to fill `__NODE0_IP__` in the config map |
| **`SIDECAR_SCRAPING_ENABLED`** | From the ama-logs daemonset env — decides whether cluster-section scraping runs in the sidecar or the replicaset |

## General Rules

- Append the output of **each step** to `TelegrafValidationOutput.md` in the repo root. Never clear it unless asked.
- The **config map is the controlled variable.** Apply it once before the OLD snapshot and do not touch it until both snapshots are captured. If it changes mid-run, the comparison is invalid — redo it.
- Use the **same lookback and the same workloads** for both snapshots.
- Wait **at least 15 minutes** after each image swap before querying (pod restart + ingestion latency).
- Compare **structural invariants, not raw record counts.** Counts drift with scrape timing; treat ±15% as noise.
- Restore the cluster at the end (see Cleanup). Record what you changed as you go.

---

## Pre-flight (do these before touching the cluster)

These two checks are cheap and catch the failure modes that otherwise waste a full
30-minute A/B cycle.

### P1 — The DCR must collect metrics, or the whole comparison is vacuous

`build/common/installer/scripts/dcr-config-parser.rb` defines a `@logs_and_events_streams`
set. **If the cluster's DCR contains only those logs-and-events streams, the agent sets
`LOGS_AND_EVENTS_ONLY=true` and suppresses all telegraf/metric collection.**
`InsightsMetrics` is then 0 on both sides and every invariant "passes" while proving nothing.

```bash
az monitor data-collection rule show --ids <dcrId> --query "dataFlows[].streams" -o json
```

Confirm the DCR includes a metrics stream (e.g. `Microsoft-InsightsMetrics`, typically via
the `Microsoft-ContainerInsights-Group-Default` grouping). Read the current
`@logs_and_events_streams` list in `dcr-config-parser.rb` rather than assuming it.

If metrics are missing, fix the DCR first and wait for data before starting.

> The parser runs **once at container start**, and only for the DaemonSet. `livenessprobe.sh`
> gates the DCR re-check on `CONTROLLER_TYPE == DaemonSet`, so only DaemonSet pods
> self-restart on a DCR change; the ReplicaSet recovers when mdsd refreshes its config
> cache (~10–14 min).

### P2 — Render the config map offline through the real parser

Never apply an unvalidated config map. Wrong-but-plausible keys parse cleanly and emit
nothing, which looks identical to a regression.

```bash
# from the repo root; requires the tomlrb version the agent ships
ruby .github/skills/telegraf-validation/scripts/render-prom-config.rb \
     <settings-body-file>
```

Renders all four scenarios — `replicaset`, `sidecar`, `daemonset`, `windows`. Check that
each expected `[[inputs.prometheus]]` block appears with the values you intended, and read
the parser diagnostics it prints.

> **Config-map key trap**: the cluster-section selectors are `kubernetes_label_selector`
> and `kubernetes_field_selector` — **not** `monitor_kubernetes_pods_label_selector`. Only
> `monitor_kubernetes_pods_namespaces` carries the `monitor_` prefix. Wrong names fail
> silently. Cross-check against `kubernetes/container-azm-ms-agentconfig.yaml`.

> **tomlrb version trap**: pin the version the agent actually ships (check
> `.github/workflows/run_unit_tests.yml`). Newer releases parse inline tables with quoted
> keys that the shipped one cannot — testing on a newer gem hides real failures.

---

## Procedures

### Deploy Scenario Workloads

```bash
kubectl apply -f test/scenario/telegraf/telegraf-scenario-workloads.yaml
kubectl get pods -n ci-telegraf-a -o wide
kubectl get pods -n ci-telegraf-b -o wide
```

Delete the Windows document from the manifest if the cluster has no Windows nodepool.

Verify the endpoints actually serve metrics before trusting any negative result. If
`kubectl exec` is unavailable, apply a short `Job` that curls the endpoint and read its logs:

```bash
kubectl logs job/<probe-job> -n ci-telegraf-a
```

Expect a few thousand metric lines including `empty_dimension_rainfall` and `go_info`.

### Apply the Controlled Config Map

```bash
kubectl get configmap container-azm-ms-agentconfig -n kube-system -o yaml > configmap-backup-original.yaml   # RESTORE POINT
sed "s/__NODE0_IP__/<a linux node internal IP>/" \
    test/scenario/telegraf/container-azm-ms-agentconfig.yaml | kubectl apply -f -
```

Then restart the agents so the config is re-parsed:

```bash
kubectl rollout restart ds/ama-logs -n kube-system
kubectl rollout restart deploy/ama-logs-rs -n kube-system
kubectl rollout status ds/ama-logs -n kube-system --timeout=300s
```

### Swap the Image

**Managed addon** — the addon reconciler will revert a hand-edited image, so to test a
non-released image you must disable the addon and install the chart:

```bash
az aks disable-addons -a monitoring -g <rg> -n <cluster> --subscription <sub>
helm install ama-logs <chart-path> -n kube-system -f <values file>
# recreate the DCRA against the SAME pre-existing DCR
az monitor data-collection rule association create \
  --name ContainerInsightsExtension --resource <clusterResourceId> --rule-id <dcrId>
```

Record the DCRA state first (`az monitor data-collection rule association list ...`) so it
can be restored. Leave any other association (e.g. a managed-Prometheus one) untouched.

Two gaps make a helm install on AKS fail in ways that look like an image bug:

1. **Two image paths in the chart.** The AKS branch uses
   `OmsAgent.imageRepository` / `imageTagLinux` / `imageTagWindows`; the Arc branch uses
   `amalogs.image.repo` / `tag` / `tagWindows`. Set **both**, then verify what actually
   rendered — setting only one silently deploys the default production image and yields a
   perfect, meaningless PASS:
   ```bash
   kubectl get ds ama-logs -n kube-system \
     -o jsonpath="{range .spec.template.spec.containers[*]}{.name}={.image}{'\n'}{end}"
   ```
2. **Missing MSI RBAC.** The chart's reader ClusterRole grants secrets access only for its
   own secret, while the addon separately provisions access to `aad-msi-auth-token`. Without
   it `addon-token-adapter` crash-loops with `secrets "aad-msi-auth-token" is forbidden`.
   The secret itself survives the addon disable — this is purely an authorization gap. Add a
   Role/RoleBinding in `kube-system` granting `get` on that secret.

The chart does **not** render `container-azm-ms-agentconfig`, so the scenario config map
survives a helm install.

**Helm release already in place** — just `helm upgrade` with the new tag.

After any swap, confirm pods are Running with 0 restarts, then **wait 15 minutes**.

### Capture a Snapshot

```bash
.github/skills/telegraf-validation/scripts/capture-telegraf-snapshot.sh \
    <label> <workspaceGuid> <clusterResourceId> 20m <outdir>
```

Seven sections: table counts, InsightsMetrics by namespace, custom-prom metric names,
scrape sources, per-node coverage, agent config errors, Perf counters. Run it once for the
OLD image and once for the NEW image with the **same lookback**.

> Every query filters `_ResourceId`. Workspaces are often shared by several clusters —
> without that filter the numbers are wrong in a way that still looks plausible.

---

## Invariants

These are the assertions that matter. Record each as PASS/FAIL with its numbers.
Derive the concrete expected values from the OLD snapshot; the *shape* is fixed.

| # | Invariant | Why it matters |
|---|---|---|
| **I1** | Custom-prom metric set is identical, and `go_info` is **absent** | `go_info` is in `fieldpass` *and* `fielddrop`; its absence proves `fielddrop` still applies |
| **I2** | Every configured scrape path is live — node URLs, the service URL, and one pod URL per monitored namespace | Proves `urls`, `kubernetes_services` and `monitor_kubernetes_pods` all still generate working plugins |
| **I3** | **`$NODE_IP` still expands** — each Linux node's IP appears as a scrape URL | The classic regression when config values are escaped or quoted. `$` must pass through untouched |
| **I4** | Node-level `fieldpass`/`fielddrop` still narrow the metric set to the expected count | Proves node-section filters survive independently of the cluster section |
| **I5** | One `[[inputs.prometheus]]` per entry in `monitor_kubernetes_pods_namespaces`, all producing data | Proves per-namespace plugin generation |
| **I6** | Non-prom InsightsMetrics namespaces persist with the same metric counts — `container.azm.ms/disk`, `/diskio`, `/net`, `/kubestate`, `/prometheus` | Guards the rest of the telegraf input set |
| **I7** | `Perf` counter set unchanged (`K8SContainer` + `K8SNode`) | Guards the non-telegraf metrics path |
| **I8** | No new error rows in `KubeMonAgentEvents` | Config-parse failures surface here |

**Pass criteria**: I1–I8 hold structurally. Record counts are *not* required to match —
±15% is normal scrape/ingestion variance. A change in the *set* of metrics, URLs, or
namespaces is a real regression; a change in volume alone usually is not.

**Failure investigation**: re-render the config offline for the failing scenario (P2) and
diff the generated `[[inputs.prometheus]]` blocks between the OLD and NEW parser. Checking
out the pre-change commit in a `git worktree` and rendering the same settings body through
both gives an unambiguous A/B of the generated config without any cluster involvement.

---

## Environment Notes

- **`SIDECAR_SCRAPING_ENABLED=true`** means cluster-section custom-prom scraping runs in the
  `ama-logs-prometheus` **sidecar**, not the replicaset. Check it before concluding the
  replicaset is broken.
- **Windows may legitimately emit no `InsightsMetrics`** when scraping is delegated to the
  sidecar. Confirm against the OLD snapshot before calling it a regression. Windows coverage
  is then established by the offline `windows` render plus the Windows agent parsing the
  config map cleanly and starting telegraf.
- **Windows ignores the `telegraf --test` exit code**, and on Windows that test run is
  unfiltered — so a bad generated config can surface differently there than on Linux, where
  the test run is input-filtered.

## Cleanup

Restore everything you changed, in this order:

```bash
helm uninstall ama-logs -n kube-system                      # if helm was used
kubectl delete -f <msi-rbac file>                           # if it was added
kubectl delete ns ci-telegraf-a ci-telegraf-b
kubectl apply -f configmap-backup-original.yaml             # the restore point
az aks enable-addons -a monitoring -g <rg> -n <cluster> \
  --subscription <sub> --workspace-resource-id <workspaceResourceId>
```

Then verify: the addon reports `enabled: true`, the `ContainerInsightsExtension` DCRA points
at the original DCR, any other association is untouched, agents are Running with 0 restarts,
and data is flowing again.

> `az aks enable-addons` needs the **workspace resource ID**, not the GUID. Look it up
> rather than guessing the name:
> `az monitor log-analytics workspace list --subscription <sub> --query "[?customerId=='<guid>'].id" -o tsv`

## Steps

### Phase 1 — Pre-flight

1. Resolve the derived values; save them to `TelegrafValidationOutput.md`.
2. **P1** — verify the DCR collects metrics. Fix and wait for data if not.
3. **P2** — render the config map offline through all four scenarios; confirm the expected blocks.
4. Deploy the scenario workloads; verify the endpoints serve metrics.
5. Apply the controlled config map (substituting the node IP); restart the agents.

### Phase 2 — OLD image snapshot

6. Ensure the OLD image is running; confirm the tag actually deployed.
7. Wait 15 minutes after any restart.
8. Capture the snapshot with label `before-<oldtag>`.
9. Derive the concrete expected values for I1–I8 and record them as the comparison contract.

### Phase 3 — NEW image snapshot

10. Swap to the NEW image; **verify the running image tag**.
11. Confirm pods are Running with 0 restarts. If a pod crash-loops, check `addon-token-adapter` RBAC before suspecting the image.
12. Wait 15 minutes.
13. Capture the snapshot with label `after-<newtag>`, same lookback.

### Phase 4 — Compare and report

14. Evaluate I1–I8 side by side; record PASS/FAIL with numbers for each.
15. Investigate any failure by re-rendering offline and diffing the generated config.
16. Cleanup and verify restoration.
17. Write the final verdict to `TelegrafValidationOutput.md`: image tags compared, per-invariant results, and anything classified as noise rather than regression.
