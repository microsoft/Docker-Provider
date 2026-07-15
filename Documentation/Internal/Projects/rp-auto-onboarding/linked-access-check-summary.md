# Linked Access Check for ama-logs — What It Is & Can & How We Remove It

*Short, shareable overview, organized as five questions: (1) what the linked
access check is in the scope of ama-logs, (2) why it is needed now, (3) why we
want to remove it, (4) whether we can remove it, and (5) how it can be removed.*

---

## TL;DR

The omsagent linked access check is **four ANDed checks**. They fall into two
groups with different removal conditions:

| Check(s) | What it gates | Paths affected | Removal condition |
|---|---|---|---|
| **#1, #3, #4** — `sharedkeys/read`, `solutions/write`, `solutions/read` | Legacy shared-key + OMS-solutions onboarding (the workspace **key** aks-rp fetches and the ContainerInsights solution) | **Legacy only** (not exercised on MSI) | Remove when **either** (a) the legacy shared-key path of ama-logs is **fully retired** *(**preferred**)*, **or** (b) **aks-rp performs the same checks on behalf of the user**. |
| **#2** — `workspaces/read` | Caller's read guard on the workspace; mirrors the workspace **GET** aks-rp does (**both** paths) to read the workspace **GUID** (`CustomerID`) injected into the ama-logs helm chart | **Both** legacy and MSI | Remove when **either** (a) we **do not inject the customer's workspace ID into our telemetry** — feasible on **MSI**, where the agent can self-derive the GUID from its local DCR config chunks (see Q4), but **not** on legacy shared-key onboarding — **or** (b) **aks-rp performs the same read check on behalf of the user** *(**preferred** — supportable once ama-logs integrates **OBO** in aks-rp)*. |

---

## 1. What is it, in the scope of ama-logs?

**Linked access check** = an ARM manifest rule that ties a write on **one**
resource to the caller's permission over a **different** resource named in the
request body.

For ama-logs enabling, the caller makes an ARM call to write a **cluster**, and
the call includes a workspace ID. So ARM enforces:

> When you `PUT` a cluster with a workspace ID in the body, you must **already
> have permission on that workspace** — otherwise ARM returns **403** before
> aks-rp ever runs.

**What it actually checks:** the gate is defined as **four** linked-access-check
records. All four share the same **trigger** (`actionName` =
`Microsoft.ContainerService/managedClusters/write`) and the same **body
property** (`linkedProperty` =
`properties.addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID`), and
differ only in the **linked action** (`linkedAction`) they demand.

A single qualifying `PUT` fires **all four**, and the caller must hold **every**
linked action on the target workspace — any miss → 403:

| # | linkedAction (caller must hold on the workspace) | What it authorizes |
| --- | --- | --- |
| 1 | `Microsoft.OperationalInsights/workspaces/sharedkeys/read` | read the workspace **shared keys** — for the **legacy shared-key** path (the key the RP fetches) |
| 2 | `Microsoft.OperationalInsights/workspaces/read` | read the workspace |
| 3 | `Microsoft.OperationsManagement/solutions/write` | install the legacy **ContainerInsights OMS solution** (a **write**) |
| 4 | `Microsoft.OperationsManagement/solutions/read` | read legacy OMS solution state |

**Notes on the four:**
- **#1 is specific to the legacy (shared-key) ama-logs path** — it gates the
  workspace key that the RP will fetch. On the managed-identity path no shared
  key is used, so this action isn't functionally exercised.
- **#3 and #4 are also legacy artifacts** — `Microsoft.OperationsManagement/solutions/*`
  is the old **OMS "solutions"** model, where Container Insights
  installed a `ContainerInsights(workspace)` *solution* on the workspace. This is
  **not** part of the MSI path.
