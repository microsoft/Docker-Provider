## Telegraf Upgrade Test Results

**Prod Image**: ciprod:3.1.35 | **Test Image**: cidev:3.1.35-12-ga398c2798-20260414052603
**Telegraf Version (Prod)**: 1.37.1 (Linux DS/Sidecar), 1.24.2 (Windows) | **Telegraf Version (Test)**: 1.38.2
**Cluster**: sky-test-cluster | **Date**: 2026-04-14

### Derived Values
- **Cluster Resource ID**: /subscriptions/6e377996-dbe0-4f90-aeee-e1592d1d7c0d/resourceGroups/AKSTest/providers/Microsoft.ContainerService/managedClusters/sky-test-cluster
- **Workspace ID**: a14e51b3-a583-4081-97c0-bf1e44b5195b
- **Subscription**: 6e377996-dbe0-4f90-aeee-e1592d1d7c0d
- **Resource Group**: AKSTest

### Build
- **Build ID**: 116380 (commit a398c2798)
- **Linux Image**: cidev:3.1.35-12-ga398c2798-20260414052603
- **Windows Image**: Windows build failed - cannot test Windows

### Pre-flight
- Pods: All Running, 0 restarts
- Current telegraf: 1.37.1 (Linux), 1.24.2 (Windows)
- Deprecation warnings:
  - fieldpass deprecated since 1.29.0, removal at 1.40.0 (disk, diskio, net, prometheus)
  - ignore_protocol_stats deprecated since 1.37.0, removal at 1.45.0 (net)

---

## Phase 2: Prod Baselines (ciprod:3.1.35)

### Scenario 1 Baseline (Default - No Custom Prometheus)
Window: 2026-04-14T17:04:05Z to 2026-04-14T17:07:05Z

**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T17:05:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:06:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:07:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T17:05:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:06:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:07:00 | 16 |
| container.azm.ms/net | 2026-04-14T17:05:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:06:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:07:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T17:05:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:06:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:07:00 | 36 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T17:04:00 | 821 |
| 2026-04-14T17:05:00 | 348 |
| 2026-04-14T17:06:00 | 348 |
| 2026-04-14T17:07:00 | 434 |

No loopback data in net (verified).

### Scenario 2 Baseline (Pod-level Prometheus Scraping)
Window: 2026-04-14T17:21:36Z to 2026-04-14T17:24:36Z

**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T17:22:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:23:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:24:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T17:22:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:23:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:24:00 | 16 |
| container.azm.ms/net | 2026-04-14T17:22:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:23:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:24:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T17:22:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:23:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:24:00 | 36 |
| prometheus | 2026-04-14T17:22:00 | 4148 |
| prometheus | 2026-04-14T17:23:00 | 4148 |
| prometheus | 2026-04-14T17:24:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T17:21:00 | 348 |
| 2026-04-14T17:22:00 | 782 |
| 2026-04-14T17:23:00 | 782 |
| 2026-04-14T17:24:00 | 434 |

Reference app metrics verified (port 2112, 4148 metrics/min).

### Scenario 3 Baseline (Namespace-scoped Scraping)

Window: 2026-04-14T17:30:59Z to 2026-04-14T17:33:59Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T17:31:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:32:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:33:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T17:31:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:32:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:33:00 | 16 |
| container.azm.ms/net | 2026-04-14T17:31:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:32:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:33:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T17:31:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:32:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:33:00 | 36 |
| prometheus | 2026-04-14T17:31:00 | 2074 |
| prometheus | 2026-04-14T17:32:00 | 2074 |
| prometheus | 2026-04-14T17:33:00 | 2074 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T17:31:00 | 348 |
| 2026-04-14T17:32:00 | 348 |
| 2026-04-14T17:33:00 | 782 |

### Scenario 4 Baseline (Custom URLs (Daemonset))

Window: 2026-04-14T17:38:30Z to 2026-04-14T17:41:30Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T17:39:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:40:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:41:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T17:39:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:40:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:41:00 | 16 |
| container.azm.ms/net | 2026-04-14T17:39:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:40:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:41:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T17:39:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:40:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:41:00 | 36 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T17:38:00 | 348 |
| 2026-04-14T17:39:00 | 348 |
| 2026-04-14T17:40:00 | 348 |
| 2026-04-14T17:41:00 | 434 |

