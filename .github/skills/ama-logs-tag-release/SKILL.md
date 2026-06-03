---
name: ama-logs-tag-release
description: "Create and push the git tag (e.g. 3.4.0) for an ama-logs release after its release-notes PR has merged into ci_prod. Use when: 'tag the release', 'cut the 3.X.Y tag', 'create release tag', 'tag ci_prod for release'. DO NOT USE FOR: tagging hotfixes on branches other than ci_prod, creating GitHub Releases with binaries, or signing tags."
argument-hint: "[version] — e.g. '3.4.0'. If omitted, infer from charts/azuremonitor-containerinsights/Chart.yaml."
---

# ama-logs Release Tag

After the release-notes / chart-bump PR (see the `ama-logs-update-charts-release-notes` skill) lands on `ci_prod`, the release is tagged. The tag is what downstream pipelines and the publishing job key off of.

This skill creates the `<VERSION>` git tag on the merge commit of the release PR and pushes it to `origin`. It mirrors the pattern used by `3.3.0` and `3.4.0`.

## Required Inputs

| Input | Description | Example |
|-------|-------------|---------|
| **VERSION** | The release version, no `v` prefix | `3.4.0` |
| **Release PR number** | The merged release PR in `microsoft/Docker-Provider` | `1699` |

If VERSION was not provided, read it from `charts/azuremonitor-containerinsights/Chart.yaml` (`version:` field). If the release PR number was not provided, find it with:

```powershell
gh pr list --repo microsoft/Docker-Provider --state merged --base ci_prod `
  --search "<VERSION> Release notes in:title" --json number,title,mergeCommit,state
```

## Step-by-step procedure

### Step 1: Verify the release PR is merged

```powershell
gh pr view <PR_NUM> --repo microsoft/Docker-Provider `
  --json state,baseRefName,mergeCommit,mergedAt
```

Required values:
- `state` must be `MERGED`.
- `baseRefName` must be `ci_prod`.
- `mergeCommit.oid` will be the SHA we tag.

If the PR is not merged, **stop** and tell the user — never tag from an un-merged branch.

### Step 2: Pull the latest tags and confirm the version isn't already tagged

```powershell
git fetch origin --tags 2>&1 | Select-Object -Last 5
git tag -l <VERSION>
```

If `git tag -l <VERSION>` outputs anything, the tag already exists. Stop and confirm with the user — do not silently overwrite.

### Step 3: Confirm the merge commit is reachable from origin/ci_prod

```powershell
git --no-pager log <MERGE_SHA> -1 --oneline
git merge-base --is-ancestor <MERGE_SHA> origin/ci_prod; $LASTEXITCODE
```

The `log` line should match the release PR title (e.g. `3.4.0 Release notes (#1699)`). `$LASTEXITCODE` must be `0` — meaning the commit is on `ci_prod`. If it isn't, stop.

### Step 4: Identify the previous release tag

You will need the previous release tag for the GitHub Release step (Step 7) — it's what GitHub's "auto-generate release notes" uses as the comparison base.

```powershell
git tag -l "3.*" | Sort-Object { [version]$_ } -ErrorAction SilentlyContinue | Select-Object -Last 5
```

Pick the highest non-`<VERSION>` tag — call it `<PREV_VERSION>`. Confirm with the user if there's any ambiguity (e.g. concurrent hotfix branches).

### Step 5: Create the annotated tag

The release convention in this repo is **annotated tags** with the version itself as the message (e.g. `3.1.32`, `3.1.34`, `3.4.0` all have message `"<VERSION>"`). A few historical tags (`3.1.35`, `3.3.0`) are lightweight — those are regressions, do not match them.

```powershell
git tag -a <VERSION> <MERGE_SHA> -m "<VERSION>"
```

`git tag -a` without `-m` opens `$EDITOR`; always pass `-m` so the skill is non-interactive.

### Step 6: Push the tag

Push only the new tag — never `git push --tags` from a worktree, which can leak local-only tags. The form `git push origin tag <VERSION>` is equivalent.

```powershell
git push origin refs/tags/<VERSION> 2>&1 | Select-Object -Last 5
```

Expected output ends with `* [new tag]   <VERSION> -> <VERSION>`.

### Step 7: Draft and publish the GitHub Release

The release tag alone does not produce a GitHub Release entry — that is a separate step. Use the GitHub UI (the `gh release create` CLI works too but the UI flow is what the team uses, and "auto-generate release notes" is more reliable from the UI).

1. Open https://github.com/microsoft/Docker-Provider/releases/new
2. **Choose a tag**: select the `<VERSION>` tag you just pushed.
3. **Previous tag**: change from "auto" to `<PREV_VERSION>` (the previous prod tag, from Step 4).
4. Click **Generate release notes**. GitHub will populate the body from PR titles merged between `<PREV_VERSION>` and `<VERSION>`.
5. **Release title**: `<VERSION>`.
6. Leave "Set as the latest release" checked. Do NOT mark as pre-release.
7. Click **Publish release**.

Verify the result:

```powershell
gh api repos/microsoft/Docker-Provider/git/refs/tags/<VERSION> --jq '{ref, sha: .object.sha, type: .object.type}'
gh release view <VERSION> --repo microsoft/Docker-Provider --json tagName,name,isLatest,publishedAt
```

`object.type` must be `tag` (annotated). `isLatest` must be `true`.

Print to the user:
- Tag name, SHA, and annotation message
- Previous tag used for the diff
- Release URL: `https://github.com/microsoft/Docker-Provider/releases/tag/<VERSION>`
- Reminder: the build/publish pipeline triggers off this tag — confirm with the release owner before walking away.

## Important rules

- **Annotated tags only** (`git tag -a -m "<VERSION>"`). Lightweight tags are a regression — the historical `3.3.0` lightweight tag is what we are correcting away from.
- **Tag message = version string**, nothing else (e.g. `-m "3.4.0"`). Matches `3.1.32`/`3.1.34`/`3.4.0`.
- **No `v` prefix.** Tags are bare versions: `3.4.0`, not `v3.4.0`.
- **Tag the merge commit of the release PR**, never the PR's head commit on the feature branch and never an arbitrary commit on `ci_prod`. The merge commit is reproducible and is what reviewers approved.
- **Never** force-push or move an existing release tag without explicit owner approval. If a tag was created wrong (e.g. lightweight when it should have been annotated), delete-and-recreate is acceptable only **before** downstream pipelines have consumed it — confirm with the release owner first.
- **Never** create the tag from a stale local `ci_prod`. Always `git fetch origin --tags` first.
- **Always** finish with the GitHub Release (Step 7). A pushed tag without a published Release is incomplete — downstream pipelines and consumers expect the Release entry.
