/**
 * ICM Browser Scraper — connects to a running Edge instance via CDP
 * to scrape ICM portal pages for incident details not available via API.
 *
 * Works on both **Windows (native)** and **WSL2**:
 *
 * **Windows:** Edge connects directly on localhost:9222.
 *   Launch Edge:
 *     Start-Process 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' `
 *       -ArgumentList '--remote-debugging-port=9222','--user-data-dir=C:\Users\<user>\.edge-cdp-debug','--no-first-run'
 *
 * **WSL2:** Edge runs on the Windows host; WSL reaches it via netsh port proxy on 9223.
 *   1. Launch Edge on Windows with --remote-debugging-port=9222
 *   2. Set up port proxy: netsh interface portproxy add v4tov4 listenport=9223 listenaddress=0.0.0.0 connectport=9222 connectaddress=127.0.0.1
 *   3. User authenticated to ICM in that Edge instance
 */

import WebSocket from "ws";
import { execSync } from "child_process";

/** Detect if running inside WSL2 */
function isWSL(): boolean {
  return (
    process.platform === "linux" &&
    (process.env.WSL_DISTRO_NAME !== undefined ||
      process.env.WSL_INTEROP !== undefined)
  );
}

/**
 * Auto-detect the Windows host IP from WSL2.
 * Tries in order: /etc/resolv.conf nameserver, default route, fallback.
 */
function detectWindowsHostIP(): string {
  if (process.env.CDP_HOST) return process.env.CDP_HOST;

  try {
    const resolv = execSync("grep nameserver /etc/resolv.conf 2>/dev/null | head -1 | awk '{print $2}'", { encoding: "utf-8" }).trim();
    if (resolv && resolv !== "127.0.0.53") return resolv;
  } catch {}

  try {
    const gw = execSync("ip route show default 2>/dev/null | awk '{print $3}' | head -1", { encoding: "utf-8" }).trim();
    if (gw) return gw;
  } catch {}

  return "172.29.112.1";
}

function getCDPEndpoint(): string {
  if (process.env.CDP_ENDPOINT) return process.env.CDP_ENDPOINT;

  if (process.platform === "win32") {
    const host = process.env.CDP_HOST || "localhost";
    const port = process.env.CDP_PORT || "9222";
    return `http://${host}:${port}`;
  }

  if (isWSL()) {
    const host = detectWindowsHostIP();
    const port = process.env.CDP_PORT || "9223";
    return `http://${host}:${port}`;
  }

  // Linux native fallback
  const host = process.env.CDP_HOST || "localhost";
  const port = process.env.CDP_PORT || "9222";
  return `http://${host}:${port}`;
}

const CDP_HTTP = getCDPEndpoint();

interface CDPTab {
  id: string;
  type: string;
  title: string;
  url: string;
  webSocketDebuggerUrl: string;
}

async function fetchJSON(url: string): Promise<any> {
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`HTTP ${resp.status} from ${url}`);
  return resp.json();
}

/** Open a persistent WebSocket to a tab and send multiple commands */
class CDPSession {
  private ws: WebSocket;
  private msgId = 1;
  private pending = new Map<number, (msg: any) => void>();
  private eventHandlers = new Map<string, (params: any) => void>();

  private constructor(ws: WebSocket) {
    this.ws = ws;
    ws.on("message", (data: WebSocket.RawData) => {
      const msg = JSON.parse(data.toString());
      if (msg.id && this.pending.has(msg.id)) {
        this.pending.get(msg.id)!(msg);
        this.pending.delete(msg.id);
      }
      if (msg.method && this.eventHandlers.has(msg.method)) {
        this.eventHandlers.get(msg.method)!(msg.params);
      }
    });
  }

  static async connect(wsUrl: string): Promise<CDPSession> {
    const ws = new WebSocket(wsUrl);
    await new Promise<void>((resolve, reject) => {
      ws.on("open", resolve);
      ws.on("error", reject);
    });
    return new CDPSession(ws);
  }

  on(event: string, handler: (params: any) => void): void {
    this.eventHandlers.set(event, handler);
  }

  send(method: string, params: Record<string, any> = {}, timeoutMs = 15000): Promise<any> {
    return new Promise((resolve, reject) => {
      const id = this.msgId++;
      const timer = setTimeout(() => {
        this.pending.delete(id);
        resolve(null); // don't reject — some responses just time out
      }, timeoutMs);
      this.pending.set(id, (msg) => {
        clearTimeout(timer);
        if (msg.error) reject(new Error(msg.error.message));
        else resolve(msg.result);
      });
      this.ws.send(JSON.stringify({ id, method, params }));
    });
  }

