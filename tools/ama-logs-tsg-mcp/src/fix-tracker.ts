// Plans IcM discussion entries that track microsoft/Docker-Provider fix PRs from link to release. Read-only:
// the SRE agent supplies incidents (with their entries) and Ev2 rollouts (from ev2-mcp) and posts the planned entries itself.

export const REPO = "microsoft/Docker-Provider";
// Ev2 definitions: 1032 pushes the ama-logs image; 1198/1200 roll the extension out to AKS (SDP) and Arc.
export const DEFS = { push: 1032, aks: 1198, arc: 1200 };
type Channel = "aks" | "arc";
// ponytail: release = the Ev2 Prod endpoint finishing (team decision); sovereign endpoints aren't tracked.
const isProd = (r: Rollout) => !/^(fairfax|mooncake|ussec|usnat|bleu|delos)$/i.test(r.endpoint?.trim() ?? "");
const PROGRESS = ["linked", "merged", "in-image", "rolling", "released"];

// findings: CVEs the agent extracted from the incident; fixedBy = fix PR URLs it verified; fixed = already in a released image.
export interface Finding { id: string; fixedBy?: string[]; fixed?: boolean }
export interface Incident { id: string | number; title?: string; status?: string; tags?: string[]; entries?: string[]; channel?: Channel; findings?: Finding[] }
export interface PullRequest { url: string; number: number; title: string; body?: string | null; branch?: string; state: "open" | "closed" | "merged"; mergeSha?: string | null }
export interface Match { incidentId: string; confidence: "linked" | "proposed"; evidence: string }
// Shaped from ev2-mcp get_rollout_summary (stages) and get_rollout_details for shell/PushAgentToACR (push). No log text.
export interface Rollout {
  definitionId: number; endpoint?: string; rolloutId: string; status?: string; startTime?: string; endTime?: string; sourceVersion?: string;
  artifactsVersion?: string; url?: string; stages?: { name: string; status: string }[]; stageCount?: number; push?: { status?: string; exitCode?: number | string };
}
export type TrackedRollout = Rollout & { includesFix: boolean };
export interface PlannedEntry { incidentId: string; prUrl: string; state: string; text: string }

// Short so it stays unobtrusive in customer-facing entries; markers() also reads the older [fix-tracker:<url>:<state>] form.
const short = (prUrl: string) => prUrl.replace(/^https:\/\/github\.com\/([^/]+\/[^/]+)\/pull\/(\d+).*$/i, "$1#$2");
export const marker = (prUrl: string, state: string) => `[ft:${short(prUrl)}:${state}]`;