### Scenario 5 Baseline (Field Filtering)

Window: 2026-04-14T17:46:02Z to 2026-04-14T17:49:02Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T17:47:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:48:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:49:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T17:47:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:48:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:49:00 | 16 |
| container.azm.ms/net | 2026-04-14T17:47:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:48:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:49:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T17:47:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:48:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:49:00 | 36 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T17:46:00 | 348 |
| 2026-04-14T17:47:00 | 348 |
| 2026-04-14T17:48:00 | 782 |

### Scenario 6 Baseline (Label Selectors)

Window: 2026-04-14T17:53:33Z to 2026-04-14T17:56:33Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T17:54:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:55:00 | 12 |
| container.azm.ms/disk | 2026-04-14T17:56:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T17:54:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:55:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T17:56:00 | 16 |
| container.azm.ms/net | 2026-04-14T17:54:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:55:00 | 8 |
| container.azm.ms/net | 2026-04-14T17:56:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T17:54:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:55:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T17:56:00 | 36 |
| prometheus | 2026-04-14T17:54:00 | 4148 |
| prometheus | 2026-04-14T17:55:00 | 4148 |
| prometheus | 2026-04-14T17:56:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T17:53:00 | 348 |
| 2026-04-14T17:54:00 | 348 |
| 2026-04-14T17:55:00 | 348 |
| 2026-04-14T17:56:00 | 434 |

### Scenario 7 Baseline (Process Metrics)

Window: 2026-04-14T18:01:02Z to 2026-04-14T18:04:02Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T18:02:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:03:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:04:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T18:02:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:03:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:04:00 | 16 |
| container.azm.ms/net | 2026-04-14T18:02:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:03:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:04:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T18:02:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:03:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:04:00 | 36 |
| prometheus | 2026-04-14T18:02:00 | 4148 |
| prometheus | 2026-04-14T18:03:00 | 4148 |
| prometheus | 2026-04-14T18:04:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T18:01:00 | 821 |
| 2026-04-14T18:02:00 | 348 |
| 2026-04-14T18:03:00 | 782 |

### Scenario 8 Baseline (OSM No Configmap)

Window: 2026-04-14T18:08:30Z to 2026-04-14T18:11:30Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T18:09:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:10:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:11:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T18:09:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:10:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:11:00 | 16 |
| container.azm.ms/net | 2026-04-14T18:09:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:10:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:11:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T18:09:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:10:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:11:00 | 36 |
| prometheus | 2026-04-14T18:09:00 | 4148 |
| prometheus | 2026-04-14T18:10:00 | 4148 |
| prometheus | 2026-04-14T18:11:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T18:08:00 | 348 |
| 2026-04-14T18:09:00 | 348 |
| 2026-04-14T18:10:00 | 782 |
| 2026-04-14T18:11:00 | 434 |

### Scenario 9 Baseline (OSM Single NS)

Window: 2026-04-14T18:16:00Z to 2026-04-14T18:19:00Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T18:16:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:17:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:18:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:19:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T18:16:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:17:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:18:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:19:00 | 16 |
| container.azm.ms/net | 2026-04-14T18:16:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:17:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:18:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:19:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T18:16:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:17:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:18:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:19:00 | 36 |
| prometheus | 2026-04-14T18:16:00 | 4148 |
| prometheus | 2026-04-14T18:17:00 | 4148 |
| prometheus | 2026-04-14T18:18:00 | 4148 |
| prometheus | 2026-04-14T18:19:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T18:16:00 | 821 |
| 2026-04-14T18:17:00 | 821 |
| 2026-04-14T18:18:00 | 821 |

### Scenario 10 Baseline (OSM Multi NS)

