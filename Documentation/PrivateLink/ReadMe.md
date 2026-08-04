# Private Link documentation for AKS + Log Analytics

This folder contains reference documentation for the AMPLS + AKS + Log Analytics end-to-end configuration.

## Files

- [`tutorial-aks-ampls-log-analytics.md`](tutorial-aks-ampls-log-analytics.md) — proposed Microsoft Learn tutorial that walks through the complete setup with CLI commands, a Bicep template, portal steps, and verification steps. Intended as a starting point for a docs PR against `MicrosoftDocs/azure-monitor-docs` to close the end-to-end walkthrough gap identified during ICM 21000001094698.
- [`screenshots/`](screenshots/) — reference screenshots captured against a real portal deployment (Grace's dev sub, 2026-08-04) as visual aids for the portal steps in the tutorial. These need to be re-captured in a clean tenant before the docs PR ships. See the inventory below.

## Screenshot inventory

| File | What it shows | Referenced in tutorial |
|---|---|---|
| `01-create-law.png` | Create Log Analytics workspace, Basics tab | Step 2 (Portal tab) |
| `02-create-dce.png` | Create Data Collection Endpoint (deep link attempt) | — |
| `02-dce-list.png` | Data Collection Endpoints list with **Create** button | Step 2 (Portal tab) |
| `03-ampls-scoped-resources.png` | AMPLS **Azure Monitor Resources** blade with LAW + DCE scoped | Step 3 (Portal tab) |
| `04-pe-wizard-basics.png` | Create private endpoint wizard, **Basics** tab | Step 4 (Portal tab) |
| `04-pe-wizard-resource.png` | Create private endpoint wizard, **Resource** tab | Step 4 (Portal tab) |
| `04-pe-wizard-dns-tab-yes.png` | Create private endpoint wizard, **DNS** tab with `Integrate with private DNS zone = Yes` and all 5 zones auto-listed | Step 4 (Portal tab) — the key visual for the "recommended path" |
| `04-pe-wizard-dns-tab-disabled-by-id-alias.png` | DNS tab with `Yes` disabled because the Resource tab used **Connect by resource ID or alias** | Step 4 (Portal tab) — the warning callout |
| `05-pe-dns-configuration.png` | PE DNS configuration blade top (viewport) | — |
| `05-pe-dns-config-healthy.png` | PE DNS configuration blade mid-scroll | — |
| `05-pe-dns-config-full.png` | PE DNS configuration blade with 5 zone configs showing A records | Step 4 (Portal tab) — "Integrate = Yes" outcome |
| `06-law-network-isolation.png` | Log Analytics workspace **Network Isolation** blade | Step 7 (Portal tab) |
| `06-law-public-network-access.png` | LAW **Public network access** management pane with Ingestion / Query radio options | Step 7 (Portal tab) |

Notes for the docs PR:
- Screenshots were captured against the current Azure portal (as of 2026-08-04). Portal UI drifts — re-verify before shipping.
- Screenshots contain Grace's tenant/subscription info (`ContainerInsights_Dev_Grace`, `grwehner@microsoft.com`). Docs team should re-capture in a clean tenant using anonymized names.

## Background

Existing Microsoft Learn docs cover pieces of the AMPLS + AKS + Log Analytics setup but never as a single flow:

- [`azure-monitor/fundamentals/private-link-configure`](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-configure) — sets up AMPLS + workspace + scoping only. Templates omit the private endpoint, five DNS zones, VNET links, and `privateDnsZoneGroup`.
- [`azure-monitor/fundamentals/private-link-vm-kubernetes`](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-vm-kubernetes) — assumes AMPLS is already correctly configured; covers only DCE scoping and cluster association.
- [`private-link/private-endpoint-dns`](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns) — the only authoritative source listing the five required Private DNS zones; it's a reference table across all Azure services, not an Azure Monitor–specific walkthrough.

The customer failure pattern is consistent: they wire up `privatelink.monitor.azure.com` (which makes DCE/MCS work) but miss `privatelink.ods.opinsights.azure.com` (which is what the workspace's log-ingestion FQDN needs). All uploads then return HTTP 403 from the workspace's ODS gateway.

This tutorial closes that gap by giving customers a single canonical path that includes DNS verification from inside the cluster — the check that catches the failure before it becomes a production incident.
