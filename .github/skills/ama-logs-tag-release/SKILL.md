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

### Step 4: Match the prior release's tag style

Inspect the previous release tag to decide between a lightweight or annotated tag:

```powershell
git for-each-ref refs/tags/<PREV_VERSION> --format='%(objecttype) -> %(*objectname)%(objectname)'
```

- `commit -> <sha>` → lightweight tag (no annotation).
- `tag -> <sha>` → annotated tag.

The current convention in this repo is **lightweight tags** (e.g. `3.3.0`, `3.4.0`). Stay consistent unless the user explicitly asks for an annotated/signed tag.

### Step 5: Create the tag

Lightweight (default — matches existing convention):

```powershell
git tag <VERSION> <MERGE_SHA>
```

Annotated (only if the prior release used `tag -> ...`):

```powershell
git tag -a <VERSION> <MERGE_SHA> -m "Release <VERSION>"
```

### Step 6: Push the tag

Push only the new tag — never `git push --tags` from a worktree, which can leak local-only tags.

```powershell
git push origin refs/tags/<VERSION> 2>&1 | Select-Object -Last 5
```

Expected output ends with `* [new tag]   <VERSION> -> <VERSION>`.

### Step 7: Verify on origin and report

```powershell
gh api repos/microsoft/Docker-Provider/git/refs/tags/<VERSION> --jq '{ref, sha: .object.sha, type: .object.type}'
```

`sha` must equal `<MERGE_SHA>` (or the annotated-tag object pointing to it). Print to the user:
- Tag name and SHA
- Link: `https://github.com/microsoft/Docker-Provider/releases/tag/<VERSION>`
- Reminder: the build/publish pipeline triggers off this tag — confirm with the release owner before walking away.

## Important rules

- **No `v` prefix.** Tags are bare versions: `3.4.0`, not `v3.4.0`.
- **Tag the merge commit of the release PR**, never the PR's head commit on the feature branch and never an arbitrary commit on `ci_prod`. The merge commit is reproducible and is what reviewers approved.
- **Never** force-push or move an existing release tag. If the tag is wrong, talk to the release owner — moving it can break downstream pipelines and consumers who already pulled the prior SHA.
- **Never** create the tag from a stale local `ci_prod`. Always `git fetch origin --tags` first.
- **Never** create a GitHub Release in this skill — publishing/release-notes-on-GitHub is a separate manual step owned by the release manager.