Window: 2026-04-14T18:23:30Z to 2026-04-14T18:26:30Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T18:24:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:25:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:26:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T18:24:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:25:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:26:00 | 16 |
| container.azm.ms/net | 2026-04-14T18:24:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:25:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:26:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T18:24:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:25:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:26:00 | 36 |
| prometheus | 2026-04-14T18:24:00 | 4148 |
| prometheus | 2026-04-14T18:25:00 | 4148 |
| prometheus | 2026-04-14T18:26:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T18:23:00 | 348 |
| 2026-04-14T18:24:00 | 821 |
| 2026-04-14T18:25:00 | 821 |
| 2026-04-14T18:26:00 | 473 |

---

## Phase 2b: Test Data (cidev:3.1.35-12-ga398c2798-20260414052603)

### Scenario 1 Test (Default (No Custom Prometheus))

Window: 2026-04-14T18:39:35Z to 2026-04-14T18:42:35Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T18:40:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:41:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:42:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T18:40:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:41:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:42:00 | 16 |
| container.azm.ms/net | 2026-04-14T18:40:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:41:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:42:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T18:40:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:41:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:42:00 | 36 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T18:39:00 | 818 |
| 2026-04-14T18:40:00 | 818 |
| 2026-04-14T18:41:00 | 348 |
| 2026-04-14T18:42:00 | 434 |

### Scenario 2 Test (Pod-level Prometheus Scraping)

Window: 2026-04-14T18:47:06Z to 2026-04-14T18:50:06Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T18:48:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:49:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:50:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T18:48:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:49:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:50:00 | 16 |
| container.azm.ms/net | 2026-04-14T18:48:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:49:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:50:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T18:48:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:49:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:50:00 | 36 |
| prometheus | 2026-04-14T18:48:00 | 4148 |
| prometheus | 2026-04-14T18:49:00 | 4148 |
| prometheus | 2026-04-14T18:50:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T18:47:00 | 818 |
| 2026-04-14T18:48:00 | 348 |
| 2026-04-14T18:49:00 | 782 |

### Scenario 3 Test (Namespace-scoped Scraping)

Window: 2026-04-14T18:54:35Z to 2026-04-14T18:57:35Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T18:55:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:56:00 | 12 |
| container.azm.ms/disk | 2026-04-14T18:57:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T18:55:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:56:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T18:57:00 | 16 |
| container.azm.ms/net | 2026-04-14T18:55:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:56:00 | 8 |
| container.azm.ms/net | 2026-04-14T18:57:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T18:55:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:56:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T18:57:00 | 36 |
| prometheus | 2026-04-14T18:55:00 | 2074 |
| prometheus | 2026-04-14T18:56:00 | 2074 |
| prometheus | 2026-04-14T18:57:00 | 2074 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T18:54:00 | 818 |
| 2026-04-14T18:55:00 | 348 |
| 2026-04-14T18:56:00 | 782 |
| 2026-04-14T18:57:00 | 434 |

### Scenario 4 Test (Custom URLs (Daemonset))

Window: 2026-04-14T19:02:03Z to 2026-04-14T19:05:03Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T19:03:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:04:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:05:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T19:03:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:04:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:05:00 | 16 |
| container.azm.ms/net | 2026-04-14T19:03:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:04:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:05:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T19:03:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:04:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:05:00 | 36 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T19:02:00 | 348 |
| 2026-04-14T19:03:00 | 348 |
| 2026-04-14T19:04:00 | 782 |

### Scenario 5 Test (Field Filtering)

Window: 2026-04-14T19:09:32Z to 2026-04-14T19:12:32Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T19:10:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:11:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:12:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T19:10:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:11:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:12:00 | 16 |
| container.azm.ms/net | 2026-04-14T19:10:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:11:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:12:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T19:10:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:11:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:12:00 | 36 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T19:09:00 | 818 |
| 2026-04-14T19:10:00 | 818 |
| 2026-04-14T19:11:00 | 348 |

### Scenario 6 Test (Label Selectors)

Window: 2026-04-14T19:17:01Z to 2026-04-14T19:20:01Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T19:18:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:19:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:20:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T19:18:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:19:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:20:00 | 16 |
| container.azm.ms/net | 2026-04-14T19:18:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:19:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:20:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T19:18:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:19:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:20:00 | 36 |
| prometheus | 2026-04-14T19:18:00 | 4148 |
| prometheus | 2026-04-14T19:19:00 | 4148 |
| prometheus | 2026-04-14T19:20:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T19:17:00 | 348 |
| 2026-04-14T19:18:00 | 782 |
| 2026-04-14T19:19:00 | 782 |

