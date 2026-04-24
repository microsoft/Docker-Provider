# Internal ADE Dashboard Files

## Dashboard Versions

| File | Description |
|------|-------------|
| `(Original)Container-Insights-Logs-Addon.json` | Original dashboard without process metrics |
| `(New)Container-Insights-Logs-Addon-with-ProcessMetrics-readable.json` | Readable/formatted version with process metrics |
| `(New-NoUpdate)Container-Insights-Logs-Addon-with-ProcessMetrics.json` | Process metrics version (no updates) |
| `Container-Insights-Logs-Addon-with-ProcessMetrics-04152026.json` | Snapshot from 04/15/2026 |
| `Container-Insights-Logs-Addon-with-ProcessMetrics-04222026.json` | Snapshot from 04/22/2026 — fluentd query fix (`pattern` → `exe`) |
| `Container-Insights-Logs-Addon-with-ProcessMetrics-04232026.json` | Snapshot from 04/23/2026 |
| `Container-Insights-Logs-Addon-with-ProcessMetrics-04242026.json` | **Latest** — snapshot from 04/24/2026 (based on 04/15 file) |
| `downloadeddashboard-zane-dashboard-test.json` | Test dashboard (downloaded from portal) |

## What's New in 04/24/2026

### Fix: fluentd dashboard query uses `exe` instead of `pattern`

Changed fluentd process metrics queries from `customDimensions.pattern == "fluentd"` to `customDimensions.exe == "fluentd"` in `Container-Insights-Logs-Addon-with-ProcessMetrics-04222026.json` (2 queries: memory_rss and cpu_usage for fluentd).

**Why:** `pattern = "fluentd"` in procstat matches both the fluentd supervisor (PID name=`fluentd`) and the ruby worker (PID name=`ruby`), causing fluentd and ruby to show identical values on the dashboard. Using `exe = "fluentd"` matches only the supervisor process, so ruby and fluentd now report distinct memory/CPU values.

### Added 18 new "Memory Anonymous P90 (MB)" panels

Added panels appended at the end of the process metrics page, based on the 04/15 dashboard.

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
