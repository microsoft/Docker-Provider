---
name: multiline-validation
description: "Validate multi-line log stitching behavior for an ama-logs image change. Enables multiline in the configmap, deploys the OLD (production) image, captures stitching baselines, deploys the NEW (test) image, captures the same metrics, and produces an A/B comparison per language and OS. Use when: validating a fluent-bit upgrade, validating a parser/configmap change, comparing multiline stitching between two images, multi-line A/B test, stacktrace stitching test."
argument-hint: "Provide cluster name, OLD image tag, NEW image tag, and helm release name"
---

# Multi-line Log Stitching A/B Validation

Validates that an ama-logs image change preserves (or improves) multi-line log stitching behavior across Java, Python, Go, and .NET stack traces on both Linux and Windows. Produces a per-language, per-OS A/B comparison table that shows whether the NEW image produces the same row counts, max-lengths, and stitched-vs-single ratios as the OLD image.

This skill is **complementary to backdoor-deployment** — that skill validates aggregate data volume and resource consumption; this one validates the multi-line parser pipeline specifically. Run both when an image change can affect log parsing (fluent-bit upgrade, parser config edit, output plugin change).

## Required Inputs

Confirm with the user; suggest defaults from the most recent run if available.

| Input | Description | Example |
|-------|-------------|---------|
| **Cluster name** | AKS cluster with Linux + Windows nodepools | `zane-ama-logs-helm-test` |
| **OLD image tag** | Current production image | `ciprod:3.3.0` (Linux) / `ciprod:win-3.3.0` (Windows) |
| **NEW image tag** | Test image from CI build | `cidev:3.3.0-6-g1d77401ab-20260506045747` |
| **Helm release name** | Helm release for ama-logs on the cluster | `azuremonitor-containers` |
| **Helm release namespace** | Usually `default` for the prod chart | `default` |

## Derived Values

Parse from `charts/azuremonitor-containerinsights/values.yaml` — do not ask the user.

| Value | Source |
|-------|--------|
| **Cluster Resource ID** | `OmsAgent.aksResourceID` |
| **Log Analytics Workspace ID** | `OmsAgent.workspaceID` |
| **Subscription ID / Resource Group** | Extracted from cluster resource ID |

## General Rules

- Save the output of **each step** to `MultilineValidationOutput.md` in the repo root. Always append; never clear unless explicitly asked.
- The **configmap is the controlled variable** — apply it once, then leave it alone for the entire run. If the configmap changes between OLD and NEW snapshots, the comparison is invalid and must be redone.
- Use the **same multiline test job set** for both snapshots. Re-deploy fresh job runs after each image swap so log windows are clean.
- Wait **at least 12 minutes** after each image deploy before querying ContainerLogV2 (pod restart + ingestion latency).
- Restore `values.yaml` and remove the test configmap from the cluster at the end (unless the user wants to keep them).

## Procedures

### Apply Multiline Configmap

The skill ships its own configmap so behavior is deterministic. Source: `test/scenario/multiline/container-azm-ms-agentconfig.yaml` if present, otherwise generate inline:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: container-azm-ms-agentconfig
  namespace: kube-system
data:
  log-data-collection-settings: |-
    [log_collection_settings]
       [log_collection_settings.stdout]
          enabled = true
       [log_collection_settings.stderr]
          enabled = true
       [log_collection_settings.enable_multiline_logs]
          enabled = "true"
          stacktrace_languages = ["java", "python", "dotnet", "go"]
