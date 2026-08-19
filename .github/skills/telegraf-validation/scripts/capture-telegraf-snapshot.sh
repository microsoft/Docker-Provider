#!/usr/bin/env bash
# Captures a telegraf / custom-Prometheus snapshot from a Log Analytics workspace.
#
# Run this IDENTICALLY before and after the image swap so the two snapshots are
# directly comparable. Same lookback, same scenario workloads, same config map.
#
# usage:
#   ./capture-telegraf-snapshot.sh <label> <workspace-guid> <cluster-resource-id> [lookback] [outdir]
#
# example:
#   ./capture-telegraf-snapshot.sh before-3.6.0 a14e51b3-... /subscriptions/.../managedClusters/my-cluster 20m ./out
#
# Every query filters on _ResourceId. A Log Analytics workspace is frequently
# shared by several clusters -- without that filter the numbers are wrong in a
# way that looks plausible.
set -uo pipefail

LABEL="${1:?usage: capture-telegraf-snapshot.sh <label> <workspace-guid> <cluster-resource-id> [lookback] [outdir]}"
WS="${2:?missing workspace guid}"
RID_RAW="${3:?missing cluster resource id}"
LOOKBACK="${4:-20m}"
OUTDIR="${5:-.}"

# Resource IDs are compared case-insensitively; normalize both sides.
RID="$(printf '%s' "$RID_RAW" | tr '[:upper:]' '[:lower:]')"
OUT="${OUTDIR%/}/telegraf-capture-${LABEL}.txt"
mkdir -p "${OUTDIR%/}"

q() { timeout 300 az monitor log-analytics query -w "$WS" --analytics-query "$1" -o table 2>&1; }

{
echo "########################################################################"
echo "# TELEGRAF CAPTURE: ${LABEL}"
echo "# taken: $(date -u +%FT%TZ)   lookback: ${LOOKBACK}"
echo "# workspace: ${WS}"
echo "# cluster:   ${RID_RAW}"
echo "########################################################################"

echo
echo "=== [1] table-level record counts ==="
q "
let RID='${RID}';
union withsource=Tbl InsightsMetrics, Perf, ContainerInventory, KubeNodeInventory, KubeServices, ContainerNodeInventory, KubePodInventory, ContainerLogV2, KubeEvents
| where TimeGenerated > ago(${LOOKBACK})
| where tolower(tostring(_ResourceId)) == RID
| summarize Records=count(), Last=max(TimeGenerated) by Tbl
| sort by Tbl asc"

echo
echo "=== [2] InsightsMetrics by Namespace/Origin (the telegraf surface) ==="
q "
let RID='${RID}';
InsightsMetrics
| where TimeGenerated > ago(${LOOKBACK})
| where tolower(tostring(_ResourceId)) == RID
| summarize Records=count(), Metrics=dcount(Name) by Origin, Namespace
| sort by Namespace asc"

echo
echo "=== [3] custom-prom metric names (fieldpass/fielddrop assertions) ==="
q "
let RID='${RID}';
InsightsMetrics
| where TimeGenerated > ago(${LOOKBACK})
| where tolower(tostring(_ResourceId)) == RID
| where Namespace == 'prometheus'
| summarize Records=count() by Name
| sort by Name asc"

echo
echo "=== [4] scrape sources (proves each config path is live) ==="
q "
let RID='${RID}';
InsightsMetrics
| where TimeGenerated > ago(${LOOKBACK})
| where tolower(tostring(_ResourceId)) == RID
| where Namespace == 'prometheus'
| extend T=parse_json(Tags)
| extend url=tostring(T['scrapeUrl']), addr=tostring(T['address'])
| summarize Records=count(), Metrics=dcount(Name) by url, addr, Computer
| sort by url asc, Computer asc"

echo
echo "=== [5] per-node coverage (node-level \$NODE_IP scraping) ==="
q "
let RID='${RID}';
InsightsMetrics
| where TimeGenerated > ago(${LOOKBACK})
| where tolower(tostring(_ResourceId)) == RID
| summarize Records=count(), Namespaces=make_set(Namespace, 20) by Computer
| sort by Computer asc"

echo
echo "=== [6] agent health / config errors ==="
q "
let RID='${RID}';
KubeMonAgentEvents
| where TimeGenerated > ago(${LOOKBACK})
| where tolower(tostring(_ResourceId)) == RID
| summarize Count=count(), Sample=any(Message) by Category, Level
| sort by Level asc"

echo
echo "=== [7] Perf counters (regression guard for non-prom telegraf) ==="
q "
let RID='${RID}';
Perf
| where TimeGenerated > ago(${LOOKBACK})
| where tolower(tostring(_ResourceId)) == RID
| summarize Records=count() by ObjectName, CounterName
| sort by ObjectName asc, CounterName asc"
} > "$OUT" 2>&1

echo "captured -> $OUT ($(grep -cE '^' "$OUT") lines)"
