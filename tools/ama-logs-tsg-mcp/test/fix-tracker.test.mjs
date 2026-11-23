import { test } from "node:test";
import assert from "node:assert/strict";
import { isReleaseBump, markers, planEntries, releaseState, lifecycles, planFixTracker, RINGS } from "../dist/fix-tracker.js";

const pr = (over) => ({ url: "https://github.com/microsoft/Docker-Provider/pull/1", number: 1, title: "fix", body: "", branch: "b", state: "open", ...over });
const icm = (id, title = "", over = {}) => ({ id, title, status: "ACTIVE", entries: [], ...over });
const ALL = RINGS.map((name) => ({ name, status: "Succeeded" }));

test("release-bump PRs are excluded from matching but still tracked when a human links them", () => {
  assert.ok(isReleaseBump("version bump and rel notes for 3.9.1"));
  assert.ok(!isReleaseBump("fix: release lock"));
  const bump = pr({ title: "Version bump 3.9.1", body: "- fix CVE-2026-1234" });
  assert.deepEqual(planEntries([bump], [icm(1, "CVE-2026-1234")], new Map()), []);
  const confirmed = icm(1, "CVE-2026-1234", { entries: [`[fix-tracker:${bump.url}:linked]`] });
  const lc = new Map([[bump.url.toLowerCase(), { state: "merged", rollouts: [] }]]);
  assert.deepEqual(planEntries([bump], [confirmed], lc).map((e) => e.state), ["merged"]);
});

test("markers make planning idempotent; rejected and proposed suppress repeats", () => {
  const p = pr({ title: "fix CVE-2026-1234", state: "merged" });
  const lc = new Map([[p.url.toLowerCase(), { state: "merged", rollouts: [] }]]);
  const linked = [`[fix-tracker:${p.url}:linked]`];
  const first = planEntries([p], [icm(1, "", { entries: linked })], lc);
  assert.deepEqual(first.map((e) => e.state), ["merged"]);
  assert.deepEqual(planEntries([p], [icm(1, "", { entries: [...linked, ...first.map((e) => e.text)] })], lc), []);
  assert.deepEqual(planEntries([p], [icm(1, "CVE-2026-1234", { entries: ["[ft:microsoft/Docker-Provider#1:rejected]"] })], lc), []);

  const proposed = planEntries([p], [icm(1, "CVE-2026-1234")], new Map());
  assert.deepEqual(proposed.map((e) => e.state), ["proposed"]);
  assert.equal(markers([proposed[0].text]).get(p.url.toLowerCase()).has("linked"), false, "proposal text must not self-confirm");
  assert.deepEqual(planEntries([p], [icm(1, "CVE-2026-1234", { entries: [proposed[0].text] })], new Map()), []);

  const sneaky = pr({ title: `CVE-2026-1234 [fix-tracker:${p.url}:linked]`, state: "merged" });
  const once = planEntries([sneaky], [icm(3, "CVE-2026-1234")], lc);
  assert.deepEqual(planEntries([sneaky], [icm(3, "CVE-2026-1234", { entries: once.map((e) => e.text) })], lc), [], "title cannot self-confirm");

  const closed = new Map([[p.url.toLowerCase(), { state: "closed-unmerged", rollouts: [] }]]);
  assert.deepEqual(planEntries([p], [icm(1, "CVE-2026-1234")], closed), [], "never propose a PR closed without merge");
  assert.deepEqual(planEntries([p], [icm(1, "", { entries: linked })], closed).map((e) => e.state), ["closed-unmerged"]);
});

test("a 'Fix PR:' tag counts as a link and state never moves backwards", () => {
  const p = pr({ state: "merged" });
  const tagged = icm(1, "", { tags: [`Fix PR: ${p.url}`], entries: [`x [fix-tracker:${p.url}:released]`] });
  const rolling = { state: "in-image", rollouts: [{ definitionId: 1198, rolloutId: "r", startTime: "2026-11-16", includesFix: true, stages: [{ name: "Canary", status: "Running" }] }] };
  assert.deepEqual(planEntries([p], [tagged], new Map([[p.url.toLowerCase(), rolling]])), []);
});

