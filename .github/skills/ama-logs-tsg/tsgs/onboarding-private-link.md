# Onboarding / Private Link (AMPLS)

## Symptom
Container Insights configured on a cluster behind Azure Monitor Private Link Scope (AMPLS) — customer sees empty tables (Syslog, ContainerLogV2, KubeEvents, KubePodInventory) in their Log Analytics workspace. Agent pods appear healthy (`Running`, `Ready`, restart count 0). Onboarding, addon enable, and reinstall don't help.

---

## ⚠️ CRITICAL: Private-link clusters do NOT emit telemetry to ContainerInsightsAgent-Prod

**The absence of a cluster from `ContainerInsightsAgent-Prod` App Insights is EXPECTED for AMPLS/private-link clusters — it is NOT evidence of an agent failure.**

The Application Insights ingestion endpoint (`dc.applicationinsights.azure.com`) is a Microsoft-owned resource that is not in the customer's AMPLS. When a private-link cluster's egress is locked down (typical AMPLS + firewall setup), traffic to our internal AI is blocked at the network layer even though customer log ingestion may be working perfectly.

**Consequences for triage:**
- `tsg_triage`, `tsg_errors`, `tsg_workload`, `tsg_pods` — all rely on App Insights telemetry and will return "no data" for these clusters. That doesn't mean the agent is broken.
- The "last telemetry" timestamp in App Insights typically corresponds to the date customer enabled AMPLS, not the date something broke.
- Prior AI-based RCAs about the cluster (SRE Agent, older ICM notes) are frequently based on this stale window and should be treated as suspect.
- **Success criteria must be verified in the CUSTOMER'S workspace**, not in ours:
  - `Syslog | where _ResourceId =~ "<cluster-arm-id>" | where TimeGenerated > ago(15m)`
  - `ContainerLogV2 | where _ResourceId =~ "<cluster-arm-id>" | take 5`
  - `KubeEvents | where ClusterName =~ "<cluster-name>" | take 5`
  - `KubePodInventory | where ClusterName =~ "<cluster-name>" | take 5`

---

## The Container Insights ingestion path — what actually happens on the wire

Even in **AAD MSI auth mode with DCR**, Container Insights log data uploads go to the **workspace-specific ODS endpoint**, not the DCE ingest endpoint. This surprises people. Code refs:

- `source/plugins/go/src/oms.go:2215` — `OMSEndpoint = "https://" + WorkspaceID + ".ods." + LogAnalyticsWorkspaceDomain + "/OperationalData.svc/PostJsonDataItems"` (unconditional; `IsAADMSIAuthMode` only changes the auth token).
- Customer's DCR config chunk contains `"channels":[{"endpoint":"https://{wsid}.ods.opinsights.azure.com","protocol":"ods"}]` and `"sendToChannels":["ods-{wsid}"]`.
- `gigl-dce-*` channels exist in the AMA framework but are used only by AMACoreAgent for OTel logs / AMW Prometheus — **not** for Container Insights log streams (as of ciprod 3.4.x).

Traffic breakdown for a CI + AMPLS cluster:

| Traffic | FQDN pattern | Private DNS zone | Purpose |
|---|---|---|---|
| MSI token acquisition | `169.254.169.254` (IMDS) | n/a (link-local) | Managed identity |
| MCS / AMCS handler (DCR download) | `global.handler.control.monitor.azure.com` | `privatelink.monitor.azure.com` | Configuration bootstrap |
| DCE handler (regional) | `{dce}-{shard}.{region}-1.handler.control.monitor.azure.com` | `privatelink.monitor.azure.com` | DCR download + gig ingestion token issue |
| DCE ingest (only for AMW Prometheus / OTel) | `{dce}-{shard}.{region}-1.ingest.monitor.azure.com` | `privatelink.monitor.azure.com` | Metrics / OTel logs |
| **LOG DATA UPLOAD (syslog, container logs, kube events, pod inventory)** | **`{wsid}.ods.opinsights.azure.com`** | **`privatelink.ods.opinsights.azure.com`** | **Container Insights ingestion** |
| OMS legacy (health assessment, older workloads) | `{wsid}.oms.opinsights.azure.com` | `privatelink.oms.opinsights.azure.com` | OMS Homing (legacy auth clusters) |
| Automation agent service | `*.agentsvc.azure-automation.net` | `privatelink.agentsvc.azure-automation.net` | Automation solutions (rarely used by CI) |
| App Insights .NET Profiler / Debugger storage | `*.blob.core.windows.net` | `privatelink.blob.core.windows.net` | AI Profiler backing storage |

⚠️ **Note the split**: MCS/AMCS/DCE-handler all resolve through `privatelink.monitor.azure.com`. **The workspace ODS ingestion endpoint resolves through a DIFFERENT zone — `privatelink.ods.opinsights.azure.com`.** Customers routinely have the first zone linked and think they're done.

---

## The 5 required private DNS zones for AMPLS