- So three of the four checks (#1, #3, #4) exist to support **legacy onboarding**.
- **#2 (`workspaces/read`) applies to both paths** — it's the caller's read guard
  on the workspace, and it mirrors the workspace **GET** aks-rp itself does (on both
  legacy and MSI paths) to read the workspace **GUID** (`CustomerID`) that gets
  injected into the ama-logs helm chart. So #2 is the only check that does real work
  on the MSI path.
- **#3 is a write** — so a pure workspace *Reader* is not enough to pass the
  gate; onboarding needs a write-capable role on the workspace side.

**Scope of linked property:** this gate is attached **only to the omsagent addonProfile
path**. The newer **azureMonitorProfile** onboarding surface has **no linked
access check at all** today — so the check as it exists is entirely a
**legacy-omsagent** construct.

---

## 2. Why is it needed now for ama-logs?

After ARM forwards the request, aks-rp fetches the workspace's **shared key**
using its **own first-party identity (service principal)** — *not* the caller's
identity. Because the RP acts as itself, nothing downstream re-checks whether the
*caller* was allowed to use that workspace.

➡️ **The linked access check is the only place the caller's workspace permission
is verified** (see Q4 for the per-path impact). Remove it with nothing else
changing, and any caller who can create a cluster could point it at a workspace
they don't own and have the RP pull that workspace's key for them.

#1, #3, and #4 are **only on the legacy shared-key path** — that's the path that
fetches a key. The azureMonitorProfile (managed-identity) path has no linked
access check and uses managed identity instead of a shared key.

#2 is a general read permission, this guards that user can not use a workspace id that the user has no read permission to when enabling ama-logs.

**What #2 (`workspaces/read`) actually enables in aks-rp:** aks-rp itself performs
a workspace **GET** (`workspaces/read`) — on **both** the legacy and MSI paths — to
read the workspace's `CustomerID` (the workspace GUID). That GUID is stored as the
omsagent addon config `WorkspaceID` and injected into the **ama-logs helm chart** so
the agent knows which workspace to send data to. The RP does this GET with its
**own first-party identity**; linked-access-check #2 is the caller-side mirror,
enforcing that the user who issued the PUT also has read on that same workspace.
This is why #2 is the one check that does real work on the MSI path.
(Source: `putmanagedclusterasync_addon.go` → `getLogAnalyticsWorkspaceInfo` —
workspace GET → `customerID` → `AddonConfigOmsWorkspaceID`; `oms_agent.go` helm
values → `WorkspaceID`.)

---

## 3. Why do we want to remove it?

1. The linked access check does not work during **region build**. During region
   build, the workspace is not yet available, so we need to bootstrap from a
   workspace in another GA region — and **cross-region linked access check is not
   supported**.
2. The **legacy path of ama-logs is retiring**, so there is no need to keep the linked access check in ARM, at least #1, #3, and #4.

---

## 4. Can we remove it?

### Impact of removing it — by auth path

The two ama-logs auth paths are affected very differently, because only the
legacy path actually relies on this gate:

**Legacy (shared-key) path — high impact:**
- Today the linked access check is the **only** place the caller's workspace
  permission is verified. After ARM, aks-rp fetches the workspace **shared key**
  as the **RP's own identity**, not the caller's.
- Remove the check with nothing else in place, and any caller who can `PUT` a
  cluster could point it at a **workspace they don't own** and have the RP fetch
  and inject that workspace's shared key into their cluster — i.e. a
  **shared-key exfiltration** risk. This path **cannot** lose the check without a
  replacement caller-side permission enforcement.

**Managed-identity (MSI) path — low impact:**
- On the MSI path no shared key is fetched (the RP skips the key fetch), so the
  `sharedkeys/read` check (#1) isn't functionally exercised, and the legacy OMS
  `solutions/*` checks (#3/#4) don't apply either — for these three the gate is
  effectively **over-gating** this path today.
- **#2 (`workspaces/read`) is the exception** — it still does real work on the
  MSI path: it's the caller's read-permission guard on the workspace, and it
  applies regardless of auth path (it stops a caller associating a workspace they
  can't even read).
- Removing the check here means a caller could **associate** a cluster to a
  workspace they don't own, but **no key is issued** — workspace authentication
  still requires the cluster's managed identity + a **DCR association**, which is
  a **separate RBAC grant** the caller does not obtain via this `PUT`. So the
  impact is **"associate-to-unowned-workspace only,"** not secret exposure.


Therefore,
For #1, #3, and #4:
1. The **legacy path of ama-logs is fully retired**. *(**preferred**)*
Or,
2. **aks-rp can support the same functions** that the linked access check does **on behalf of the user**.

For #2:
#2 (`workspaces/read`) backs **two** things: (a) aks-rp reading the workspace
**GUID** (`CustomerID`) to inject into the ama-logs helm chart, and (b) the
caller-side permission guard on the workspace (ama-logs telemetry onboarding).
It can be removed when **either**:
1. we **do not inject the customer's workspace ID into our telemetry**, **or**
2. **aks-rp can support the same functions** that the linked access check does **on behalf of the user**. *(**preferred** — supportable once ama-logs integrates **OBO** in aks-rp)*

**More on option (a) — can the agent obtain the workspace ID itself?**
For **MSI-onboarded** clusters, **yes**: the ama-logs agent can self-derive the
workspace GUID from the **DCR config chunks** that `mdsd` fetches from AMCS at
runtime (using the agent's own MSI/AAD token), cached locally in the container at
`/etc/mdsd.d/config-cache/configchunks/*.json`. Modern DCR config has no literal
`workspaceId` field — the GUID is embedded in the **ODS channel** the data routes
to: `channels[].endpoint = https://<GUID>.ods.opinsights.azure.com` (and
`sendToChannels -> "ods-<GUID>"`). So on MSI, aks-rp would **not** need to inject
the workspace ID — the agent already has it via the DCR-issued channel config.
- **Caveat — MSI only.** This relies on the AMCS/DCR path, which is the MSI/AAD
  onboarding path. **Legacy shared-key** onboarding does **not** use AMCS/DCR
  chunks; there the workspace ID still comes from the `WSID` secret/env that
  aks-rp injects, so option (a) does **not** cover the legacy path.
- Verified: the GUID extracted from the DCR chunk matched the pod's onboarded
  `/etc/omsagent-secret/WSID`. *(Source: sibling investigation —
  `mdsd-workspaceid-from-configchunks.md`.)*


---

## 5. How can we remove it?

- The linked access check lives in the **Microsoft.ContainerService ARM manifest
  source** (not in aks-rp code). Removal = deleting/relaxing those four manifest
  entries on the omsagent property.
- It is a static manifest change; aks-rp code is unchanged by the removal itself.

---

## Bottom line

The linked access check is a **front-door permission gate**. Its legacy-specific
weight (#1, #3, #4) is on the **shared-key path**, where aks-rp fetches the
workspace key as the **RP's identity, not the caller's** — making the gate the only
caller-side check for that key. **#2 (`workspaces/read`) is different**: it applies
to **both** paths and mirrors the workspace **GET** aks-rp performs to read the
workspace **GUID** (`CustomerID`) it injects into the ama-logs helm chart, so on the
**MSI path #2 still does real work** (the legacy checks #1/#3/#4 do not). Any plan to
remove it must therefore (a) keep caller-permission enforcement for the **legacy**
shared-key path, and (b) for #2, either stop injecting the customer's workspace ID
into our telemetry, or have aks-rp enforce the same read check on behalf of the user.

---

*Read-only research summary. No repo or manifest files were modified.*