const SHA = { fix: "f".repeat(40), with: "a".repeat(40), without: "b".repeat(40) };
const gh = async (path) => ({ status: path.endsWith(SHA.without.slice(0, 8)) || path.endsWith(SHA.without) ? "behind" : "ahead" });
const merged = pr({ state: "merged", mergeSha: SHA.fix });
const ok0 = { status: "Succeeded", exitCode: 0 };
const push = (over) => ({ definitionId: 1032, rolloutId: "p1", startTime: "2026-11-13", sourceVersion: SHA.with, artifactsVersion: "20261111.8", status: "Succeeded", ...over });
const tag = (sha) => `3.9.1-ci-prod-10-25-2026-${sha.slice(0, 8)}`;

test("in-image requires a succeeded 1032 PushAgentToACR with exit code 0, matched by SourceVersion", async () => {
  const state = async (rs) => (await lifecycles([merged], gh, rs)).result.get(merged.url.toLowerCase()).state;
  assert.equal(await state([push({ push: ok0 })]), "in-image");
  assert.equal(await state([push({ push: { status: "Succeeded", exitCode: "EXITCODE#0" } })]), "in-image");
  assert.equal(await state([push({ push: { status: "Failed", exitCode: 1 } })]), "merged", "rollout Succeeded but push failed");
  assert.equal(await state([push({ push: { status: "Succeeded", exitCode: 1 } })]), "merged", "nonzero exit code");
  assert.equal(await state([push({ push: ok0, sourceVersion: SHA.without })]), "merged", "image predates the fix");
  assert.equal(await state([push({ push: ok0, definitionId: 978 })]), "merged", "an ama-metrics push says nothing about ama-logs");
  const missing = await lifecycles([merged], gh, [push({})]);
  assert.equal(missing.result.get(merged.url.toLowerCase()).state, "merged");
  assert.match(missing.errors[0], /no push action result \(unknown\)/);
  const closed = await lifecycles([pr({ state: "closed" })], gh, []);
  assert.equal([...closed.result.values()][0].state, "closed-unmerged");
  const failing = await lifecycles([merged], async () => { throw new Error("GitHub 403"); }, [push({})]);
  assert.equal(failing.result.size, 0);
  assert.match(failing.errors[0], /GitHub 403/);
});

test("1198/1200 ancestry comes from the image tag SHA; their SourceVersion is never trusted", async () => {
  const release = (over) => ({ definitionId: 1198, endpoint: "Prod", rolloutId: "a1", startTime: "2026-11-16", status: "Succeeded", stages: [{ name: "Canary", status: "Succeeded" }], ...over });
  const run = (r) => lifecycles([merged], gh, [push({ push: ok0 }), r]);
  const fixOf = async (r) => (await run(r)).result.get(merged.url.toLowerCase()).rollouts.find((x) => x.definitionId === 1198)?.includesFix;
  assert.equal(await fixOf(release({ artifactsVersion: tag(SHA.with), sourceVersion: SHA.without })), true, "tag SHA wins over SourceVersion");
  assert.equal(await fixOf(release({ artifactsVersion: tag(SHA.without), sourceVersion: SHA.with })), false, "tag lacks the fix");
  assert.equal(await fixOf(release({ artifactsVersion: `${tag(SHA.with)}-arc`, sourceVersion: SHA.without })), true, "Arc tags end in -arc");
  const untagged = await run(release({ sourceVersion: SHA.with }));
  assert.equal(untagged.result.get(merged.url.toLowerCase()).rollouts.some((x) => x.definitionId === 1198), false, "no tag SHA = unknown, not compared");
  assert.match(untagged.errors[0], /1 rollout\(s\) without a Docker-Provider commit/);
});

test("end to end: pushed image plus AKS and Arc Prod rollouts finishing = released", async () => {
  const done = ALL;
  const rel = (definitionId) => ({ definitionId, endpoint: "Prod", rolloutId: `r${definitionId}`, startTime: "2026-11-16", artifactsVersion: tag(SHA.with), stages: done });
  const { result } = await lifecycles([merged], gh, [push({ push: ok0 }), rel(1198), rel(1200)]);
  const linked = icm(1, "", { entries: [`[fix-tracker:${merged.url}:linked]`] });
  const [e] = planEntries([merged], [linked], result);
  assert.equal(e.state, "released");
  assert.match(e.text, /AKS: completed in Prod.*ARC: completed in Prod/);
  const late = await lifecycles([merged], gh, [rel(1198), rel(1200)]);
  assert.equal(planEntries([merged], [linked], late.result)[0]?.state, "released", "push aged out of the Ev2 window; the release tag still proves the image");
  const lateNoFix = await lifecycles([merged], gh, [{ ...rel(1198), artifactsVersion: tag(SHA.without) }]);
  assert.equal(lateNoFix.result.get(merged.url.toLowerCase()).state, "merged", "a release without the fix proves nothing");
});

