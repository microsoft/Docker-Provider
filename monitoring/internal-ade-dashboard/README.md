# Internal ADE Dashboard Files

## Dashboard Versions

| File | Description |
|------|-------------|
| `(Original)Container-Insights-Logs-Addon.json` | Original dashboard without process metrics |
| `(New)Container-Insights-Logs-Addon-with-ProcessMetrics-readable.json` | Readable/formatted version with process metrics |
| `(New-NoUpdate)Container-Insights-Logs-Addon-with-ProcessMetrics.json` | Process metrics version (no updates) |
| `Container-Insights-Logs-Addon-with-ProcessMetrics-04152026.json` | Snapshot from 04/15/2026 |
| `Container-Insights-Logs-Addon-with-ProcessMetrics-04222026.json` | Snapshot from 04/22/2026 |
| `Container-Insights-Logs-Addon-with-ProcessMetrics-04232026.json` | Snapshot from 04/23/2026 |
| `Container-Insights-Logs-Addon-with-ProcessMetrics-04242026.json` | **Latest** — snapshot from 04/24/2026 (based on 04/15 file) |
| `downloadeddashboard-zane-dashboard-test.json` | Test dashboard (downloaded from portal) |

## What's New in 04/24/2026

Added **18 new "Memory Anonymous P90 (MB)" panels** appended at the end of the process metrics page, based on the 04/15 dashboard.

### Why

Telegraf procstat `memory_rss` reports `VmRSS = RssAnon + RssFile`. RssFile includes shared library text and binary code loaded via mmap, which the kernel can evict and re-read from disk. These pages are not charged to the container's cgroup and are excluded from container-level RSS (`memoryRssBytes`) and working set (`workingSetBytes`). This makes `memory_rss` appear inflated compared to container-level metrics.

The new `memory_anonymous` metric reports only RssAnon (heap, stack), which maps closely to container-level RSS (cgroup `anon`) and is more meaningful for capacity planning.

### New Panels

**Linux** (8 panels):
mdsd, fluent-bit, telegraf, ruby, crond, inotifywait, fluentd, main.sh

**Windows** (10 panels):
fluent-bit, telegraf, MonAgentLauncher, MonAgentCore, MonAgentHost, MonAgentManager, AzurePerfCollectorExtension, AzureProfilerExtension, AggregatorHost, powershell

### Prerequisite

Requires `memory_anonymous` in the procstat `fieldpass` config — see branch `zane/add-memory-anonymous`.