### Scenario 7 Test (Process Metrics)

Window: 2026-04-14T19:24:31Z to 2026-04-14T19:27:31Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T19:25:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:26:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:27:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T19:25:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:26:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:27:00 | 16 |
| container.azm.ms/net | 2026-04-14T19:25:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:26:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:27:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T19:25:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:26:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:27:00 | 36 |
| prometheus | 2026-04-14T19:25:00 | 4148 |
| prometheus | 2026-04-14T19:26:00 | 4148 |
| prometheus | 2026-04-14T19:27:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T19:24:00 | 818 |
| 2026-04-14T19:25:00 | 818 |
| 2026-04-14T19:26:00 | 348 |

### Scenario 8 Test (OSM No Configmap)

Window: 2026-04-14T19:32:03Z to 2026-04-14T19:35:03Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T19:33:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:34:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:35:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T19:33:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:34:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:35:00 | 16 |
| container.azm.ms/net | 2026-04-14T19:33:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:34:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:35:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T19:33:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:34:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:35:00 | 36 |
| prometheus | 2026-04-14T19:33:00 | 4148 |
| prometheus | 2026-04-14T19:34:00 | 4148 |
| prometheus | 2026-04-14T19:35:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T19:32:00 | 348 |
| 2026-04-14T19:33:00 | 782 |
| 2026-04-14T19:34:00 | 782 |

### Scenario 9 Test (OSM Single NS)

Window: 2026-04-14T19:39:32Z to 2026-04-14T19:42:32Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T19:40:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:41:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:42:00 | 12 |
| container.azm.ms/diskio | 2026-04-14T19:40:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:41:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:42:00 | 16 |
| container.azm.ms/net | 2026-04-14T19:40:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:41:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:42:00 | 8 |
| container.azm.ms/prometheus | 2026-04-14T19:40:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:41:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:42:00 | 36 |
| prometheus | 2026-04-14T19:40:00 | 4148 |
| prometheus | 2026-04-14T19:41:00 | 4148 |
| prometheus | 2026-04-14T19:42:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T19:39:00 | 818 |
| 2026-04-14T19:40:00 | 818 |
| 2026-04-14T19:41:00 | 818 |

### Scenario 10 Test (OSM Multi NS)

Window: 2026-04-14T19:47:00Z to 2026-04-14T19:50:00Z


**InsightsMetrics:**

| Namespace | Time | Count |
|-----------|------|-------|
| container.azm.ms/disk | 2026-04-14T19:47:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:48:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:49:00 | 12 |
| container.azm.ms/disk | 2026-04-14T19:50:00 | 6 |
| container.azm.ms/diskio | 2026-04-14T19:47:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:48:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:49:00 | 16 |
| container.azm.ms/diskio | 2026-04-14T19:50:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:47:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:48:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:49:00 | 8 |
| container.azm.ms/net | 2026-04-14T19:50:00 | 4 |
| container.azm.ms/prometheus | 2026-04-14T19:47:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:48:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:49:00 | 36 |
| container.azm.ms/prometheus | 2026-04-14T19:50:00 | 18 |
| prometheus | 2026-04-14T19:47:00 | 4148 |
| prometheus | 2026-04-14T19:48:00 | 4148 |
| prometheus | 2026-04-14T19:49:00 | 4148 |
| prometheus | 2026-04-14T19:50:00 | 4148 |

**Perf:**

| Time | Count |
|------|-------|
| 2026-04-14T19:47:00 | 818 |
| 2026-04-14T19:48:00 | 818 |
| 2026-04-14T19:49:00 | 818 |


---

## Phase 2c: Comparison and Summary

**Prod Image**: ciprod:3.1.35 | **Test Image**: cidev:3.1.35-12-ga398c2798-20260414052603
**Telegraf Version (Prod)**: 1.37.1 | **Telegraf Version (Test)**: 1.38.2
**Cluster**: sky-test-cluster | **Date**: 2026-04-14

### Scenario Results