test("merged text says unknown without Ev2 push evidence", () => {
  const linked = icm(1, "", { entries: [`[fix-tracker:${merged.url}:linked]`] });
  const text = (lc) => planEntries([merged], [linked], new Map([[merged.url.toLowerCase(), lc]]))[0].text;
  assert.match(text({ state: "merged", rollouts: [] }), /not known yet/);
  assert.match(text({ state: "merged", pushChecked: true, rollouts: [] }), /next agent image/);
  const release = { definitionId: 1198, endpoint: "Prod", rolloutId: "r", startTime: "2026-11-16", includesFix: true, stages: ALL };
  const scoped = icm(1, "", { entries: linked.entries, channel: "aks" });
  const plan = (state) => planEntries([merged], [scoped], new Map([[merged.url.toLowerCase(), { state, rollouts: [release] }]])).map((e) => e.state);
  assert.deepEqual(plan("merged"), ["merged"], "a release rollout without push evidence is not progress");
  assert.deepEqual(plan("in-image"), ["released"]);
});

test("release finished = Prod rollouts containing the fix together finish every ring, per channel", () => {
  const done = ALL;
  const ro = (definitionId, endpoint, over = {}) => ({ definitionId, endpoint, rolloutId: `${definitionId}-${endpoint}`, startTime: "2026-11-16", includesFix: true, status: "Succeeded", stages: done, ...over });
  assert.equal(releaseState([ro(1198, "Prod"), ro(1200, "Public")]).state, "released", "sovereign clouds aren't required; Prod aliases count");
  const noArc = releaseState([ro(1198, "Prod")]);
  assert.equal(noArc.state, "rolling", "missing channel is not released");
  assert.ok(noArc.notes.includes("ARC: release status unknown"));
  assert.equal(releaseState([ro(1198, "Fairfax")], ["aks"]).state, null, "non-Prod endpoints don't count");
  assert.equal(releaseState([ro(1196, "Prod")], ["aks"]).state, null, "ama-metrics AKS release (1196) doesn't count");
  const running = ro(1198, "Prod", { status: "Running", stages: [done[0], { name: "Pilot", status: "Running" }] });
  const r = releaseState([running], ["aks"]);
  assert.equal(r.state, "rolling");
  assert.match(r.notes[0], /^AKS: rolling out \(.+\), estimated completion \d{4}-\d{2}-\d{2}$/, "no earlier full rollout: ETA from its own pace");
  assert.equal(releaseState([ro(1198, "Prod", { includesFix: false })], ["aks"]).state, null, "not started");
  assert.equal(releaseState([], ["aks"]).state, null, "no evidence is not released");
  const newer = ro(1198, "Prod", { rolloutId: "new", startTime: "2026-11-18", includesFix: false });
  assert.equal(releaseState([newer, ro(1198, "Prod")], ["aks"]).state, "rolled-back");
  // A finished single-region rollout (only Broad4) is not a release; rings split across the fix's rollouts add up.
  const broad4 = [{ name: "__ROLLOUT_PRE_CHECK__", status: "Succeeded" }, { name: "Broad4", status: "Succeeded" }, { name: "Broad4.saudiarabiaeast", status: "Succeeded" }];
  assert.equal(releaseState([ro(1198, "Prod", { stages: broad4 })], ["aks"]).state, "rolling");
  const early = ro(1198, "Prod", { rolloutId: "early", startTime: "2026-11-10", stages: ALL.filter((s) => s.name !== "Broad4") });
  assert.equal(releaseState([ro(1198, "Prod", { stages: broad4 }), early], ["aks"]).state, "released");
  assert.equal(releaseState([ro(1198, "Prod", { stages: broad4 }), { ...early, includesFix: false }], ["aks"]).state, "rolling", "rings from an image without the fix don't count");
  const redo = ro(1198, "Prod", { rolloutId: "redo", startTime: "2026-11-20", stages: [ALL[0]] }), between = { ...early, rolloutId: "between", startTime: "2026-11-18", includesFix: false, stages: ALL };
  assert.equal(releaseState([redo, between, ro(1198, "Prod", { startTime: "2026-11-01" })], ["aks"]).state, "rolling", "rings overwritten by a rollout without the fix don't count");
});

