# Private Link documentation for AKS + Log Analytics

This folder contains reference documentation for the AMPLS + AKS + Log Analytics end-to-end configuration.

## Files

- [`tutorial-aks-ampls-log-analytics.md`](tutorial-aks-ampls-log-analytics.md) — proposed Microsoft Learn tutorial that walks through the complete setup with CLI commands, a Bicep template, and verification steps. Intended as a starting point for a docs PR against `MicrosoftDocs/azure-monitor-docs` to close the end-to-end walkthrough gap identified during ICM 21000001094698.

## Background

Existing Microsoft Learn docs cover pieces of the AMPLS + AKS + Log Analytics setup but never as a single flow:

- [`azure-monitor/fundamentals/private-link-configure`](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-configure) — sets up AMPLS + workspace + scoping only. Templates omit the private endpoint, five DNS zones, VNET links, and `privateDnsZoneGroup`.
- [`azure-monitor/fundamentals/private-link-vm-kubernetes`](https://learn.microsoft.com/en-us/azure/azure-monitor/fundamentals/private-link-vm-kubernetes) — assumes AMPLS is already correctly configured; covers only DCE scoping and cluster association.
- [`private-link/private-endpoint-dns`](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns) — the only authoritative source listing the five required Private DNS zones; it's a reference table across all Azure services, not an Azure Monitor–specific walkthrough.

The customer failure pattern is consistent: they wire up `privatelink.monitor.azure.com` (which makes DCE/MCS work) but miss `privatelink.ods.opinsights.azure.com` (which is what the workspace's log-ingestion FQDN needs). All uploads then return HTTP 403 from the workspace's ODS gateway.

This tutorial closes that gap by giving customers a single canonical path that includes DNS verification from inside the cluster — the check that catches the failure before it becomes a production incident.