export function markers(entries: string[] = []) {
  const found = new Map<string, Set<string>>();
  for (const m of entries.join("\n").matchAll(/\[(?:fix-tracker:(https:\/\/github\.com\/[^\]\s]+\/pull\/\d+)|ft:([\w.-]+\/[\w.-]+)#(\d+)):([a-z-]+)\]/gi)) {
    const url = (m[1] ?? `https://github.com/${m[2]}/pull/${m[3]}`).toLowerCase();
    if (!found.has(url)) found.set(url, new Set());
    const state = m[4].toLowerCase();
    found.get(url)!.add(state === "abandoned" ? "closed-unmerged" : state);
  }
  return found;
}

export const isReleaseBump = (title: string) => /\bversion bump\b|\brel(?:ease)?[ -]?notes\b/i.test(title);

export function extractEvidence(pr: PullRequest) {
  const text = `${pr.title}\n${pr.body ?? ""}\n${pr.branch ?? ""}`;
  const strong = new Set<string>(), weak = new Set<string>(), msrc = new Set<string>(), cve = new Set<string>();
  for (const m of text.matchAll(/microsofticm\.com\/imp\/v\d+\/incidents\/(?:details|incident)\/(\d{9,14})/gi)) strong.add(m[1]);
  for (const m of text.matchAll(/\b(?:icm|incident)s?\b[^\d\n]{0,20}(\d{9,14})\b/gi)) strong.add(m[1]);
  for (const m of text.matchAll(/\b(\d{9,14})\b/g)) if (!strong.has(m[1])) weak.add(m[1]);
  for (const m of text.matchAll(/\bmsrc[\s_#:-]*(?:case[\s#:]*)?(\d{5,7})\b/gi)) msrc.add(m[1]);
  for (const m of text.matchAll(/\bCVE-\d{4}-\d{4,}\b/gi)) cve.add(m[0].toUpperCase());
  return { strong, weak, msrc, cve };
}

// Auto-link only on an explicit IcM reference or a unique MSRC case; everything weaker is a proposal for a human.
export function matchIcms(pr: PullRequest, incidents: Incident[]): Match[] {
  const ev = extractEvidence(pr), matches: Match[] = [];
  const msrcHits = incidents.filter((i) => [...ev.msrc].some((c) => msrcCase(i.title) === c));
  for (const i of incidents) {
    const id = String(i.id), cves = [...ev.cve].filter((c) => (i.title ?? "").toUpperCase().includes(c));
    if (ev.strong.has(id)) matches.push({ incidentId: id, confidence: "linked", evidence: `PR references IcM ${id}` });
    else if (msrcHits.includes(i)) matches.push({ incidentId: id, confidence: msrcHits.length === 1 ? "linked" : "proposed",
      evidence: `PR references MSRC case ${msrcCase(i.title)}${msrcHits.length > 1 ? ` (matches ${msrcHits.length} IcMs)` : ""}` });
    else if (ev.weak.has(id)) matches.push({ incidentId: id, confidence: "proposed", evidence: `PR contains the number ${id} without an IcM keyword` });
    else if (cves.length) matches.push({ incidentId: id, confidence: "proposed", evidence: `PR and IcM title share ${cves.join(", ")}` });
  }
  return matches;
}

const msrcCase = (title = "") => /\bMSRC\]?\s*\[?\s*(\d{5,7})\b/i.exec(title)?.[1];

const ref = (r: Rollout) => r.url ?? `Ev2 Prod rollout ${r.rolloutId}`;
const ok = (s?: string) => /^succeeded$/i.test(s ?? "");
const median = (xs: number[]) => xs.sort((a, b) => a - b)[Math.floor(xs.length / 2)];

// Per channel from Prod Ev2 stage summaries. Released = a rollout containing the fix has every stage Succeeded and
// no later rollout dropped it. Missing evidence is reported as unknown, never as done. This is not fleet adoption.
export function releaseState(rollouts: TrackedRollout[], channels: Channel[] = ["aks", "arc"]) {
  let done = 0, started = false, back = false;
  const notes: string[] = [];
  for (const channel of channels) {
    const rs = rollouts.filter((r) => r.definitionId === DEFS[channel] && isProd(r))
      .sort((a, b) => Date.parse(b.startTime ?? "") - Date.parse(a.startTime ?? ""));
    const label = channel.toUpperCase(), latest = rs[0], idx = rs.findIndex((r) => r.includesFix);
    const complete = (r: Rollout) => !!r.stages?.length && r.stages.every((s) => ok(s.status));
    const shipped = rs.find((r) => r.includesFix && complete(r));
    if (!latest) notes.push(`${label}: release status unknown`);
    else if (idx > 0) { back = true; notes.push(`${label}: newer rollout ${ref(latest)} does not include the fix`); }
    else if (shipped) { done++; notes.push(`${label}: completed in Prod (${ref(shipped)})`); }
    else if (idx === 0) {
      started = true;
      // ETA = start + median duration of earlier completed Prod rollouts of this definition: an estimate, not a promise.
      const took = rs.slice(1).filter((r) => complete(r) && r.startTime && r.endTime).map((r) => Date.parse(r.endTime!) - Date.parse(r.startTime!));
      const at = took.length && latest.startTime ? Date.parse(latest.startTime) + median(took) : 0;
      const eta = at > Date.now() ? new Date(at).toISOString().slice(0, 10) : null; // an overdue estimate is no estimate
      notes.push(`${label}: rolling out (${ref(latest)}), ${eta ? `estimated completion ${eta}` : "ETA unknown"}`);
    } else notes.push(`${label}: not started`);
  }
  const state = back ? "rolled-back" : channels.length && done === channels.length ? "released" : started || done ? "rolling" : null;
  return { state, notes };
}

export interface Lifecycle { state: "open" | "closed-unmerged" | "merged" | "in-image"; image?: string; imageRef?: string; pushChecked?: boolean; rollouts: TrackedRollout[] }

// Customer-readable: what is fixed, the rollout link and ETA. Stage internals stay in Ev2.
const DETAIL: Record<string, (fix: string, l: Lifecycle | undefined, notes: string[]) => string> = {
  linked: (fix) => `Fix in progress: ${fix}.`,
  merged: (fix, l) => `Fix merged: ${fix}. ${l?.pushChecked ? "It will ship in the next agent image." : "Image and rollout status not known yet."}`,
  "in-image": (fix, l, n) => `Fix is built into agent image ${l?.image ?? "(tag unknown)"}: ${fix}. ${n.join("; ") || "Rollout not started"}.`,
  rolling: (fix, _, n) => `Fix is rolling out: ${fix}. ${n.join("; ")}.`,
  released: (fix, _, n) => `Fix released to Prod: ${fix}. ${n.join("; ")}.`,
  "rolled-back": (fix, _, n) => `Fix was rolled back: ${fix}. ${n.join("; ")}. We are reviewing.`,
  "closed-unmerged": (fix) => `Fix PR was closed without merging: ${fix}. We are reviewing next steps.`,
};

const list = (ids: string[]) => ids.length > 5 ? `${ids.slice(0, 5).join(", ")} and ${ids.length - 5} more` : ids.join(", ");
const fixes = (i: Incident, key: string) => (i.findings ?? []).filter((f) => f.fixedBy?.some((u) => u.toLowerCase() === key)).map((f) => f.id);
// Findings with neither a verified fix PR nor an already-released fix: candidates for a new fix PR.
export const unfixed = (i: Incident) => (i.findings ?? []).filter((f) => !f.fixed && !f.fixedBy?.length).map((f) => f.id);

// Coverage combines all fix PRs; "released" only invites resolving when every finding has a released fix.
function coverage(i: Incident, key: string, state: string, releasedPrs: Set<string>) {
  const all = i.findings ?? [];
  if (!all.length) return state === "released" ? " Please verify and resolve." : "";
  const mine = fixes(i, key), open = unfixed(i), done = all.filter((f) => f.fixed && !mine.includes(f.id)).length;
  const others = all.length - mine.length - open.length - done;
  let text = ` Fixes ${mine.length} of ${all.length} listed CVEs${mine.length ? ` (${list(mine)})` : ""}.`;
  if (done) text += ` ${done} already fixed in released images.`;
  if (others) text += ` ${others} covered by other fix PRs.`;
  if (open.length) text += ` Still open, no fix yet: ${list(open)}.`;
  if (state !== "released") return text;
  const pending = all.some((f) => !f.fixed && !f.fixedBy?.some((u) => u.toLowerCase() === key || releasedPrs.has(u.toLowerCase())));
  return text + (pending ? " The incident stays open until the remaining CVEs are fixed and released." : " Every listed CVE now has a released fix; please verify and resolve.");
}

export function planEntries(prs: PullRequest[], incidents: Incident[], lifecycles: Map<string, Lifecycle>): PlannedEntry[] {
  const out: PlannedEntry[] = [], active = incidents.filter((i) => !/resolved/i.test(i.status ?? ""));
  // Match against all active IcMs at once so an MSRC case shared by several IcMs stays a proposal.
  // Release-bump notes quote other PRs' IcM references; only a human link can attach one.
  const matches = new Map(prs.map((pr) => [pr.url.toLowerCase(), isReleaseBump(pr.title) ? [] : matchIcms(pr, active)]));
  for (const incident of active) {
    const id = String(incident.id), seen = markers(incident.entries);
    const releasedPrs = new Set([...seen].filter(([, s]) => s.has("released")).map(([u]) => u));
    // Rendered after every PR is planned, so PRs released in the same run count as released for each other.
    const render: (() => PlannedEntry)[] = [];
    const tagged = new Set((incident.tags ?? []).map((t) => /^Fix PR:\s*(\S+)/i.exec(t)?.[1]?.toLowerCase()).filter(Boolean));
    for (const pr of prs) {
      const key = pr.url.toLowerCase(), posted = seen.get(key) ?? new Set<string>();
      if (posted.has("rejected")) continue;
      const covers = fixes(incident, key);
      // A PR that fixes none of the incident's listed CVEs is not its fix, whatever its text says; humans can still link it.
      if (incident.findings?.length && !covers.length && !posted.has("linked") && !tagged.has(key)) continue;
      const match = matches.get(key)!.find((m) => m.incidentId === id)
        ?? (covers.length ? { incidentId: id, confidence: "proposed" as const, evidence: `it updates the packages for ${list(covers)}` } : undefined);
      // Brackets stripped so a PR title cannot smuggle a marker into a posted entry.
      const title = pr.title.replace(/[[\]]/g, "");
      const linked = posted.has("linked") || tagged.has(key) || match?.confidence === "linked";
      const fix = `${title} (${pr.url})`, lc = lifecycles.get(key);
      const add = (state: string, notes: string[] = []) => {
        if (state === "released") releasedPrs.add(key);
        render.push(() => ({ incidentId: id, prUrl: pr.url, state,
          text: `${DETAIL[state](fix, lc, notes)}${/closed|rolled/.test(state) ? "" : coverage(incident, key, state, releasedPrs)} ${marker(pr.url, state)}` }));
      };
      if (!linked) {
        if (match && !posted.has("proposed") && lc?.state !== "closed-unmerged")
          render.push(() => ({ incidentId: id, prUrl: pr.url, state: "proposed", text: `Possible fix: ${fix}, because ${match.evidence}.${coverage(incident, key, "proposed", releasedPrs)} Not linked yet. ` +
            `To confirm, add the tag "Fix PR: ${pr.url}"; to reject, post an entry containing ft:${short(pr.url)}:rejected in square brackets. ${marker(pr.url, "proposed")}` }));
        continue;
      }
      if (!posted.has("linked") && !tagged.has(key)) {
        if (lc?.state === "closed-unmerged") continue;
        add("linked");
      }
      if (!lc || lc.state === "open") continue;
      if (lc.state === "closed-unmerged") { if (!posted.has(lc.state)) add(lc.state); continue; }
      const rel = lc.state === "in-image" ? releaseState(lc.rollouts, incident.channel ? [incident.channel] : undefined) : { state: null, notes: [] };
      const state = rel.state ?? lc.state;
      if (state === "rolled-back") { if (!posted.has(state)) add(state, rel.notes); continue; }
      const top = Math.max(...[...posted].map((s) => PROGRESS.indexOf(s)), 0);
      if (PROGRESS.indexOf(state) > top) add(state, rel.notes);
    }
    out.push(...render.map((r) => r()));
  }
  return out;
}

// ---- I/O (GitHub REST). Injectable for tests.

type Get = (url: string) => Promise<any>;

export function githubGet(token = process.env.GITHUB_TOKEN): Get {
  return async (path) => {
    const res = await fetch(`https://api.github.com/${path}`, { headers: {
      Accept: "application/vnd.github+json", "User-Agent": "ama-logs-tsg-mcp", ...(token ? { Authorization: `Bearer ${token}` } : {}) } });
    if (!res.ok) throw new Error(`GitHub ${res.status}: ${path}`);
    return res.json();
  };
}

const toPr = (p: any): PullRequest => ({ url: p.html_url, number: p.number, title: p.title, body: p.body, branch: p.head?.ref,
  state: p.merged_at ? "merged" : p.state, mergeSha: p.merged_at ? p.merge_commit_sha : null });

export async function recentPrs(gh: Get, since: Date) {
  const prs: PullRequest[] = [];
  for (let page = 1; page <= 10; page++) {
    const batch = await gh(`repos/${REPO}/pulls?state=all&sort=updated&direction=desc&per_page=100&page=${page}`);
    for (const p of batch) if (Date.parse(p.created_at) >= +since || Date.parse(p.merged_at) >= +since) prs.push(toPr(p));
    if (batch.length < 100 || Date.parse(batch.at(-1).updated_at) < +since) break;
  }
  return prs;
}

// The Docker-Provider commit a rollout shipped. 1198/1200 deploy an image tag ending in that SHA
// (3.9.1-ci-prod-10-25-2026-46052686) but run from another repo, so their SourceVersion is not trusted.
// 1032's ArtifactsVersion is a build number with no SHA, so its SourceVersion is the fallback.
export const commitOf = (r: Rollout) =>
  r.artifactsVersion?.match(/-([0-9a-f]{7,40})(?:-arc)?$/i)?.[1] || (r.definitionId === DEFS.push ? r.sourceVersion : undefined);

// Annotates every rollout with whether its commit contains the PR's merge commit (GitHub compare).
export async function lifecycles(prs: PullRequest[], gh: Get, rollouts: Rollout[], track?: Set<string>) {
  const result = new Map<string, Lifecycle>(), errors: string[] = [], cache = new Map<string, Promise<boolean>>();
  for (const p of prs) if (p.state !== "merged") result.set(p.url.toLowerCase(), { state: p.state === "open" ? "open" : "closed-unmerged", rollouts: [] });
  const contains = (fix: string, sha: string) => {
    const k = `${fix}...${sha}`;
    if (!cache.has(k)) cache.set(k, gh(`repos/${REPO}/compare/${k}`).then((c) => ["ahead", "identical"].includes(c.status)));
    return cache.get(k)!;
  };
  const known = rollouts.filter(commitOf);
  if (known.length < rollouts.length) errors.push(`${rollouts.length - known.length} rollout(s) without a Docker-Provider commit (image tag SHA or 1032 sourceVersion) ignored (unknown)`);
  const shas = [...new Set(known.map((r) => commitOf(r)!))];
  for (const p of prs.filter((x) => x.state === "merged" && x.mergeSha && (!track || track.has(x.url.toLowerCase())))) {
    try {
      const has = new Map(await Promise.all(shas.map(async (s) => [s, await contains(p.mergeSha!, s)] as const)));
      const tracked = known.map((r) => ({ ...r, includesFix: has.get(commitOf(r)!)! }));
      const pushes = tracked.filter((r) => r.definitionId === DEFS.push);
      // In image only on the push action's own result; the overall rollout status covers more than the push.
      const pushed = pushes.find((r) => r.includesFix && ok(r.push?.status) && /^(?:exitcode#)?0$/i.test(String(r.push?.exitCode)));
      for (const r of pushes) if (r.includesFix && !r.push) errors.push(`${p.url}: push rollout ${r.rolloutId} contains the fix but has no push action result (unknown)`);
      // Releases trail the push by weeks, so the push can fall out of the 29-day Ev2 window; a release deploying a tag with the fix proves the image too.
      const deployed = tracked.find((r) => (r.definitionId === DEFS.aks || r.definitionId === DEFS.arc) && r.includesFix);
      const shown = pushed ?? deployed;
      result.set(p.url.toLowerCase(), { state: shown ? "in-image" : "merged", image: shown?.artifactsVersion,
        imageRef: pushed ? `${ref(pushed)}, push action exit code 0` : deployed && `deployed by ${ref(deployed)}`,
        pushChecked: pushes.some((r) => r.push), rollouts: tracked });
    } catch (e: any) { errors.push(`${p.url}: ${e.message}`); }
  }
  return { result, errors };
}

export async function planFixTracker(incidents: Incident[], lookbackHours = 24, rollouts: Rollout[] = [], gh = githubGet()) {
  // Fail the whole call, not just one incident: an agent that dropped titles or findings must redo its input before posting anything.
  const untitled = incidents.filter((i) => !i.title?.trim());
  if (untitled.length) throw new Error(`Every incident needs its full title: ${untitled.map((i) => i.id).join(", ")}`);
  const noFindings = incidents.filter((i) => !i.findings?.length && /\bCVE\b|CVE-\d|FedRAMP|vulnerab/i.test([i.title, ...(i.tags ?? [])].join(" ")));
  if (noFindings.length) throw new Error(`CVE incidents need findings (one per listed CVE): ${noFindings.map((i) => i.id).join(", ")}`);
  // A filtered stage list could fake "released". Ev2 lists __ROLLOUT_PRE_CHECK__ in every started rollout; the agent's own count catches dropped regions.
  const partial = rollouts.filter((r) => r.definitionId !== DEFS.push && isProd(r) && ((r.stages?.length ?? 0) !== r.stageCount
    || (!!r.stages?.length && !r.stages.some((s) => s.name === "__ROLLOUT_PRE_CHECK__"))));
  if (partial.length) throw new Error(`Rollouts need every StageInfos entry and stageCount: ${partial.map((r) => r.rolloutId).join(", ")}`);
  const since = new Date(Date.now() - lookbackHours * 3600e3);
  const scanned = await recentPrs(gh, since);
  const tracked = new Set<string>();
  for (const i of incidents) {
    for (const url of markers(i.entries).keys()) tracked.add(url);
    for (const t of i.tags ?? []) { const u = /^Fix PR:\s*(\S+)/i.exec(t)?.[1]; if (u) tracked.add(u.toLowerCase()); }
    for (const f of i.findings ?? []) for (const u of f.fixedBy ?? []) tracked.add(u.toLowerCase());
  }
  const prs = new Map(scanned.map((p) => [p.url.toLowerCase(), p]));
  const prefix = `https://github.com/${REPO.toLowerCase()}/pull/`, fetchErrors: string[] = [];
  for (const url of tracked) if (url.startsWith(prefix) && !prs.has(url)) {
    try { prs.set(url, toPr(await gh(`repos/${REPO}/pulls/${url.slice(prefix.length)}`))); }
    catch (e: any) { fetchErrors.push(`${url}: ${e.message}`); }
  }
  const all = [...prs.values()], active = incidents.filter((i) => !/resolved/i.test(i.status ?? ""));
  // Only linked PRs need Ev2 ancestry; proposals and unrelated PRs would just burn GitHub compare calls.
  const linked = new Set([...tracked, ...all.filter((p) => !isReleaseBump(p.title) && matchIcms(p, active).some((m) => m.confidence === "linked"))
    .map((p) => p.url.toLowerCase())]);
  const { result, errors } = await lifecycles(all, gh, rollouts, linked);
  return {
    since: since.toISOString(), scanned: scanned.length,
    excludedReleaseBumps: scanned.filter((p) => isReleaseBump(p.title)).map((p) => p.url),
    entries: planEntries(all, incidents, result), errors: [...fetchErrors, ...errors],
    needsFixPr: active.map((i) => ({ incidentId: String(i.id), cves: unfixed(i) })).filter((n) => n.cves.length),
  };
}