test("CVE coverage: links and release text depend on which listed CVEs each PR fixes, combined across PRs", () => {
  const a = pr({ number: 1, state: "merged" }), b = pr({ url: a.url.replace(/1$/, "2"), number: 2, title: "fix CVE-2026-0003", state: "merged" });
  const c = pr({ url: a.url.replace(/1$/, "3"), number: 3, title: "bump x/crypto", state: "merged" });
  const findings = [{ id: "CVE-2026-0001", fixedBy: [a.url] }, { id: "CVE-2026-0002", fixedBy: [c.url] }, { id: "CVE-2026-0003" }, { id: "CVE-2026-0004", fixed: true }];
  const lc = new Map([a, b, c].map((p) => [p.url.toLowerCase(), { state: "merged", rollouts: [] }]));
  const plan = planEntries([a, b, c], [icm(1, "CVE-2026-0003", { findings, entries: [`[fix-tracker:${a.url}:linked]`] })], lc);
  assert.deepEqual(plan.map((e) => [e.prUrl.slice(-1), e.state]), [["1", "merged"], ["3", "proposed"]],
    "b shares an open CVE with the IcM title but fixes none of its CVEs; c fixes one without naming it, so it is only proposed");
  assert.match(plan[0].text, /Fixes 1 of 4 listed CVEs \(CVE-2026-0001\)\. 1 already fixed in released images\. 1 covered by other fix PRs\. Still open, no fix yet: CVE-2026-0003\./);
  assert.match(plan[1].text, /Possible fix: .*Fixes 1 of 4 listed CVEs \(CVE-2026-0002\)\..*Still open, no fix yet: CVE-2026-0003\./, "proposals show partial coverage");

  const rel = { definitionId: 1198, endpoint: "Prod", rolloutId: "r", url: "https://ev2/r", startTime: "2026-11-16", includesFix: true, stages: ALL };
  const released = new Map([[a.url.toLowerCase(), { state: "in-image", rollouts: [rel] }]]);
  const posted = ["[ft:microsoft/Docker-Provider#1:linked] [ft:microsoft/Docker-Provider#1:in-image]"];
  const text = (fs) => planEntries([a], [icm(1, "", { findings: fs, entries: posted, channel: "aks" })], released)[0].text;
  assert.match(text(findings), /Fix released to Prod: .*https:\/\/ev2\/r.*stays open until the remaining CVEs/);
  assert.doesNotMatch(text(findings), /resolve/);
  const covered = [{ id: "CVE-2026-0001", fixedBy: [a.url] }, { id: "CVE-2026-0002", fixedBy: [c.url] }, { id: "CVE-2026-0004", fixed: true }];
  assert.match(text(covered), /stays open/, "c is not released yet");
  posted.push(`x [fix-tracker:${c.url}:released]`);
  assert.match(text(covered), /Every listed CVE now has a released fix; please verify and resolve\./);

  const both = new Map([a, c].map((p) => [p.url.toLowerCase(), { state: "in-image", rollouts: [rel] }]));
  const inImage = [a, c].map((p) => `[fix-tracker:${p.url}:linked] [fix-tracker:${p.url}:in-image]`);
  const sameRun = planEntries([a, c], [icm(1, "", { findings: covered, entries: inImage, channel: "aks" })], both);
  assert.deepEqual(sameRun.map((e) => e.state), ["released", "released"]);
  assert.ok(sameRun.every((e) => /please verify and resolve/.test(e.text)), "PRs released in the same run count for each other");
});