  async eval(expression: string): Promise<string> {
    const result = await this.send("Runtime.evaluate", {
      expression,
      returnByValue: true,
    });
    return result?.result?.value ?? "";
  }

  close(): void {
    this.ws.close();
  }
}

/** List open tabs in the Edge instance */
async function listTabs(): Promise<CDPTab[]> {
  return fetchJSON(`${CDP_HTTP}/json/list`);
}

/** Close an existing ICM tab if open, then open a fresh one with Network
 *  monitoring enabled BEFORE navigation so we capture the initial API calls. */
async function openFreshICMTab(
  incidentId: number
): Promise<{ session: CDPSession }> {
  const icmUrl = `https://portal.microsofticm.com/imp/v5/incidents/details/${incidentId}/summary`;

  // Close any existing ICM tabs for this incident to avoid stale SPA state
  const tabs = await listTabs();
  const version = await fetchJSON(`${CDP_HTTP}/json/version`);
  const browserWs = version.webSocketDebuggerUrl as string;

  for (const tab of tabs) {
    if (tab.type === "page" && tab.url.includes(`${incidentId}`)) {
      const bSession = await CDPSession.connect(browserWs);
      await bSession.send("Target.closeTarget", { targetId: tab.id });
      bSession.close();
      await new Promise((r) => setTimeout(r, 1000));
    }
  }

  // Open a blank tab first so we can enable Network monitoring before navigation
  const bSession = await CDPSession.connect(browserWs);
  const result = await bSession.send("Target.createTarget", {
    url: "about:blank",
  });
  bSession.close();
  const targetId = result.targetId;

  await new Promise((r) => setTimeout(r, 1000));

  // Find the new blank tab
  const updatedTabs = await listTabs();
  const newTab = updatedTabs.find(
    (t) => t.id === targetId || t.url === "about:blank"
  );
  if (!newTab) {
    throw new Error("Could not find newly opened blank tab");
  }

  // Connect to the tab and enable Network BEFORE navigating to ICM
  const session = await CDPSession.connect(newTab.webSocketDebuggerUrl);
  await session.send("Network.enable", {
    maxTotalBufferSize: 50_000_000,
    maxResourceBufferSize: 10_000_000,
  });

  // Now navigate — Network will capture all API calls from the initial load
  await session.send("Page.navigate", { url: icmUrl });

  return { session };
}

interface DiscussionEntry {
  by: string;
  date: string;
  text: string;
}

interface ICMPageData {
  summary: string;
  description: string;
  discussions: DiscussionEntry[];
}

/**
 * Capture API responses via CDP Network domain (Network.enable must already be active).
 * Waits for GetIncidentDetails and getdescriptionentries responses from the page load.
 */
async function captureIncidentData(
  session: CDPSession,
  incidentId: number
): Promise<ICMPageData | null> {
  const capturedRequests: { requestId: string; url: string }[] = [];

  session.on("Network.responseReceived", (params: any) => {
    const url = params?.response?.url || "";
    if (url.includes("GetIncidentDetails") || url.includes("getdescriptionentries")) {
      capturedRequests.push({ requestId: params.requestId, url });
    }
  });

  // Wait for the page to load and API responses to arrive
  await new Promise((r) => setTimeout(r, 15000));

  let summary = "";
  let description = "";
  const discussions: DiscussionEntry[] = [];

  for (const req of capturedRequests) {
    try {
      const bodyResult = await session.send("Network.getResponseBody", {
        requestId: req.requestId,
      });
      if (!bodyResult?.body) continue;

      const data = JSON.parse(bodyResult.body);

      if (req.url.includes("GetIncidentDetails")) {
        summary = summary || data.Summary || "";
        description = description || data.Description || "";
      }

      if (req.url.includes("getdescriptionentries") && discussions.length === 0) {
        const items = data.Items || [];
        for (const item of items) {
          const text = item.Text || "";
          if (!text) continue;
          discussions.push({
            by: item.SubmittedByDisplayName || item.SubmittedBy || "",
            date: item.SubmitDate || item.Date || "",
            text: stripHtml(text),
          });
        }
      }
    } catch {
      // body may have been evicted from cache
    }
  }

  if (!summary && !description && discussions.length === 0) return null;
  return { summary, description, discussions };
}

