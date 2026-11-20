#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { DefaultAzureCredential } from "@azure/identity";
import { LogsQueryClient } from "@azure/monitor-query";
import { execSync } from "child_process";
import { writeFileSync } from "fs";
import { z } from "zod";

import { DATA_SOURCES, APP_INSIGHTS } from "./datasources.js";
import { QUERIES, QueryCategory, parameterizeQuery } from "./queries.js";
import { scrapeICMIncident } from "./icm-browser.js";
import { planFixTracker } from "./fix-tracker.js";

// ── Configuration ──────────────────────────────────────────────
const QUERY_TIMEOUT_MS = parseInt(process.env.KQL_TIMEOUT_MS || "180000", 10);
const CONCURRENCY = parseInt(process.env.QUERY_CONCURRENCY || "5", 10);
const MAX_RETRIES = parseInt(process.env.QUERY_MAX_RETRIES || "2", 10);
const MAX_INLINE_ROWS = 100;

// ── Auth & Clients ─────────────────────────────────────────────
const credential = new DefaultAzureCredential();
const logsClient = new LogsQueryClient(credential);

// ── MCP Server ─────────────────────────────────────────────────
const server = new McpServer({
  name: "ama-logs-tsg",
  version: "1.0.0",
});

// ── Shared Parameter Schemas ───────────────────────────────────
const clusterParam = z
  .string()
  .describe("AKS cluster ARM resource ID, e.g. /subscriptions/.../managedClusters/name");
const timeRangeParam = z
  .string()
  .default("24h")
  .describe("Time range to query, e.g. 1h, 6h, 24h, 2d, 7d");
const intervalParam = z
  .string()
  .default("6h")
  .describe("Aggregation interval, e.g. 1h, 6h");
const startTimeParam = z
  .string()
  .optional()
  .describe("Absolute start time in ISO 8601 format, e.g. '2026-03-10T00:00:00Z'");
const endTimeParam = z
  .string()
  .optional()
  .describe("Absolute end time in ISO 8601 format, e.g. '2026-03-11T00:00:00Z'");
const outputFileParam = z
  .string()
  .optional()
  .describe("Optional file path to write ALL results (no truncation) as JSON. Example: /tmp/tsg-triage.json");

// ── Types ──────────────────────────────────────────────────────
interface QueryResult {
  name: string;
  datasource: string;
  status: "success" | "error";
  data?: Record<string, unknown>[];
  rowCount?: number;
  truncated?: boolean;
  error?: string;
}

type ToolExtra = {
  _meta?: { progressToken?: string | number };
  sendNotification: (notification: {
    method: string;
    params: Record<string, unknown>;
  }) => Promise<void>;
};

// ── Retry Logic ────────────────────────────────────────────────
async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = MAX_RETRIES,
): Promise<T> {
  let lastError: Error | undefined;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err));
      const msg = lastError.message.toLowerCase();
      const causeMsg = ((lastError as any).cause?.message || "").toLowerCase();
      const fullMsg = `${msg} ${causeMsg}`;

      const isRetryable =
        fullMsg.includes("fetch failed") ||
        fullMsg.includes("timeout") ||
        fullMsg.includes("econnreset") ||
        fullMsg.includes("econnrefused") ||
        fullMsg.includes("socket hang up") ||
        fullMsg.includes("429") ||
        fullMsg.includes("503") ||
        fullMsg.includes("502") ||
        fullMsg.includes("504") ||
        fullMsg.includes("throttl");

      if (!isRetryable || attempt >= maxRetries) throw lastError;

      const delay = Math.min(1000 * Math.pow(2, attempt), 10000);
      await new Promise((r) => setTimeout(r, delay));
    }
  }
  throw lastError!;
}

// ── Progress Notifications ─────────────────────────────────────
async function sendProgress(
  extra: ToolExtra,
  progress: number,
  total: number,
  message: string,
): Promise<void> {
  const progressToken = extra._meta?.progressToken;
  if (progressToken === undefined) return;
  try {
    await extra.sendNotification({
      method: "notifications/progress",
      params: { progressToken, progress, total, message },
    });
  } catch {
    // Best-effort
  }
}