Per [Azure Private Endpoint DNS reference](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns) — the single AMPLS resource (`Microsoft.Insights/privateLinkScopes`, subresource `azuremonitor`) requires **all five** of these zones, each linked to the VNET where the workload runs:

1. `privatelink.monitor.azure.com` — MCS/AMCS, DCE handler + ingest, global monitor endpoints
2. `privatelink.oms.opinsights.azure.com` — OMS legacy paths
3. **`privatelink.ods.opinsights.azure.com`** — **workspace-specific ODS ingestion — REQUIRED for Container Insights logs**
4. `privatelink.agentsvc.azure-automation.net` — Log Analytics agent service
5. `privatelink.blob.core.windows.net` — AI Profiler / DiagnosticsExtension storage

They are separate top-level DNS domains; they cannot be merged. Each must be:
- Created (if it doesn't exist)
- Have DNS A-records populated from the AMPLS PE
- Linked (`virtualNetworkLinks`) to the workload VNET where the AKS cluster lives (NOT just the PE's VNET, if they differ)

---

## Diagnostic flow

### Step 1: Confirm the cluster is behind AMPLS

Since App Insights telemetry is unavailable, ask the customer directly (or check ARM if you have access):
- Workspace publicNetworkAccessForIngestion (Disabled → AMPLS-only)
- AMPLS resource ID they're using
- Cluster VNET ID

### Step 2: Get the customer to collect the troubleshoot bundle

Direct them to run: `https://supportability.visualstudio.com/AzureMonitor/_wiki/wikis/AzureMonitor.wiki/614028/Check-and-Collect-Container-Insights-Logs` — Part 2, full log collection script. This produces `AKSInsights-logs.{timestamp}.{nodename}.tgz` plus separate configchunks/fluent/linuxmonagent directories.

### Step 3: Read mdsd.err — look for the diagnostic 403 signature

The tell-tale signature of AMPLS ingestion-side failure is:

```
Failed to upload to ODS: 403, Datatype: LINUX_SYSLOGS_BLOB, RequestId: <guid>
HTTP/1.1 403 Forbidden
Cache-Control: private
Content-Length: 0
Server: Microsoft-IIS/10.0
```

- `Server: Microsoft-IIS/10.0` — the request reached a real ODS regional gateway (rules out DNS/TLS/connectivity failure)
- `Content-Length: 0` + no error body — silent rejection, characteristic of workspace-level network ACL denial
- All three CI daemonset datatypes affected: **LINUX_SYSLOGS_BLOB, CONTAINER_LOG_BLOB, HEALTH_ASSESSMENT_BLOB** — because they share the same ODS channel

If the replicaset's mdsd.err is also collected, expect the same signature on KUBE_EVENTS_BLOB and KUBE_POD_INVENTORY_BLOB.

### Step 4: Confirm the AMCS/token pipeline is NOT the problem

In the daemonset's `mdsd.info`, look for these healthy patterns:
```
[McsManager.cpp] MCS redirected to endpoint https://{dce}-{shard}.{region}-1.handler.control.monitor.azure.com
[RefreshConfigurations.cpp] Configuration [dcr-{guid}] added
[RefreshGigToken.cpp] Retrieved gig token for configuration id [dcr-{guid}] channel id [ods-{wsid}]: [eyJhbGciOi...]
```

If gig token retrieval is succeeding every hour, the auth/AMCS path is healthy. The gig token that ODS rejects is the same one AMCS just minted. **Rules out**: OMS Homing certificate failure, AMCS `-2146172665` errors, MSI token issues, DCR RBAC on the DCR (the identity CAN read the DCR).

### Step 5: The single most valuable diagnostic — `getent hosts` from inside an ama-logs pod

```bash
kubectl -n kube-system exec ds/ama-logs -c ama-logs -- \
  getent hosts {wsid}.ods.opinsights.azure.com
```

- Returns `10.x.x.x` (AMPLS PE subnet) → zone is linked correctly. Look for RBAC / workspace-scoping issues (rare).
- Returns a public IP (e.g., `20.x.x.x`, `40.x.x.x`, `52.x.x.x`) → **`privatelink.ods.opinsights.azure.com` is not resolving through the AMPLS PE from this pod's DNS view. This is almost certainly the root cause.**

**Comprehensive multi-endpoint check** (validated 2026-08-04 against a live AKS + AMPLS cluster):

```bash
WSID=4dbee6d7-be00-44f1-a22f-a3c7a91a414c   # replace with customer's workspace CustomerId
kubectl -n kube-system exec ds/ama-logs -c ama-logs -- sh -c "
for h in \
  global.handler.control.monitor.azure.com \
  ${WSID}.ods.opinsights.azure.com \
  ${WSID}.oms.opinsights.azure.com \
  ${WSID}.agentsvc.azure-automation.net ; do
  echo \"=== \$h ===\"; getent hosts \$h || echo NXDOMAIN
done"
```

Notes:
- `ods`, `oms`, `agentsvc` are all **workspace-specific** subdomains — they must be prefixed with `{wsid}`. `ods.opinsights.azure.com` or `agentsvc.azure-automation.net` bare are not resolvable FQDNs.
- `global.handler.control.monitor.azure.com` is the only truly global one.
- Expected outcome for a **healthy** AMPLS setup: all four return `10.x.x.x` addresses on the PE subnet.
- Any endpoint returning a public IP identifies which private DNS zone is missing/misconfigured.

⚠️ **Do NOT accept `curl -v <endpoint>` as a valid AMPLS test.** Public ODS gateways are reachable from anywhere on the internet. TLS succeeds against them, HTTP responds. `curl -v` shows the resolved IP but customers routinely interpret "HTTP responded" as "private link working". Only the resolved IP matters — and only from the AKS pod's DNS view, not from a jumphost that may live in a different VNET.

---

## Five failure modes that produce this exact 403

Ordered by observed frequency in CI ICMs. **Failure mode #1 was reproduced end-to-end** on a throwaway AKS + AMPLS cluster (see "Verified repro" section below); the other four produce the identical mdsd.err 403 signature.

### 1. Hub-and-spoke: zones linked to hub VNET, not AKS spoke
AMPLS + PE + private DNS zones all live in the hub RG, linked to the hub VNET. AKS VNET is a spoke, peered to hub, but private DNS zones don't propagate through VNET peering by default — the spoke's DNS resolver has to reach a resolver that sees the zones. Customer added `privatelink.monitor.azure.com` to the AKS VNET as a targeted fix ("MCS wasn't resolving") but never added the ODS zone.

### 2. Workspace added to AMPLS AFTER the PE was created
The PE's `privateDnsZoneGroup` is fixed at PE-creation time. If the PE was created with only a DCE scoped, only the DCE-related DNS records get populated (`privatelink.monitor.azure.com`). Adding the LAW to the AMPLS later does NOT retroactively update the PE's dnsZoneGroup or create records in `privatelink.ods.opinsights.azure.com`. Fix requires **editing the PE's dnsZoneGroup** to add the ODS zone integration.

### 3. LAW not actually scoped into the AMPLS
Customer claims LAW is in the AMPLS but never showed proof. If it isn't, no records ever appear in `privatelink.ods.opinsights.azure.com` for this workspace. Verify with `az monitor private-link-scope scoped-resource list`.

### 4. Custom DNS server without full conditional forwarders
AKS VNET's DNS is set to a custom resolver (typical for on-prem-integrated networks). The resolver only has conditional forwarders for `monitor.azure.com` → Azure DNS. `ods.opinsights.azure.com` still hits the public path.

### 5. IaC template with incomplete `dnsZoneConfigs` list
Bicep / Terraform / ARM template that iterates over a hand-authored zone list — commonly missing 1-2 zones because the template was copied from an older doc.

---

## Verification commands for the customer call

Ask the customer to run these — the output distinguishes all 5 scenarios:

```bash
# A. What IP does the workspace ODS endpoint resolve to from inside ama-logs?
kubectl -n kube-system exec ds/ama-logs -c ama-logs -- \
  getent hosts {wsid}.ods.opinsights.azure.com

# B. What zones does the PE actually have integrations for?
az network private-endpoint dns-zone-group list \
  -g <pe-rg> --endpoint-name <pe-name> \
  --query "[].privateDnsZoneConfigs[].privateDnsZoneId" -o tsv

# C. Which VNETs are the AMPLS DNS zones linked to?
# (VNET links are a property of the ZONE, not the PE — the PE lives in one subnet,
# but each zone has its own virtualNetworkLinks[] controlling who can resolve it.
# For hub-and-spoke, this is where things silently break.)
for z in privatelink.monitor.azure.com \
         privatelink.ods.opinsights.azure.com \
         privatelink.oms.opinsights.azure.com \
         privatelink.agentsvc.azure-automation.net \
         privatelink.blob.core.windows.net; do
  echo "=== $z ==="
  ZID=$(az network private-dns zone list --query "[?name=='$z'].id | [0]" -o tsv 2>/dev/null)
  if [ -z "$ZID" ]; then
    echo "  ⚠️  ZONE NOT FOUND IN SUBSCRIPTION"
    continue
  fi
  echo "  Zone RG: $(echo $ZID | cut -d/ -f5)"
  az network private-dns link vnet list \
    --resource-group $(echo $ZID | cut -d/ -f5) --zone-name $z \
    --query "[].{link:name, vnet:virtualNetwork.id, status:virtualNetworkLinkState, autoReg:registrationEnabled}" \
    -o table
done

# C2 (optional). Confirm the workspace's A record exists inside the ods zone.
# Expected: a single row with name = workspace customerId, ip = PE subnet IP.
az network private-dns record-set a list \
  --resource-group <ods-zone-rg> \
  --zone-name privatelink.ods.opinsights.azure.com \
  --query "[].{name:name, ip:aRecords[0].ipv4Address}" -o table

# C3 (optional). List all PEs in the customer's RG + which subnet each lives in.
# Useful for hub-and-spoke: if the PE is in the hub subnet, DNS zones may only be
# linked to the hub VNET, not the AKS spoke VNET.
az network private-endpoint list \
  --resource-group <pe-rg> \
  --query "[].{name:name, subnet:subnet.id, group:privateLinkServiceConnections[0].groupIds[0]}" \
  -o table

# D. Confirm the LAW is actually scoped into the AMPLS
az monitor private-link-scope scoped-resource list \
  -g <ampls-rg> --scope-name <ampls-name> \
  --query "[].{name:name, linkedId:linkedResourceId}" -o table

# E. Confirm workspace network access settings
az monitor log-analytics workspace show --ids <law-id> \
  --query "{ingest:publicNetworkAccessForIngestion, query:publicNetworkAccessForQuery}"
```

## Interpretation matrix

| Command A resolves to | Zones linked (C) | LAW scoped (D) | Diagnosis |
|---|---|---|---|
| Public IP | ods zone missing or wrong VNET | LAW in AMPLS | **Scenario 1 or 5** — link `privatelink.ods.opinsights.azure.com` to AKS VNET |
| Public IP | zone doesn't exist at all | LAW in AMPLS | **Scenario 2** — edit PE's dnsZoneGroup to add ODS zone integration |
| Public IP | ods zone linked correctly | LAW NOT in AMPLS | **Scenario 3** — add LAW as scoped resource; PE records refresh; wait ~5 min; delete pods |
| Public IP | anything | anything | **Scenario 4** — check VNET's DNS servers; if custom resolver, add conditional forwarders for all 5 zones |
| Private IP (10.x) | All 5 zones linked to AKS VNET | LAW in AMPLS | **Look elsewhere**: (a) verify workspace `Monitoring Metrics Publisher` role on kubelet identity; (b) check AMPLS ingestion access mode + workspace `publicNetworkAccessForIngestion` combo; (c) escalate to Azure Monitor → Log Analytics → Ingestion |

## How the AKS VNET actually reaches the AMPLS DNS zones

DNS resolution flow from a pod:

```
Pod → CoreDNS → node's VNET DNS server (default: 168.63.129.16 Azure DNS)
   ↓
Azure DNS checks: is any Private DNS zone LINKED to this VNET matching the query's FQDN?
   ├─ Yes → return records from that zone (private IP)
   └─ No  → forward to public DNS (returns public trafficmanager IP)
```

Key: **the link is an explicit `virtualNetworkLinks/{name}` resource on each zone.** Nothing else counts:
- **VNET peering does NOT share DNS zones** (common misconception). Peering shares IP reachability, not zone resolution.
- **The PE living in a VNET does NOT by itself make DNS work** — the zone must be linked to that VNET.

### Three ways to establish the link, ranked from most-automatic to least

| Mechanism | Automatic? | When it applies |
|---|---|---|
| Portal PE wizard with "Integrate DNS = Yes" — links all 5 zones to the PE's VNET | **Yes** — but only for the PE's own VNET, only if run in portal, and only if all zones are integrated | New setups where PE and AKS share a VNET |
| Manual per-zone-per-VNET `virtualNetworkLinks` | **No** — must be created explicitly. Portal auto-integration doesn't help other VNETs. | Hub-and-spoke where PE lives in hub; AKS in spoke; you want each VNET to resolve directly |
| Custom DNS server or Azure Private Resolver in the hub | **No** — must be set up separately; AKS VNET DNS must point at the resolver IP | Enterprise hub-and-spoke; standard pattern to centralize DNS |

### Common misconfigurations at this layer

- AKS VNET DNS servers left at "Default (Azure)", but hub-and-spoke pattern requires them to point at the hub resolver
- Peering exists but there's no DNS resolver in the peered VNET
- Hub has all 5 zones linked, but resolver rule/forwarder only covers `monitor.azure.com`
- Zones linked to hub VNET but hub VNET isn't the one running the resolver

### Fix template — link + attach the 4 missing zones for a customer with monitor already working

```bash
RG=<customer-rg>
VNET_ID=$(az network vnet show -g <vnet-rg> -n <aks-vnet> --query id -o tsv)
PE_NAME=<pe-name>
PE_RG=<pe-rg>

for z in privatelink.ods.opinsights.azure.com \
         privatelink.oms.opinsights.azure.com \
         privatelink.agentsvc.azure-automation.net \
         privatelink.blob.core.windows.net; do
  az network private-dns zone create -g $RG -n $z
  az network private-dns link vnet create -g $RG -z $z -n aks-vnet-link \
    --virtual-network $VNET_ID --registration-enabled false
  ZID=$(az network private-dns zone show -g $RG -n $z --query id -o tsv)
  az network private-endpoint dns-zone-group add -g $PE_RG \
    --endpoint-name $PE_NAME -n default \
    --zone-name $(echo $z | tr . -) --private-dns-zone $ZID
done
kubectl -n kube-system delete pod -l component=ama-logs-agent
# Wait 3 min. Verify with `getent hosts <wsid>.ods.opinsights.azure.com` from the pod.
```

Validated against the AKS + AMPLS repro on 2026-08-03. Recovery observed in under 3 minutes.

---

## After the fix — how to verify

1. `kubectl -n kube-system delete pod -l component=ama-logs-agent` — force DNS re-resolution.
2. Wait 5 minutes.
3. From ama-logs pod: `getent hosts {wsid}.ods.opinsights.azure.com` returns private IP.
4. Tail mdsd.err inside the pod — 403 rate should drop to zero within 1 minute of DNS recovery.
5. Customer's workspace: `Syslog | where TimeGenerated > ago(10m)` returns rows.

---

## Verified repro (2026-08-03) + confirmed customer root cause (2026-08-04)

Full end-to-end reproduction on a throwaway AKS + AMPLS cluster in the CI dev subscription. Recreated failure mode #1 (single zone linked), observed the exact customer symptoms, applied the fix, verified recovery.

**Customer's actual root cause (confirmed on the call, 2026-08-04)**:
All 5 private DNS zones existed in the customer's subscription. **But only `privatelink.monitor.azure.com` had a `virtualNetworkLinks` entry pointing at the AKS VNET.** The other 4 zones (`ods`, `oms`, `agentsvc`, `blob`) existed and had A records populated, but were linked to a different VNET (or no VNET at all) — so from inside the AKS cluster, the pod's DNS resolver ignored them and fell through to public IPs. This matches Failure Mode 1 (hub-and-spoke variant) — zones exist and are integrated with the PE but VNET links are incomplete.

**Diagnostic hierarchy this ICM proved**: `getent hosts` from inside the ama-logs pod is the definitive check, because it exercises the pod's actual DNS resolution path — the same one mdsd uses when uploading. Any check outside the pod (portal UI, curl from jumphost, DNS from a management VM) can appear to work while the pod-side DNS is still broken.

**Key evidence for confidence in the RCA:**

**Broken state — customer's setup**:
- AKS cluster (public API for simplicity), workload subnet 10.100.0.0/22
- AMPLS + PE + workspace + DCE + scoped resources
- Workspace `publicNetworkAccessForIngestion=Disabled`
- ONLY `privatelink.monitor.azure.com` created and linked to AKS VNET; PE's dnsZoneGroup had ONE entry
- CI addon enabled via `az aks enable-addons -a monitoring --enable-msi-auth-for-monitoring true`

Observations from inside the ama-logs pod:
```
$ getent hosts global.handler.control.monitor.azure.com
10.100.8.17 global.handler.control.privatelink.monitor.azure.com global.handler.control.monitor.azure.com

$ getent hosts <dce>.westus3-1.handler.control.monitor.azure.com
10.100.8.7  <dce>.westus3-1.handler.control.privatelink.monitor.azure.com <dce>.westus3-1.handler.control.monitor.azure.com

$ getent hosts <wsid>.ods.opinsights.azure.com
20.150.190.99  ipv4-usw3-oi-ods-cses-c.westus3.cloudapp.azure.com
               <wsid>.ods.opinsights.azure.com
               <wsid>.privatelink.ods.opinsights.azure.com    ← Azure DNS global CNAME set
               usw3-oi-ods.trafficmanager.net                 ← fell through to public because no local zone
```

mdsd.info showed **healthy** MCS redirect + gig token retrieval:
```
McsManager.cpp:1053 MCS redirected to endpoint https://<dce>-<shard>.westus3-1.handler.control.monitor.azure.com
RefreshConfigurations.cpp:580 Configuration [dcr-<guid>] added
RefreshGigToken.cpp:253 Retrieved gig token for configuration id [dcr-<guid>] channel id [ods-<wsid>]
```

mdsd.err showed the exact customer 403 signature on every LINUX_SYSLOGS_BLOB / CONTAINER_LOG_BLOB / HEALTH_ASSESSMENT_BLOB upload.

**Fix applied**:
```bash
# 1) Create the missing 4 zones + link each to the AKS VNET
for z in privatelink.oms.opinsights.azure.com \
         privatelink.ods.opinsights.azure.com \
         privatelink.agentsvc.azure-automation.net \
         privatelink.blob.core.windows.net; do
  az network private-dns zone create -g $RG -n $z
  az network private-dns link vnet create -g $RG -z $z -n aks-vnet-link \
    --virtual-network $VNET_ID --registration-enabled false
done

# 2) Add all 4 to the PE's dnsZoneGroup so the PE populates A records
for z in <the 4 zones>; do
  ZID=$(az network private-dns zone show -g $RG -n $z --query id -o tsv)
  az network private-endpoint dns-zone-group add -g $RG --endpoint-name $PE -n zones \
    --zone-name $(echo $z | tr . -) --private-dns-zone $ZID
done

# 3) Restart pods to clear DNS cache
kubectl -n kube-system delete pod -l component=ama-logs-agent
```

**Recovery observed within 3 minutes**:
- `getent hosts <wsid>.ods.opinsights.azure.com` → `10.100.8.5` (private, on PE subnet)
- A record auto-populated in `privatelink.ods.opinsights.azure.com` for the workspace ID
- `grep -c 'Failed to upload' mdsd.err` → **0**
- KQL against customer workspace: `KubeEvents`, `KubePodInventory` populating within minutes

**Key architectural facts confirmed by the repro**:

1. **Adding a zone to the PE's `privateDnsZoneGroup` auto-populates A records** for all currently-scoped resources whose FQDNs live in that zone. No manual A-record management needed.

2. **The workspace's ODS endpoint FQDN CNAMEs to `<wsid>.privatelink.ods.opinsights.azure.com` in PUBLIC DNS** — regardless of whether you've set up private link. This is Azure DNS's global behavior. The private link is "active" only when a private DNS zone with that name is linked to the caller's VNET.

3. **CLI shortcut `--private-dns-zone` on `az network private-endpoint create` takes ONE zone**, not a list. IaC/CLI users must loop or use ARM template with a `privateDnsZoneConfigs` array.

4. **Portal "Integrate with private DNS zone = Yes" does all 5 zones + all 5 links automatically** in the PE's VNET. That's the safe path.

---

## Documentation gaps that lead customers here

The docs are correct but easy to misread:

| Doc | What it says | What customers infer |
|---|---|---|
| [private-link-configure](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-configure) | "Select Yes to automatically create **a** new private DNS zone" (singular) | "One zone is enough" — misses that portal actually creates 5 |
| [private-link-vm-kubernetes](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-vm-kubernetes) | Focuses on DCE + LAW scoping. Doesn't enumerate the 5 required zones. | "As long as LAW+DCE are in AMPLS, ingestion works" |
| [private-endpoint-dns](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns) | Lists all 5 zones for AMPLS in one row | Reference material — customers rarely find this before hitting the bug |
| Never explicitly stated anywhere | "You must link ALL 5 zones to the workload VNET (not just the PE VNET)" | Customer misses hub-and-spoke split |
| Never explicitly stated anywhere | "Adding a scoped resource after PE creation does NOT retroactively update the PE's dnsZoneGroup" | Customer changes AMPLS scope, PE stays stale |

Where a customer most commonly goes wrong (based on this repro + the ICM patterns):

1. **CLI path**: They read `az network private-endpoint create` example that shows `--private-dns-zone privatelink.monitor.azure.com` and don't realize they need `az network private-endpoint dns-zone-group add` for each of the other 4 zones.

2. **Portal path with hub-and-spoke**: They ran the wizard in the hub VNET where the PE lives. Portal linked all 5 zones to the hub. AKS spoke VNET has zero zone links; peering alone doesn't propagate DNS zone links.

3. **Portal wizard with "Integrate = No"**: Customer opted out of auto DNS (maybe they wanted to reuse existing zones), then only manually added the ones they noticed were failing.

4. **IaC template**: Bicep/Terraform template with a hand-authored zone array missing 1-2 entries.

5. **Sequence mistake**: Workspace added to AMPLS AFTER the PE was created. Portal auto-integration only sees resources at PE creation time; adding scoped resources later does not retroactively refresh the PE's dnsZoneGroup.

---

## Six real-world onboarding paths that produce this state

The AKS onboarding flow (`az aks enable-addons -a monitoring`) does NOT touch AMPLS. AMPLS setup is a separate flow, usually done by a different team, days or weeks before AKS onboard. Nothing wires them together and nothing validates that the workspace's ODS FQDN can resolve to the PE from the AKS VNET. That's the root of every path below.

### Path 1 — Terraform / Bicep with hand-authored zone list (most common in enterprise)

Common Terraform pattern:
```hcl
resource "azurerm_private_endpoint" "ampls" {
  ...
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.monitor.id
      # missing: ods, oms, agentsvc, blob
    ]
  }
}
```
Original author was thinking "AMPLS = monitor endpoint". Module got copy-pasted across teams for years. Fix in the module → propagate.

### Path 2 — CLI with `--private-dns-zone` singular

`az network private-endpoint create --private-dns-zone <one>` takes exactly one zone. Docs snippets show singular usage. Operator runs the command, sees `Succeeded`, moves on. Never runs the `az network private-endpoint dns-zone-group add` for the other 4.

### Path 3 — Portal wizard with "Integrate = No"

Customer opts out of auto DNS integration during PE creation. Reasons:
- Enterprise DNS governance requires zones in a central subscription
- They already have some `privatelink.*` zones for other services
- They don't have permission to create zones in the PE's RG

Then they manually add `privatelink.monitor.azure.com` because MCS wasn't resolving. Skip the others because they didn't know about them.

### Path 4 — PE created before LAW was scoped in AMPLS (sequence bug)

Team sets up AMPLS with only DCE scoped → creates PE with dnsZoneGroup containing only monitor zone (either manually or because Portal was smart about "only monitor endpoints needed for DCE"). LAW added to AMPLS **later**. LAW's A record has nowhere to write. The PE's dnsZoneGroup is frozen at creation time — adding scoped resources to AMPLS never modifies it.

### Path 5 — Azure Policy / Enterprise Landing Zone

Some enterprise subscriptions have policy that auto-attaches `privateDnsZoneGroup` to any PE created for AMPLS. If the policy was authored with an incomplete zone list (very common — policy authors work from doc snippets that don't enumerate all 5), every PE in the subscription inherits the same gap.

Signature: same misconfiguration on multiple PEs across the subscription. Fix in one place, remediate downstream.

### Path 6 — Hub-and-spoke DNS with partial forwarders

PE created correctly with all 5 zones in dnsZoneGroup, all 5 zones auto-linked to the hub VNET. AKS lives in a spoke VNET. Peering + custom DNS server on the hub means spokes can resolve zones — as long as every zone is on the resolver. DNS admin adds `monitor.azure.com` (obvious one) and misses the others.

### The right diagnostic question to ask the customer

Don't ask "how did you set up AMPLS?". Ask:
> "How was your AMPLS PE created — Terraform, Bicep, Portal, or CLI? If it's IaC, can you share the module or template?"

The answer tells you which path they're on:
| Answer | Path | Fix scope |
|---|---|---|
| Terraform / Bicep module | 1 | Fix code, remediate all downstream PEs |
| CLI commands | 2 | One-off remediation + educate operator |
| Portal wizard, chose "Integrate = No" | 3 | One-off remediation via portal "Add configuration" |
| "The DCE was there first, then we added the LAW" | 4 | Remediation via portal or `dns-zone-group add` |
| Azure Policy auto-attaches | 5 | Fix policy definition, run remediation task on subscription |
| Custom DNS server in the hub | 6 | Fix conditional forwarders / VNET link on hub


---

## Common misconceptions we need to correct

| Belief | Reality |
|---|---|
| "curl -v to the endpoint returns 200, so private link works" | curl proves TCP+TLS only. Public ODS gateway is reachable from anywhere. Only the DNS-resolved IP matters. |
| "AMPLS ingestion access mode = Private Only blocks the 403" | LA ingestion **does not adhere to AMPLS access modes** — see [private-link-design](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-design). The workspace's own `publicNetworkAccessForIngestion` gates it. |
| "Auto-integrated DNS covers everything" | Auto-integration links zones to the PE's VNET only. If AKS is in a different VNET (hub-and-spoke), those zones still need to be linked to the AKS VNET separately. |
| "The 403 is an AMCS/token/RBAC issue" | If gig token retrieval succeeds (see mdsd.info), the auth pipeline is healthy. Same token, rejected at ODS = network path, not auth. |
| "No telemetry in ContainerInsightsAgent-Prod = agent broken" | Private-link clusters can't reach our internal App Insights. This is expected. Verify in customer's workspace. |
| "LOGS_AND_EVENTS_ONLY blocks syslog collection" | It doesn't. Syslog datasource is separate from ContainerInsightsExtension in `dcr-config-parser.rb`; `main.sh` enables the syslog listener before the flag is set. |
| "AAD MSI mode uses DCE ingest endpoint" | Container Insights uploads use workspace-specific ODS endpoint regardless of auth mode. `IsAADMSIAuthMode` only changes the auth token. |
| "AKS RP's private cluster setup covers monitoring private link" | No. AKS private-cluster provisions `privatelink.{region}.azmk8s.io` for the API server — completely separate from AMPLS zones. |

---

## Common Fixes

| Scenario | Fix |
|---|---|
| Private DNS zone `privatelink.ods.opinsights.azure.com` not linked to AKS VNET | `az network private-dns link vnet create -g <zone-rg> -z privatelink.ods.opinsights.azure.com -n aks-link --virtual-network <aks-vnet-id> --registration-enabled false` → delete ama-logs pods |
| ODS zone doesn't exist because LAW was added after PE creation | Edit PE's dnsZoneGroup to include ODS zone integration; portal: PE → DNS configuration → add zone. Then delete ama-logs pods. |
| LAW not scoped to AMPLS | `az monitor private-link-scope scoped-resource create --resource-group <ampls-rg> --scope-name <ampls> --name law-conn --linked-resource <law-id>` |
| Custom DNS resolver in AKS VNET | Add conditional forwarders for all 5 privatelink.* zones → Azure DNS (`168.63.129.16`) |
| Private cluster, no AMPLS at all | Follow [Enable private link for AKS](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-vm-kubernetes); ensure workspace + DCE scoped, PE created with auto-DNS integration |
| Missing DCE for private cluster | Create DCE in same region as cluster, associate to cluster, add to AMPLS |
| Legacy image reference | Update to `mcr.microsoft.com/azuremonitor/containerinsights/ciprod` |
| OMS Homing failures (legacy auth) | Check `privatelink.oms.opinsights.azure.com` zone link |

## References
- [Enable private link for AKS](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-vm-kubernetes)
- [Configure Azure Monitor private link](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-configure)
- [Design Azure Monitor private link](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-design)
- [Azure Private Endpoint DNS reference](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns) ← **the authoritative list of 5 zones**

## IaC docs — what's actually in them (and where the gaps are)

Customers using Terraform/Bicep/ARM for AMPLS often end up in this state because **the official templates don't include the DNS zones + VNET links + `privateDnsZoneGroup`**. They have to hand-author that part from a separate checklist in the docs and it's easy to miss.

| Source | AMPLS resource | Scoped resources | Private endpoint | 5 DNS zones | VNET links | dnsZoneGroup on PE |
|---|---|---|---|---|---|---|
| [Microsoft Learn — Configure private link](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-configure) (ARM template) | ✅ | ✅ | ❌ | ❌ (listed as manual checklist only) | ❌ | ❌ |
| [Microsoft Learn — Configure private link](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-configure) (Bicep template) | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| [Microsoft Learn — templates/privatelinkscopes](https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/privatelinkscopes) | ✅ (schema only) | — | — | — | — | — |
| [Microsoft Learn — private-link-vm-kubernetes](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-vm-kubernetes) | Assumes AMPLS already exists — no template | — | — | — | — | — |
| [Terraform Registry — azurerm_monitor_private_link_scope](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_private_link_scope) | ✅ | — | — | — | — | — |
| [Terraform Registry — azurerm_monitor_private_link_scoped_service](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_private_link_scoped_service) | — | ✅ | — | — | — | — |
| [Terraform community module: libre-devops/terraform-azurerm-monitor-private-link-scope](https://github.com/libre-devops/terraform-azurerm-monitor-private-link-scope) | ✅ | ✅ | ✅ | Only 1 zone (`monitor`) | Only 1 link | Only 1 config |
| AI-generated Terraform / blog examples | Variable | Variable | Usually includes | **Frequently wrong zone names** (invents `privatelink.logs.azure.com`, `privatelink.applicationinsights.azure.com`) | Variable | Variable |

**Trust order for a customer's IaC review**:
1. Correct list of zones → [private-endpoint-dns](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns) — the only authoritative list.
2. Wire up AMPLS + scoping → any of the Microsoft ARM/Bicep/Terraform samples work.
3. Wire up the PE + DNS zones + VNET links → **no complete official example exists**. The customer has to combine (1) with a private-endpoint-with-dns-zone-group pattern. This is the gap.

**Reference template we validated against the repro** — includes all 5 zones + links + a full `privateDnsZoneGroup`:

```bicep
param location string = resourceGroup().location
param amplsName string
param peName string
param peSubnetId string
param vnetId string

var zones = [
  'privatelink.monitor.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.agentsvc.azure-automation.net'
  'privatelink.blob.core.windows.net'
]

resource ampls 'Microsoft.Insights/privateLinkScopes@2023-06-01-preview' existing = {
  name: amplsName
}

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for z in zones: {
  name: z
  location: 'global'
}]

resource dnsLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (z, i) in zones: {
  name: '${z}/aks-vnet-link'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnetId }
    registrationEnabled: false
  }
  dependsOn: [ dnsZones[i] ]
}]

resource pe 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: peName
  location: location
  properties: {
    subnet: { id: peSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'ampls-conn'
        properties: {
          privateLinkServiceId: ampls.id
          groupIds: [ 'azuremonitor' ]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [for (z, i) in zones: {
      name: replace(z, '.', '-')
      properties: { privateDnsZoneId: dnsZones[i].id }
    }]
  }
}
```

Share this with the customer if they need a corrected IaC snippet. Notes:
- Uses `existing` for the AMPLS — assumes AMPLS + LAW + DCE + scoping is already declared elsewhere.
- The `privateDnsZoneConfigs` array with all 5 entries is the piece that's missing from most of the field examples above.
- Links every zone to the AKS VNET explicitly (adjust if using a hub-DNS pattern instead).

## Escalation
- **Missing / misconfigured DNS zones**: Customer network/DNS team owns the fix
- **AMPLS resource / DCE / DCR configuration**: Azure Monitor Control Service (AMCS) / Triage
- **Workspace ingestion 403 with private IP resolution + LAW correctly scoped**: Azure Log Analytics → Ingestion
- **Portal experience**: Azure Portal IaaS Experiences / Triage

## References
- [Enable private link for AKS](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-vm-kubernetes)
- [Configure Azure Monitor private link](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-configure)
- [Design Azure Monitor private link](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-design)
- [Azure Private Endpoint DNS reference](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns)