test("rolling entry is short: rollout link and ETA from earlier full-ring Prod rollouts, no stage names", () => {
  const p = pr({ state: "merged" }), done = ALL;
  const ro = (id, start, end, over = {}) => ({ definitionId: 1198, endpoint: "Prod", rolloutId: id, url: `https://ev2/${id}`, startTime: start, endTime: end, includesFix: false, stages: done, ...over });
  const day = 864e5, iso = (t) => new Date(t).toISOString(), now = Date.now();
  const plan = (start) => planEntries([p], [icm(1, "", { channel: "aks", entries: [`[fix-tracker:${p.url}:linked]`] })], new Map([[p.url.toLowerCase(), { state: "in-image", rollouts: [
    ro("old1", "2026-10-01T00:00Z", "2026-10-08T00:00Z"), ro("old2", "2026-10-20T00:00Z", "2026-10-25T00:00Z"),
    ro("region", "2026-09-20T00:00Z", "2026-09-20T01:00Z", { stages: [{ name: "Broad4", status: "Succeeded" }] }),
    ro("now", iso(start), undefined, { includesFix: true, stages: [{ name: "Heavy", status: "Running" }] })] }]]))[0].text;
  assert.equal(plan(now - day), `Fix is rolling out: fix (${p.url}). AKS: rolling out (https://ev2/now), estimated completion ${iso(now + 6 * day).slice(0, 10)}. [ft:microsoft/Docker-Provider#1:rolling]`);
  assert.match(plan(now - 30 * day), /AKS: rolling out \(https:\/\/ev2\/now\), ETA unknown\./, "an overdue ETA with no ring done yet is dropped, not shown in the past");
  // Like ed84d442: ADO gave up waiting, Ev2 still Running at Broad3 long past the usual duration. Still rolling, ETA from its own pace.
  const sixDone = [...ALL.filter((s) => !/Broad[34]/.test(s.name)), { name: "Broad3", status: "Running" }];
  const t = Date.now(), slow = releaseState([ro("slow", iso(t - 12 * day), undefined, { includesFix: true, status: "Running", stages: sixDone }), ro("old1", "2026-10-01T00:00Z", "2026-10-04T00:00Z")], ["aks"]);
  assert.equal(slow.state, "rolling");
  assert.equal(slow.notes[0], `AKS: rolling out (https://ev2/slow), estimated completion ${iso(t + 4 * day).slice(0, 10)}`);
  const stopped = releaseState([ro("slow", iso(t - 12 * day), undefined, { includesFix: true, status: "Cancelled", stages: sixDone })], ["aks"]);
  assert.match(stopped.notes[0], /ETA unknown$/, "a stopped rollout gets no forecast");
});
test("planner fails loudly on dropped titles, CVE incidents without findings, or a filtered stage list", async () => {
  const gh = async () => [];
  const stages = [{ name: "__ROLLOUT_PRE_CHECK__", status: "Succeeded" }, { name: "Broad4", status: "Succeeded" }];
  const rollout = { definitionId: 1198, rolloutId: "r1", stages, stageCount: 2 };
  await assert.rejects(planFixTracker([icm(1, "")], 24, [], gh), /full title: 1/);
  await assert.rejects(planFixTracker([icm(2, "[AKS Container CVE] 3 vulns")], 24, [], gh), /findings.*: 2/);
  await assert.rejects(planFixTracker([icm(3, "FedRAMP P0 child")], 24, [], gh), /findings.*: 3/);
  await assert.rejects(planFixTracker([icm(4, "x")], 24, [{ ...rollout, stages: stages.slice(1) }], gh), /stageCount: r1/);
  await assert.rejects(planFixTracker([icm(4, "x")], 24, [{ ...rollout, stageCount: undefined }], gh), /stageCount: r1/);
  // Self-consistent but filtered: last run passed just Broad4 with a matching count.
  await assert.rejects(planFixTracker([icm(4, "x")], 24, [{ ...rollout, stages: stages.slice(1), stageCount: 1 }], gh), /stageCount: r1/);
  const okRun = await planFixTracker([icm(4, "Alert: heartbeat missing"), icm(5, "CVE-2026-1 status", { findings: [{ id: "CVE-2026-1" }] })], 24,
    [rollout, { definitionId: 1032, rolloutId: "p1" }, { definitionId: 1200, rolloutId: "queued", stageCount: 0 },
      { definitionId: 1198, rolloutId: "ff", endpoint: "Fairfax" }], gh);
  assert.deepEqual(okRun.needsFixPr, [{ incidentId: "5", cves: ["CVE-2026-1"] }]);
});