// ── Query Execution ────────────────────────────────────────────
async function runAppInsightsQuery(
  kql: string,
  timeRange: string,
  startTime?: string,
  endTime?: string,
): Promise<Record<string, unknown>[]> {
  let timespan: { duration: string } | { startTime: Date; endTime: Date };

  if (startTime && endTime) {
    timespan = { startTime: new Date(startTime), endTime: new Date(endTime) };
  } else {
    const durationMap: Record<string, string> = {
      "1h": "PT1H",
      "6h": "PT6H",
      "12h": "PT12H",
      "24h": "PT24H",
      "2d": "P2D",
      "3d": "P3D",
      "7d": "P7D",
      "14d": "P14D",
      "30d": "P30D",
    };
    timespan = { duration: durationMap[timeRange] || "PT24H" };
  }

  const result = await withRetry(() =>
    logsClient.queryResource(APP_INSIGHTS.resourceId, kql, timespan, {
      serverTimeoutInSeconds: Math.floor(QUERY_TIMEOUT_MS / 1000),
    }),
  );

  const rows: Record<string, unknown>[] = [];
  const tables =
    result.status === "Success"
      ? result.tables
      : result.status === "PartialFailure"
        ? result.partialTables
        : [];

  for (const table of tables) {
    for (const row of table.rows) {
      const obj: Record<string, unknown> = {};
      table.columnDescriptors.forEach((col, i) => {
        obj[col.name ?? `col${i}`] = row[i];
      });
      rows.push(obj);
    }
  }
  return rows;
}

async function runKustoQuery(
  clusterUri: string,
  database: string,
  kql: string,
): Promise<Record<string, unknown>[]> {
  let scope: string;
  if (clusterUri.includes("applicationinsights.io")) {
    scope = "https://api.applicationinsights.io/.default";
  } else {
    const url = new URL(clusterUri);
    scope = `${url.protocol}//${url.host}/.default`;
  }

  const token = await credential.getToken(scope);
  const requestBody = JSON.stringify({ db: database, csl: kql });
  const timeoutSecs = Math.ceil(QUERY_TIMEOUT_MS / 1000);

  const output = await withRetry(() => {
    return new Promise<string>((resolve, reject) => {
      try {
        const result = execSync(
          `curl -s -S --max-time ${timeoutSecs} ` +
            `-w "\\n__HTTP_STATUS__:%{http_code}" ` +
            `-X POST "${clusterUri}/v1/rest/query" ` +
            `-H "Authorization: Bearer ${token!.token}" ` +
            `-H "Content-Type: application/json" ` +
            `-d @-`,
          {
            input: requestBody,
            encoding: "utf8",
            maxBuffer: 100 * 1024 * 1024,
            timeout: QUERY_TIMEOUT_MS + 5000,
          },
        );
        resolve(result);
      } catch (err: any) {
        reject(
          new Error(
            `curl failed: ${err.stderr || err.message}`.slice(0, 500),
          ),
        );
      }
    });
  });

  const statusMarker = "\n__HTTP_STATUS__:";
  const markerIdx = output.lastIndexOf(statusMarker);
  let responseBody: string, httpStatus: number;
  if (markerIdx !== -1) {
    responseBody = output.slice(0, markerIdx);
    httpStatus = parseInt(
      output.slice(markerIdx + statusMarker.length).trim(),
      10,
    );
  } else {
    responseBody = output;
    httpStatus = 200;
  }

  if (httpStatus >= 400) {
    throw new Error(
      `Kusto query failed (${httpStatus}): ${responseBody.slice(0, 500)}`,
    );
  }

  const body = JSON.parse(responseBody);
  const rows: Record<string, unknown>[] = [];
  if (body.Tables && body.Tables.length > 0) {
    const table = body.Tables[0];
    const columns = table.Columns.map(
      (c: { ColumnName: string }) => c.ColumnName,
    );
    for (const row of table.Rows) {
      const obj: Record<string, unknown> = {};
      columns.forEach((col: string, i: number) => {
        obj[col] = row[i];
      });
      rows.push(obj);
    }
  }
  return rows;
}

