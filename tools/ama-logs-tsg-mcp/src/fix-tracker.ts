// Plans IcM discussion entries that track microsoft/Docker-Provider fix PRs from link to release. Read-only:
// the SRE agent supplies incidents (with their entries) and Ev2 rollouts (from ev2-mcp) and posts the planned entries itself.

export const REPO = "microsoft/Docker-Provider";
// Ev2 definitions: 1032 pushes the ama-logs image; 1198/1200 roll the extension out to AKS (SDP) and Arc.
export const DEFS = { push: 1032, aks: 1198, arc: 1200 };
type Channel = "aks" | "arc";
// ponytail: release = the Ev2 Prod endpoint finishing (team decision); sovereign endpoints aren't tracked.
const isProd = (r: Rollout) => !/^(fairfax|mooncake|ussec|usnat|bleu|delos)$/i.test(r.endpoint?.trim() ?? "");
const PROGRESS = ["linked", "merged", "in-image", "rolling", "released"];

export interface Incident { id: string | number; title?: string; status?: string; tags?: string[]; entries?: string[]; channel?: Channel }
export interface PullRequest { url: string; number: number; title: string; body?: string | null; branch?: string; state: "open" | "closed" | "merged"; mergeSha?: string | null }
export interface Match { incidentId: string; confidence: "linked" | "proposed"; evidence: string }
// Shaped from ev2-mcp get_rollout_summary (stages) and get_rollout_details for shell/PushAgentToACR (push). No log text.
export interface Rollout {
  definitionId: number; endpoint?: string; rolloutId: string; status?: string; startTime?: string; sourceVersion?: string;
  artifactsVersion?: string; url?: string; stages?: { name: string; status: string }[]; push?: { status?: string; exitCode?: number | string };
}
export type TrackedRollout = Rollout & { includesFix: boolean };
export interface PlannedEntry { incidentId: string; prUrl: string; state: string; text: string }

export const marker = (prUrl: string, state: string) => `[fix-tracker:${prUrl}:${state}]`;