```

Apply: `kubectl apply -f <path>`

Restart both daemonsets so the new config takes effect:
```bash
kubectl rollout restart ds/ama-logs ds/ama-logs-windows -n kube-system
kubectl rollout status ds/ama-logs -n kube-system --timeout=180s
kubectl rollout status ds/ama-logs-windows -n kube-system --timeout=180s
```

### Deploy Multiline Test Jobs

The repo ships eight job manifests under `test/scenario/multiline/` covering Java, Python, Go, and .NET on both Linux and Windows. Each job emits a mix of single-line app logs and multi-line stack traces in a loop.

```bash
kubectl create namespace tenant1 --dry-run=client -o yaml | kubectl apply -f -
kubectl delete jobs -n tenant1 --all
Get-ChildItem test/scenario/multiline/*.yaml | ForEach-Object { kubectl apply -f $_.FullName }
kubectl get jobs -n tenant1
```

Re-run this block after each image swap so each snapshot has a clean log window.

> **Windows nodepool note**: Windows test pods require an `ltsc2022` nodepool. The shipped yamls use `mcr.microsoft.com/powershell:lts-nanoserver-ltsc2022` and rely on AKS image-OS scheduling — do not add a hard-coded `nodeSelector`.

### Update Image Tags and Deploy

1. Edit `charts/azuremonitor-containerinsights/values.yaml`:
   - `imageRepository: "/azuremonitor/containerinsights/<repo>"` (`ciprod` for OLD, `cidev` for NEW)
   - `imageTagLinux: <linux-tag>`
   - `imageTagWindows: <windows-tag>`
2. Helm upgrade against the existing release name (do not use `--install` with a different release name — it will fail on owned ServiceAccounts):
   ```bash
   helm upgrade <release-name> ./charts/azuremonitor-containerinsights -n <release-namespace>
   ```
3. Record deploy time in UTC (`Get-Date -Format 'u'` or `(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')`).
4. Wait for rollouts:
   ```bash
   kubectl rollout status ds/ama-logs -n kube-system --timeout=180s
   kubectl rollout status ds/ama-logs-windows -n kube-system --timeout=180s
   ```
5. Verify the running image:
   ```bash
   kubectl get ds ama-logs -n kube-system -o jsonpath="{range .spec.template.spec.containers[*]}{.name}={.image}{'\n'}{end}"
   kubectl get ds ama-logs-windows -n kube-system -o jsonpath="{.spec.template.spec.containers[0].image}"
   ```
6. **Wait 12 minutes** before querying.

### Query Stitching Metrics

Run the per-language stitching KQL via `az monitor log-analytics query -w <workspaceId>`:

```kusto
ContainerLogV2
| where TimeGenerated >= datetime('<deployTime+5min>')
| where _ResourceId =~ '<clusterResourceId>'
| where PodNamespace == 'tenant1'
| extend Msg = tostring(LogMessage)         // CRITICAL: dynamic to string
| extend Lines = countof(Msg, '\n') + 1
| extend OS = iif(ContainerName endswith 'win', 'Win', 'Linux')
| extend Lang = replace_string(ContainerName, '-win', '')
| summarize
    Rows=count(),
    MaxLen=max(strlen(Msg)),
    MaxLines=max(Lines),
    Stitched=countif(Lines>1),
    Single=countif(Lines==1)
    by Lang, OS
| order by Lang asc, OS asc
```

Save the resulting 8-row table (Lang × OS) to the output file under a clearly labeled section (`### OLD image snapshot` or `### NEW image snapshot`).

### Compare A/B

Build a single side-by-side table with one row per (Lang, OS) and these columns:

| Lang | OS | OLD Rows | OLD Stitched | OLD Single | NEW Rows | NEW Stitched | NEW Single | OLD MaxLen | NEW MaxLen | Verdict |

**Pass criteria** (per row):
1. `MaxLen` matches exactly between OLD and NEW. A change here means the longest stitched record changed → parser regression.
2. `Stitched / (Stitched + Single)` ratio matches within ±2% between OLD and NEW. A drop means stitching is failing for some headers.
3. Absolute `Rows` count is **not** required to match — different snapshot windows naturally produce different totals.

**Failure investigation**: when a row fails, drill into the specific (Lang, OS) by sampling rows and inspecting `LogMessage`. Compare the actual stitched output between OLD and NEW for the same source app log shape. Look for header regex changes, continuation regex changes, or new fluent-bit defaults.

### Cleanup

1. Delete the test namespace: `kubectl delete namespace tenant1 --wait=false`
2. (Optional) Remove the multiline configmap if the cluster shouldn't keep it: `kubectl delete configmap container-azm-ms-agentconfig -n kube-system`
3. Restore `values.yaml` placeholders:
   - `imageRepository: "/azuremonitor/containerinsights/ciprod"`
   - `imageTagLinux: <image_to_be_deployed_for_linux>`
   - `imageTagWindows: <image_to_be_deployed_for_windows>`
   - Restore any region/cloud placeholders that were swapped during deployment.
4. Final summary in `MultilineValidationOutput.md`: pass/fail per row, image tags compared, deploy timestamps, and any investigation findings.

## Steps

### Phase 1: Setup (once)

1. Confirm inputs with the user (or use most recent run defaults).
2. Set kubectl context: `kubectl config use-context <cluster name>`.
3. Apply the multiline configmap and restart both daemonsets (see "Apply Multiline Configmap").
4. Verify multiline parsers are engaged inside the Linux pod:
   ```bash
   kubectl exec -n kube-system <ama-logs-linux-pod> -c ama-logs -- cat /etc/opt/microsoft/docker-cimprov/fluent-bit.conf | grep -i multiline
   ```
   Expect a `[FILTER] Name multiline` block with `multiline.parser` listing the configured languages.

### Phase 2: OLD image snapshot

5. Update `values.yaml` to the OLD image and helm-upgrade (see "Update Image Tags and Deploy"). Record OLD deploy time.
6. Verify pods running and image tag matches expectation.
7. Deploy / re-deploy the multiline test jobs (see "Deploy Multiline Test Jobs").
8. Wait 12 minutes.
9. Run the stitching KQL (see "Query Stitching Metrics"). Save as `### OLD image snapshot`.

### Phase 3: NEW image snapshot

10. Update `values.yaml` to the NEW image and helm-upgrade. Record NEW deploy time.
11. Verify pods running and image tag matches expectation.
12. Re-deploy the multiline test jobs to start a clean window.
13. Wait 12 minutes.
14. Run the stitching KQL again. Save as `### NEW image snapshot`.

### Phase 4: Compare and report

15. Build the side-by-side comparison table (see "Compare A/B").
16. Apply the pass criteria. For any failing row, investigate and document.
17. Cleanup (see "Cleanup").
18. Write final pass/fail verdict to `MultilineValidationOutput.md`.