async function executeQuery(
  queryDef: { name: string; datasource: string; kql: string },
  params: {
    cluster: string;
    timeRange: string;
    interval: string;
    startTime?: string;
    endTime?: string;
  },
): Promise<QueryResult> {
  try {
    const kql = parameterizeQuery(queryDef.kql, params);
    const ds = DATA_SOURCES[queryDef.datasource];
    if (!ds) {
      return {
        name: queryDef.name,
        datasource: queryDef.datasource,
        status: "error",
        error: `Unknown data source: ${queryDef.datasource}`,
      };
    }

    let data: Record<string, unknown>[];
    if (queryDef.datasource === "ContainerInsightsAppInsights") {
      data = await runAppInsightsQuery(
        kql,
        params.timeRange,
        params.startTime,
        params.endTime,
      );
    } else {
      data = await runKustoQuery(ds.clusterUri, ds.database, kql);
    }

    return {
      name: queryDef.name,
      datasource: queryDef.datasource,
      status: "success",
      data: data.slice(0, MAX_INLINE_ROWS),
      rowCount: data.length,
      truncated: data.length > MAX_INLINE_ROWS,
    };
  } catch (err) {
    return {
      name: queryDef.name,
      datasource: queryDef.datasource,
      status: "error",
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

// ── Category Runner ────────────────────────────────────────────
async function runCategory(
  category: QueryCategory,
  params: {
    cluster: string;
    timeRange: string;
    interval: string;
    startTime?: string;
    endTime?: string;
  },
  extra?: ToolExtra,
): Promise<QueryResult[]> {
  const queries = QUERIES[category];
  if (!queries || queries.length === 0) return [];

  const results: QueryResult[] = [];
  const totalQueries = queries.length;

  for (let i = 0; i < queries.length; i += CONCURRENCY) {
    const batch = queries.slice(i, i + CONCURRENCY);
    const batchResults = await Promise.all(
      batch.map((q) => executeQuery(q, params)),
    );
    results.push(...batchResults);

    if (extra) {
      const completed = Math.min(i + CONCURRENCY, totalQueries);
      await sendProgress(
        extra,
        completed,
        totalQueries,
        `${category}: ${completed}/${totalQueries} queries complete`,
      );
    }
  }

  return results;
}

// ── Result Formatting ──────────────────────────────────────────
function formatResults(results: QueryResult[]): string {
  const parts: string[] = [];

  for (const r of results) {
    parts.push(`### ${r.name}`);
    parts.push(`Data Source: ${r.datasource}`);

    if (r.status === "error") {
      parts.push(`❌ Error: ${r.error}`);
    } else if (r.data && r.data.length > 0) {
      parts.push(`✅ ${r.rowCount} row(s) returned`);
      if (r.truncated) {
        parts.push(
          `⚠️ Results truncated to ${MAX_INLINE_ROWS} rows (${r.rowCount} total). Use outputFile for full results.`,
        );
      }
      const columns = Object.keys(r.data[0]);
      parts.push(`| ${columns.join(" | ")} |`);
      parts.push(`| ${columns.map(() => "---").join(" | ")} |`);
      for (const row of r.data.slice(0, 20)) {
        const values = columns.map((c) => {
          const v = row[c];
          if (v === null || v === undefined) return "";
          const s = String(v);
          return s.length > 100 ? s.slice(0, 97) + "..." : s;
        });
        parts.push(`| ${values.join(" | ")} |`);
      }
      if (r.data.length > 20) {
        parts.push(`... and ${r.data.length - 20} more rows`);
      }
    } else {
      parts.push("ℹ️ No data returned");
    }
    parts.push("");
  }

  return parts.join("\n");
}

function categoryResponse(
  results: QueryResult[],
  outputFile?: string,
): { content: Array<{ type: "text"; text: string }> } {
  let text = formatResults(results);

  if (outputFile) {
    const allData: Record<string, Record<string, unknown>[]> = {};
    let totalRows = 0;
    for (const r of results) {
      if (r.status === "success" && r.data && r.data.length > 0) {
        allData[r.name] = r.data;
        totalRows += r.data.length;
      }
    }
    writeFileSync(outputFile, JSON.stringify(allData, null, 2), "utf-8");
    text += `\n📁 Full results (${totalRows} total rows across ${Object.keys(allData).length} queries) written to \`${outputFile}\``;
  }

  return { content: [{ type: "text", text }] };
}

// ── Tool Registrations ─────────────────────────────────────────

server.tool(
  "ama_logs_tsg_triage",
  "Run initial triage queries for ama-logs (Container Insights): agent version, cluster scale, pod/node counts, high log scale mode, AKS alerts, private cluster check, managed cluster profile, addon identity, fleet version distribution, RS heartbeat check.",
  {
    cluster: clusterParam,
    timeRange: timeRangeParam,
    interval: intervalParam,
    startTime: startTimeParam,
    endTime: endTimeParam,
    outputFile: outputFileParam,
  },
  async ({ cluster, timeRange, interval, startTime, endTime, outputFile }, extra) => {
    const results = await runCategory(
      "triage",
      { cluster, timeRange, interval, startTime, endTime },
      extra as ToolExtra,
    );
    return categoryResponse(results, outputFile);
  },
);

server.tool(
  "ama_logs_tsg_errors",
  "Scan all ama-logs error categories: exceptions, MDSD send/create errors, network upload failures, OMS Homing errors, AKS alerts for daemonset and replicaset, node NetworkNotReady events.",
  {
    cluster: clusterParam,
    timeRange: timeRangeParam,
    interval: intervalParam,
    startTime: startTimeParam,
    endTime: endTimeParam,
    outputFile: outputFileParam,
  },
  async ({ cluster, timeRange, interval, startTime, endTime, outputFile }, extra) => {
    const results = await runCategory(
      "errors",
      { cluster, timeRange, interval, startTime, endTime },
      extra as ToolExtra,
    );
    return categoryResponse(results, outputFile);
  },
);

server.tool(
  "ama_logs_tsg_workload",
  "Check ama-logs agent workload health: memory RSS, CPU usage, container logs generated/sec, log size/sec, telegraf metrics, for daemonset, replicaset, and Windows pods.",
  {
    cluster: clusterParam,
    timeRange: timeRangeParam,
    interval: intervalParam,
    startTime: startTimeParam,
    endTime: endTimeParam,
    outputFile: outputFileParam,
  },
  async ({ cluster, timeRange, interval, startTime, endTime, outputFile }, extra) => {
    const results = await runCategory(
      "workload",
      { cluster, timeRange, interval, startTime, endTime },
      extra as ToolExtra,
    );
    return categoryResponse(results, outputFile);
  },
);

server.tool(
  "ama_logs_tsg_pods",
  "Check ama-logs pod health: restarts, alert status for daemonset and replicaset pods, KubeSystemEvents (pod events summary, lifecycle timeline, crash summary, FailedMount, liveness probe failures, container start/exit).",
  {
    cluster: clusterParam,
    timeRange: timeRangeParam,
    interval: intervalParam,
    startTime: startTimeParam,
    endTime: endTimeParam,
    outputFile: outputFileParam,
  },
  async ({ cluster, timeRange, interval, startTime, endTime, outputFile }, extra) => {
    const results = await runCategory(
      "pods",
      { cluster, timeRange, interval, startTime, endTime },
      extra as ToolExtra,
    );
    return categoryResponse(results, outputFile);
  },
);

server.tool(
  "ama_logs_tsg_logs",
  "Get raw ama-logs trace logs from a specific component: daemonset, replicaset, or windows.",
  {
    cluster: clusterParam,
    component: z
      .enum(["daemonset", "replicaset", "windows"])
      .default("daemonset")
      .describe("Component to get logs for"),
    timeRange: timeRangeParam,
    interval: intervalParam,
    startTime: startTimeParam,
    endTime: endTimeParam,
    outputFile: outputFileParam,
  },
  async ({ cluster, component, timeRange, interval, startTime, endTime, outputFile }) => {
    const componentMap: Record<string, string> = {
      daemonset: "Recent Traces (Daemonset)",
      replicaset: "Recent Traces (Replicaset)",
      windows: "Recent Traces (Windows)",
    };

    const queryName = componentMap[component];
    const queries = QUERIES.logs.filter((q) => q.name === queryName);

    const results: QueryResult[] = [];
    for (const q of queries) {
      results.push(
        await executeQuery(q, { cluster, timeRange, interval, startTime, endTime }),
      );
    }
    return categoryResponse(results, outputFile);
  },
);

server.tool(
  "ama_logs_tsg_config",
  "Check ama-logs agent configuration: configmap settings, excluded namespaces, container log table format, high log scale mode, addon reconciler events.",
  {
    cluster: clusterParam,
    timeRange: timeRangeParam,
    interval: intervalParam,
    startTime: startTimeParam,
    endTime: endTimeParam,
    outputFile: outputFileParam,
  },
  async ({ cluster, timeRange, interval, startTime, endTime, outputFile }, extra) => {
    const results = await runCategory(
      "config",
      { cluster, timeRange, interval, startTime, endTime },
      extra as ToolExtra,
    );
    return categoryResponse(results, outputFile);
  },
);

server.tool(
  "ama_logs_tsg_query",
  "Run an arbitrary KQL query against any ama-logs data source: ContainerInsightsAppInsights, AKS, AKS CCP, Azcore, AKS GuestAgent.",
  {
    datasource: z
      .enum(["ContainerInsightsAppInsights", "AKS", "AKS CCP", "Azcore", "AzcrpBI", "Azcrp", "AKS SwedenCentral", "AKS GuestAgent"])
      .describe("Data source to query against"),
    kql: z.string().describe("KQL query to execute"),
    cluster: z
      .string()
      .optional()
      .describe("Optional cluster ARM resource ID. When provided, _cluster in the KQL will be replaced."),
    timeRange: timeRangeParam,
    maxRows: z
      .number()
      .optional()
      .describe("Maximum rows to return inline (default: 100). Use outputFile for unlimited."),
    outputFile: z
      .string()
      .optional()
      .describe("Optional file path to write ALL results (no truncation). Supports .csv and .json."),
    outputFormat: z
      .enum(["csv", "json"])
      .default("csv")
      .describe("Output format when outputFile is specified. Default: csv"),
  },
  async ({ datasource, kql, cluster, timeRange, maxRows, outputFile, outputFormat }) => {
    try {
      let parameterizedKql = kql;
      if (cluster) {
        parameterizedKql = parameterizeQuery(kql, { cluster, timeRange });
      }

      const ds = DATA_SOURCES[datasource];
      if (!ds) {
        return {
          content: [{ type: "text" as const, text: `❌ Unknown data source: ${datasource}` }],
        };
      }

      let data: Record<string, unknown>[];
      if (datasource === "ContainerInsightsAppInsights") {
        data = await runAppInsightsQuery(parameterizedKql, timeRange);
      } else {
        data = await runKustoQuery(ds.clusterUri, ds.database, parameterizedKql);
      }

      const limit = maxRows || MAX_INLINE_ROWS;
      let text = `### Ad-hoc Query\nData Source: ${datasource}\n`;

      if (data.length === 0) {
        text += "ℹ️ No data returned";
      } else {
        text += `✅ ${data.length} row(s) returned\n`;
        if (data.length > limit) {
          text += `⚠️ Showing first ${limit} of ${data.length} rows.\n`;
        }

        const columns = Object.keys(data[0]);
        text += `| ${columns.join(" | ")} |\n`;
        text += `| ${columns.map(() => "---").join(" | ")} |\n`;
        for (const row of data.slice(0, limit)) {
          const values = columns.map((c) => {
            const v = row[c];
            if (v === null || v === undefined) return "";
            const s = String(v);
            return s.length > 100 ? s.slice(0, 97) + "..." : s;
          });
          text += `| ${values.join(" | ")} |\n`;
        }
      }

      if (outputFile) {
        if (outputFormat === "json") {
          writeFileSync(outputFile, JSON.stringify(data, null, 2), "utf-8");
        } else {
          if (data.length > 0) {
            const columns = Object.keys(data[0]);
            const header = columns.map((c) => `"${c}"`).join(",");
            const rows = data.map((row) =>
              columns
                .map((c) => {
                  const v = row[c];
                  if (v === null || v === undefined) return "";
                  const s = String(v).replace(/"/g, '""');
                  return `"${s}"`;
                })
                .join(","),
            );
            writeFileSync(outputFile, [header, ...rows].join("\n"), "utf-8");
          } else {
            writeFileSync(outputFile, "", "utf-8");
          }
        }
        text += `\n📁 Full results (${data.length} rows) written to \`${outputFile}\``;
      }

      return { content: [{ type: "text" as const, text }] };
    } catch (err) {
      return {
        content: [
          {
            type: "text" as const,
            text: `❌ Query failed: ${err instanceof Error ? err.message : String(err)}`,
          },
        ],
      };
    }
  },
);

server.tool(
  "ama_logs_tsg_auth_check",
  "Validate ama-logs TSG credentials and connectivity to all data sources (ContainerInsightsAgent-Prod App Insights, AKS Kusto). Run this first if queries fail with 403 or connection errors.",
  {
    autoFix: z.boolean().default(true).describe("Attempt to automatically fix auth issues (default: true)"),
  },
  async ({ autoFix }) => {
    const results: string[] = ["## Auth Check\n"];

    // Test Azure credential
    try {
      const token = await credential.getToken("https://api.applicationinsights.io/.default");
      results.push(`✅ Azure credential: OK (expires ${token!.expiresOnTimestamp})`);
    } catch (err) {
      results.push(`❌ Azure credential: FAILED - ${err instanceof Error ? err.message : String(err)}`);
      if (autoFix) {
        results.push("🔧 Attempting: az login...");
        try {
          execSync("az account get-access-token --query accessToken -o tsv", {
            encoding: "utf8",
            timeout: 30000,
          });
          results.push("✅ az CLI token refreshed");
        } catch {
          results.push("❌ az CLI token refresh failed. Run `az login` manually.");
        }
      }
    }

    // Test App Insights
    try {
      const testKql = "customMetrics | take 1";
      await runAppInsightsQuery(testKql, "1h");
      results.push(`✅ App Insights (${APP_INSIGHTS.appId}): OK`);
    } catch (err) {
      results.push(
        `❌ App Insights (${APP_INSIGHTS.appId}): FAILED - ${err instanceof Error ? err.message : String(err)}`,
      );
    }

    // Test Kusto (AKS)
    for (const [name, ds] of Object.entries(DATA_SOURCES)) {
      if (name === "ContainerInsightsAppInsights") continue;
      try {
        await runKustoQuery(ds.clusterUri, ds.database, ".show tables | take 1");
        results.push(`✅ Kusto (${name}): OK`);
      } catch (err) {
        results.push(
          `❌ Kusto (${name}): FAILED - ${err instanceof Error ? err.message : String(err)}`,
        );
      }
    }

    return { content: [{ type: "text" as const, text: results.join("\n") }] };
  },
);

// Tool: ama_logs_tsg_icm_page
server.tool(
  "ama_logs_tsg_icm_page",
  "Scrape an ICM incident page via Edge browser CDP connection. Works on both Windows (native) and WSL2. Opens the incident in Edge (or finds an already-open tab) and extracts the authored summary, discussion entries, and ARM resource IDs. On Windows, connects to localhost:9222. On WSL2, connects via port proxy on 9223. Requires Edge running with --remote-debugging-port=9222. Use this to get ICM details not available via the ICM API (authored summary text, discussion content, ARM resource IDs mentioned in descriptions).",
  {
    incidentId: z
      .number()
      .int()
      .positive()
      .describe("The ICM incident ID to scrape, e.g. 123456789"),
  },
  async ({ incidentId }) => {
    const text = await scrapeICMIncident(incidentId);
    return {
      content: [{ type: "text" as const, text }],
    };
  }
);

// Tool: ama_logs_tsg_fix_tracker_plan
server.tool(
  "ama_logs_tsg_fix_tracker_plan",
  "Read-only. Scans microsoft/Docker-Provider for PRs opened or merged in the lookback window, matches them to the given active IcMs (explicit IcM ID/link or unique MSRC case = linked; bare number, shared CVE or ambiguous MSRC = proposed), follows linked PRs through merge, pushed image (Ev2 1032 shell/PushAgentToACR, exit code 0) and AKS (1198) / Arc (1200) Ev2 Prod release rollouts (released = every Prod stage Succeeded), and returns short customer-readable IcM discussion entries to post (what is fixed, CVE coverage, rollout link, ETA) plus needsFixPr (listed CVEs with no fix PR). Ev2 data comes from the caller via `rollouts` (gather it with ev2-mcp from the Prod endpoint); missing rollouts are reported as unknown. Each entry ends with an [ft:<owner/repo>#<n>:<state>] marker; pass each incident's existing discussion entries so already-posted states are skipped. Release-bump PRs are never auto-matched. Does not write to IcM.",
  {
    incidents: z.array(z.object({
      id: z.union([z.string(), z.number()]),
      title: z.string().optional(),
      status: z.string().optional(),
      tags: z.array(z.string()).optional().describe("IcM tags; 'Fix PR: <url>' tags count as human-confirmed links"),
      entries: z.array(z.string()).optional().describe("Existing discussion entry texts (needed for idempotency)"),
      channel: z.enum(["aks", "arc"]).optional().describe("Affected release channel; omit to require both"),
            findings: z.array(z.object({
              id: z.string().describe("CVE or finding ID listed in the incident"),
              fixedBy: z.array(z.string()).optional().describe("Fix PR URLs you verified update the affected package to at least its fixed version"),
              fixed: z.boolean().optional().describe("True only if a version already released to Prod contains the fix"),
            })).optional().describe("Vulnerability incidents only: every listed CVE. Entries then state coverage, PRs covering none are not linked, and 'released' only invites resolving when every CVE has a released fix"),
    })).describe("Active IcMs owned by the team"),
    lookbackHours: z.number().default(24).describe("Scan PRs created or merged in this many hours (overlap with the previous run is safe)"),
    rollouts: z.array(z.object({
      definitionId: z.coerce.number().describe("1032 = ama-logs image push, 1198 = AKS release, 1200 = Arc release"),
      endpoint: z.string().optional().describe("Ev2 endpoint the rollout was read from; only Prod counts (default Prod)"),
      rolloutId: z.string(),
      status: z.string().optional().describe("Overall rollout Status"),
      startTime: z.string().optional(),
      endTime: z.string().optional().describe("Completed rollouts: used to estimate the ETA of the current one"),
      sourceVersion: z.string().optional().describe("RolloutDetails.ReleasePipelineInfo.AzureDevOps.SourceVersion (used for 1032 only)"),
      artifactsVersion: z.string().optional().describe("RolloutDetails.ArtifactsRegistrationInfo.ArtifactsVersion; for 1198/1200 the deployed image tag, e.g. 3.9.1-ci-prod-10-25-2026-46052686 (its SHA suffix is the shipped commit)"),
      url: z.string().optional(),
      stages: z.array(z.object({ name: z.string(), status: z.string() })).optional().describe("get_rollout_summary StageInfos[].StageName/StageStatus"),
      push: z.object({ status: z.string().optional(), exitCode: z.union([z.number(), z.string()]).optional() }).optional()
        .describe("1032 only: shell/PushAgentToACR action status and exit code. Never pass log text."),
    })).default([]).describe("Ev2 rollouts from ev2-mcp for the last 30 days"),
  },
  async ({ incidents, lookbackHours, rollouts }) => ({
    content: [{ type: "text" as const, text: JSON.stringify(await planFixTracker(incidents, lookbackHours, rollouts), null, 2) }],
  })
);

// ── Server Startup ─────────────────────────────────────────────
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("ama-logs-tsg-mcp server started");
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