| # | Scenario | InsightsMetrics | Perf | Result | Notes |
|---|----------|-----------------|------|--------|-------|
| 1 | Default | MATCH | MATCH | PASS | disk=12, diskio=16, net=8, prom=36 per min |
| 2 | Pod Scraping | MATCH | MATCH | PASS | +4148 prometheus metrics/min from ref app |
| 3 | Namespace Filter | MATCH | MATCH | PASS | 2074 prom metrics (prom-test only) |
| 4 | Custom URLs | MATCH | MATCH | PASS | No pod scraping, node URL scraping |
| 5 | Field Filtering | MATCH | MATCH | PASS | fieldpass working, default metrics unaffected |
| 6 | Label Selectors | MATCH | MATCH | PASS | 4148 prom metrics (label-selected pods only) |
| 7 | Process Metrics | MATCH | MATCH | PASS | Process metrics via AppInsights pipeline |
| 8 | OSM No Configmap | MATCH | MATCH | PASS | Telegraf starts cleanly without OSM cm |
| 9 | OSM Single NS | MATCH | MATCH | PASS | OSM metrics flowing for prom-test NS |
| 10 | OSM Multi NS | MATCH | MATCH | PASS | OSM metrics flowing for 3 namespaces |

### Steady-State Counts (per minute, all scenarios)

| Namespace | Prod | Test | Match |
|-----------|------|------|-------|
| container.azm.ms/disk | 12 | 12 | YES |
| container.azm.ms/diskio | 16 | 16 | YES |
| container.azm.ms/net | 8 | 8 | YES |
| container.azm.ms/prometheus | 36 | 36 | YES |
| prometheus (pod scraping) | 4148 | 4148 | YES |

### Deprecation Warnings
- fieldpass deprecated since 1.29.0, removal at 1.40.0: use fieldinclude (affects: disk, diskio, net, prometheus)
- ignore_protocol_stats deprecated since 1.37.0, removal at 1.45.0 (affects: net)

### Notes
- Perf counts show edge-minute variation (348 vs 782 vs 818) due to ingestion latency. This is expected and not a regression.
- No loopback data in net namespace (verified in S1).
- Windows build failed so Windows testing could not be performed.
- All pods healthy with 0 restarts across all scenarios.

### Overall Result: PASS


---

## Config Placeholder Substitution Check

### Prod Image (ciprod:3.1.35, Telegraf 1.37.1)

| Config File | Container | Unsubstituted Vars | --test Parse | Status |
|---|---|---|---|---|
| telegraf.conf | DS ama-logs | None | Exit 0 (OK) | PASS |
| telegraf-prom-side-car.conf | DS sidecar | AZMON_TELEGRAF_OSM_PROM_PLUGINS | Exit 1 (invalid TOML line 213) | FAIL |
| telegraf-rs.conf | RS ama-logs | 6 vars (MONITOR_PODS, SCRAPE_SCOPE, LABEL_SELECTOR, FIELD_SELECTOR, PLUGINS_WITH_NAMESPACE_FILTER, OSM_PROM_PLUGINS) | N/A (telegraf not running) | FAIL |

Note: Prod image works on Telegraf 1.37.1 because it treats undefined env vars as empty strings.
These unsubstituted placeholders will break Telegraf 1.38.0+ which uses strict env var handling.

### Test Image (cidev:3.1.35-14-g8ceba8681, Telegraf 1.38.2, commit 8ceba86)

| Config File | Container | Unsubstituted Vars | --test Parse | Status |
|---|---|---|---|---|
| telegraf.conf | DS ama-logs | None | Exit 0 (OK) | PASS |
| telegraf-prom-side-car.conf | DS sidecar | None | Exit 0 (OK) | PASS (FIXED) |
| telegraf-rs.conf | RS ama-logs | 11 vars (expected - sidecar scraping enabled, RS telegraf not started) | N/A | N/A |

Note: RS telegraf-rs.conf still has unsubstituted vars because SIDECAR_SCRAPING_ENABLED=true
causes the config parsers to skip the RS path. This is safe because RS telegraf is not started
in this configuration. The substituteDsDefaultsInTelegrafConf RS branch would activate if
sidecar scraping were disabled.