export function markers(entries: string[] = []) {
  const found = new Map<string, Set<string>>();
  for (const m of entries.join("\n").matchAll(/\[fix-tracker:(https:\/\/github\.com\/[^\]\s]+\/pull\/\d+):([a-z-]+)\]/gi)) {
    const url = m[1].toLowerCase();
    if (!found.has(url)) found.set(url, new Set());
    const state = m[2].toLowerCase();
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

// Per channel from Prod Ev2 stage summaries. Released = a rollout containing the fix has every stage Succeeded and
// no later rollout dropped it. Missing evidence is reported as unknown, never as done. This is not fleet adoption.
export function releaseState(rollouts: TrackedRollout[], channels: Channel[] = ["aks", "arc"]) {
  let done = 0, started = false, back = false;
  const notes: string[] = [];
  for (const channel of channels) {
    const rs = rollouts.filter((r) => r.definitionId === DEFS[channel] && isProd(r))
      .sort((a, b) => Date.parse(b.startTime ?? "") - Date.parse(a.startTime ?? ""));
    const label = `${channel.toUpperCase()} Prod`, latest = rs[0], idx = rs.findIndex((r) => r.includesFix);
    const shipped = rs.find((r) => r.includesFix && r.stages?.length && r.stages.every((s) => ok(s.status)));
    if (!latest) notes.push(`${label}: no Ev2 evidence (unknown)`);
    else if (idx > 0) { back = true; notes.push(`${label}: latest ${ref(latest)} does not contain the fix; ${ref(rs[idx])} did`); }
    else if (shipped) { done++; notes.push(`${label}: all stages Succeeded (${ref(shipped)})`); }
    else if (idx === 0) {
      started = true;
      const at = latest.stages?.find((s) => !ok(s.status));
      notes.push(`${label}: ${latest.status ?? "status unknown"}${at ? `, stage ${at.name} ${at.status}` : ""} (${ref(latest)})`);
    } else notes.push(`${label}: not started`);
  }
  const state = back ? "rolled-back" : channels.length && done === channels.length ? "released" : started || done ? "rolling" : null;
  return { state, notes };
}

export interface Lifecycle { state: "open" | "closed-unmerged" | "merged" | "in-image"; image?: string; imageRef?: string; pushChecked?: boolean; rollouts: TrackedRollout[] }

const DETAIL: Record<string, (l: Lifecycle, notes: string[]) => string> = {
  merged: (l) => l.pushChecked ? "Fix PR merged; no Ev2 image push containing it has a succeeded push action (exit code 0) yet."
    : "Fix PR merged; image and rollout status unknown (no Ev2 push evidence supplied).",
  "in-image": (l, n) => `Fix is in image ${l.image ?? "(tag unknown)"} (${l.imageRef}). Release: ${n.join("; ") || "not started"}.`,
  rolling: (_, n) => `Fix is rolling out (Ev2 stage status): ${n.join("; ")}.`,
  released: (_, n) => `All required Ev2 release rollouts containing the fix have every stage Succeeded: ${n.join("; ")}. Ev2 completion is not fleet adoption; a human should verify and mitigate/resolve.`,
  "rolled-back": (_, n) => `A newer Ev2 rollout no longer contains this fix (rollback or older version): ${n.join("; ")}. Needs human review.`,
  "closed-unmerged": () => "Fix PR was closed without merging. Needs human review.",
};

export function planEntries(prs: PullRequest[], incidents: Incident[], lifecycles: Map<string, Lifecycle>): PlannedEntry[] {
  const out: PlannedEntry[] = [], active = incidents.filter((i) => !/resolved/i.test(i.status ?? ""));
  // Match against all active IcMs at once so an MSRC case shared by several IcMs stays a proposal.
  // Release-bump notes quote other PRs' IcM references; only a human link can attach one.
  const matches = new Map(prs.map((pr) => [pr.url.toLowerCase(), isReleaseBump(pr.title) ? [] : matchIcms(pr, active)]));
  for (const incident of active) {
    const id = String(incident.id), seen = markers(incident.entries);
    const tagged = new Set((incident.tags ?? []).map((t) => /^Fix PR:\s*(\S+)/i.exec(t)?.[1]?.toLowerCase()).filter(Boolean));
    for (const pr of prs) {
      const key = pr.url.toLowerCase(), posted = seen.get(key) ?? new Set<string>();
      if (posted.has("rejected")) continue;
      const match = matches.get(key)!.find((m) => m.incidentId === id);
      // Brackets stripped so a PR title cannot smuggle a [fix-tracker:...] marker into a posted entry.
      const title = pr.title.replace(/[[\]]/g, "");
      const linked = posted.has("linked") || tagged.has(key) || match?.confidence === "linked";
      const add = (state: string, detail: string) =>
        out.push({ incidentId: id, prUrl: pr.url, state, text: `${detail} ${marker(pr.url, state)}` });
      if (!linked) {
        if (match && !posted.has("proposed") && lifecycles.get(key)?.state !== "closed-unmerged")
          add("proposed", `Possible fix PR ${pr.url} ("${title}"). Evidence: ${match.evidence}. Not linked automatically. ` +
            `To confirm, post an entry containing "fix-tracker:${pr.url}:linked" in square brackets; to reject, use ":rejected" instead.`);
        continue;
      }
      const lc = lifecycles.get(key);
      if (!posted.has("linked") && !tagged.has(key)) {
        if (lc?.state === "closed-unmerged") continue;
        add("linked", `Fix PR linked: ${pr.url} ("${title}"). Evidence: ${match?.evidence ?? "confirmed by a human"}.`);
      }
      if (!lc || lc.state === "open") continue;
      if (lc.state === "closed-unmerged") { if (!posted.has(lc.state)) add(lc.state, DETAIL[lc.state](lc, [])); continue; }
      const rel = lc.state === "in-image" ? releaseState(lc.rollouts, incident.channel ? [incident.channel] : undefined) : { state: null, notes: [] };
      const state = rel.state ?? lc.state;
      if (state === "rolled-back") { if (!posted.has(state)) add(state, DETAIL[state](lc, rel.notes)); continue; }
      const top = Math.max(...[...posted].map((s) => PROGRESS.indexOf(s)), 0);
      if (PROGRESS.indexOf(state) > top) add(state, DETAIL[state](lc, rel.notes));
    }
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
  r.artifactsVersion?.match(/-([0-9a-f]{7,40})$/i)?.[1] || (r.definitionId === DEFS.push ? r.sourceVersion : undefined);

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
  const since = new Date(Date.now() - lookbackHours * 3600e3);
  const scanned = await recentPrs(gh, since);
  const tracked = new Set<string>();
  for (const i of incidents) {
    for (const url of markers(i.entries).keys()) tracked.add(url);
    for (const t of i.tags ?? []) { const u = /^Fix PR:\s*(\S+)/i.exec(t)?.[1]; if (u) tracked.add(u.toLowerCase()); }
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
  };
}