/** Strip HTML tags and decode common entities */
function stripHtml(html: string): string {
  return html
    .replace(/<[^>]*>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#\d+;/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Detect the Windows username for Edge user-data-dir.
 */
function getWindowsUser(): string {
  if (process.env.WINDOWS_USER) return process.env.WINDOWS_USER;

  if (process.platform === "win32") {
    return process.env.USERNAME || "your-username";
  }

  // WSL: ask Windows for the username
  try {
    const out = execSync(
      "powershell.exe -NoProfile -Command \"$env:USERNAME\" 2>/dev/null",
      { encoding: "utf-8", timeout: 5000 }
    ).trim().replace(/\r/g, "");
    if (out) return out;
  } catch {}
  return process.env.USER || "your-username";
}

/**
 * Check if the netsh port proxy from proxyPort→cdpPort already exists.
 */
function hasPortProxy(proxyPort: number, cdpPort: number): boolean {
  try {
    const cmd = process.platform === "win32"
      ? 'netsh interface portproxy show v4tov4'
      : 'powershell.exe -NoProfile -Command "netsh interface portproxy show v4tov4" 2>/dev/null';
    const out = execSync(cmd, { encoding: "utf-8", timeout: 5000 });
    return out.includes(String(proxyPort)) && out.includes(String(cdpPort));
  } catch {
    return false;
  }
}

/**
 * Set up the netsh port proxy (WSL only — not needed for native Windows).
 */
function ensurePortProxy(proxyPort: number, cdpPort: number): void {
  if (hasPortProxy(proxyPort, cdpPort)) return;
  try {
    const cmd = process.platform === "win32"
      ? `netsh interface portproxy add v4tov4 listenport=${proxyPort} listenaddress=0.0.0.0 connectport=${cdpPort} connectaddress=127.0.0.1`
      : `powershell.exe -NoProfile -Command "netsh interface portproxy add v4tov4 listenport=${proxyPort} listenaddress=0.0.0.0 connectport=${cdpPort} connectaddress=127.0.0.1" 2>/dev/null`;
    execSync(cmd, { encoding: "utf-8", timeout: 10000 });
  } catch {
    // May fail without admin — will surface in the final error message
  }
}

/**
 * Launch Edge with --remote-debugging-port.
 */
function launchEdge(cdpPort: number, winUser: string): void {
  try {
    if (process.platform === "win32") {
      execSync(
        `Start-Process 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe' -ArgumentList '--remote-debugging-port=${cdpPort}','--user-data-dir=C:\\Users\\${winUser}\\.edge-cdp','--no-first-run'`,
        { encoding: "utf-8", timeout: 10000, shell: "powershell.exe" }
      );
    } else {
      execSync(
        `powershell.exe -NoProfile -Command "Start-Process 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe' -ArgumentList '--remote-debugging-port=${cdpPort}','--user-data-dir=C:\\Users\\${winUser}\\.edge-cdp','--no-first-run'" 2>/dev/null`,
        { encoding: "utf-8", timeout: 10000 }
      );
    }
  } catch {
    // Edge may already be running or path differs — will detect via CDP check
  }
}

/**
 * Wait for CDP endpoint to become available, with retries.
 */
async function waitForCDP(endpoint: string, maxWaitSec: number): Promise<boolean> {
  const start = Date.now();
  while (Date.now() - start < maxWaitSec * 1000) {
    try {
      await fetchJSON(`${endpoint}/json/version`);
      return true;
    } catch {
      await new Promise((r) => setTimeout(r, 1000));
    }
  }
  return false;
}

/** Scrape the ICM incident summary page */
export async function scrapeICMIncident(
  incidentId: number
): Promise<string> {
  const cdpPort = 9222;

  // Step 1: Check if CDP is already reachable
  let cdpReady = false;
  try {
    await fetchJSON(`${CDP_HTTP}/json/version`);
    cdpReady = true;
  } catch {
    // Not running — try auto-setup
  }

  if (!cdpReady) {
    const winUser = getWindowsUser();
    const setupLog: string[] = ["🔧 Edge CDP not running — attempting auto-setup..."];

    if (isWSL()) {
      // WSL: set up port proxy first
      const proxyPort = parseInt(process.env.CDP_PORT || "9223", 10);
      setupLog.push("  Setting up port proxy...");
      ensurePortProxy(proxyPort, cdpPort);
    }

    // Launch Edge
    setupLog.push("  Launching Edge with --remote-debugging-port...");
    launchEdge(cdpPort, winUser);

    // Wait for CDP
    setupLog.push("  Waiting for Edge CDP to be ready (up to 10s)...");
    cdpReady = await waitForCDP(CDP_HTTP, 10);

    if (!cdpReady) {
      const lines = [...setupLog, "", `❌ Auto-setup failed. Could not connect to Edge CDP at ${CDP_HTTP}`, ""];

      if (process.platform === "win32") {
        lines.push(
          "This can happen if:",
          "- Edge is already running without CDP (close all Edge windows first)",
          `- Then launch Edge manually:`,
          `  Start-Process 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe' -ArgumentList '--remote-debugging-port=${cdpPort}','--user-data-dir=C:\\Users\\${winUser}\\.edge-cdp','--no-first-run'`,
          "",
          "Then retry this tool.",
        );
      } else {
        const proxyPort = parseInt(process.env.CDP_PORT || "9223", 10);
        lines.push(
          "This can happen if:",
          "- Edge is already running without CDP (close all Edge windows first)",
          "- Port proxy needs admin rights (run PowerShell as Admin once):",
          `  netsh interface portproxy add v4tov4 listenport=${proxyPort} listenaddress=0.0.0.0 connectport=${cdpPort} connectaddress=127.0.0.1`,
          `  New-NetFirewallRule -DisplayName "Edge CDP for WSL" -Direction Inbound -LocalPort ${proxyPort} -Protocol TCP -Action Allow`,
          "",
          "Then retry this tool.",
        );
      }

      return lines.join("\n");
    }

    setupLog.push("  ✅ Edge CDP is ready!");
    console.error(setupLog.join("\n"));
  }

  try {
    const { session } = await openFreshICMTab(incidentId);

    // Wait for page to settle after navigation
    await new Promise((r) => setTimeout(r, 5000));

    // Check if we landed on a sign-in page
    const currentUrl = await session.eval("window.location.href");
    if (
      currentUrl.includes("login.microsoftonline.com") ||
      currentUrl.includes("login.live.com")
    ) {
      session.close();
      return [
        "⚠️ Edge is on a sign-in page. Please sign in to ICM in the browser, then retry this tool.",
        `Current URL: ${currentUrl}`,
      ].join("\n");
    }

    // Capture authored summary + discussion entries via Network interception
    const details = await captureIncidentData(session, incidentId);

    // Also get the visible page text for context
    const pageText = await session.eval("document.body.innerText");
    session.close();

    const lines: string[] = [
      `### ICM ${incidentId} — Browser Scrape`,
      "",
      `**URL**: https://portal.microsofticm.com/imp/v5/incidents/details/${incidentId}/summary`,
      "",
    ];

    if (details?.summary) {
      const plainSummary = stripHtml(details.summary);
      lines.push("#### Authored Summary");
      lines.push(plainSummary);
      lines.push("");

      // Extract ARM resource IDs from authored summary
      const armIds =
        details.summary.match(
          /\/subscriptions\/[a-f0-9-]+\/resource[Gg]roups\/[^"'<>\s&;]+/gi
        ) || [];
      if (armIds.length > 0) {
        lines.push("#### Extracted ARM Resource IDs");
        const unique = [...new Set(armIds.map((m) => m.replace(/&amp;/g, "&")))];
        unique.forEach((id) => lines.push(`- \`${id}\``));
        lines.push("");
      }
    }

    if (details?.discussions && details.discussions.length > 0) {
      lines.push(`#### Discussion (${details.discussions.length} entries)`);
      for (const d of details.discussions) {
        const dateStr = d.date ? new Date(d.date).toISOString().split("T")[0] : "";
        lines.push(`**${d.by}** (${dateStr}):`);
        lines.push(d.text.length > 500 ? d.text.substring(0, 500) + "..." : d.text);
        lines.push("");
      }
    }

    if (pageText && pageText.length > 100) {
      lines.push("#### Page Header");
      lines.push(pageText.substring(0, 1500));
    } else if (!details?.summary) {
      lines.push(
        "⚠️ Could not extract authored summary or page content. The page may still be loading — retry in a few seconds."
      );
    }

    return lines.join("\n");
  } catch (err: any) {
    return `❌ Error scraping ICM ${incidentId}: ${err.message}`;
  }
}
