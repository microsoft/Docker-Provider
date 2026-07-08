---
name: ama-logs-update-charts-release-notes
description: "Prepare an ama-logs release PR: bump the image tag (X.Y.Z) across Helm charts, manifests, and Dockerfiles, and add a formatted ReleaseNotes.md entry. Use when: cutting a new ama-logs release, '3.X.Y release notes', 'bump ciprod image tag', 'release PR for Docker-Provider', creating release notes for a new ciprod build. DO NOT USE FOR: MDSD or Windows AMA bumps in isolation, hotfix patches, or anything that does not increment the ciprod image tag."
argument-hint: "[old version] [new version] — e.g. '3.3.0' '3.4.0'. If omitted, infer old from charts/azuremonitor-containerinsights/Chart.yaml and ask the user for new."
---

# ama-logs Release PR: Chart Bump + Release Notes

This skill prepares a release PR in `microsoft/Docker-Provider` that bumps the ciprod image tag across all Helm charts, Kubernetes manifests, and Dockerfiles, and adds a formatted entry to `ReleaseNotes.md`. It mirrors the structure used by recent release PRs (e.g. #1656 for 3.3.0, #1699 for 3.4.0).

## Required Inputs

| Input | Description | Example |
|-------|-------------|---------|
| **OLD version** | Current ciprod tag (Linux side) | `3.3.0` |
| **NEW version** | Target ciprod tag | `3.4.0` |
| **Release date** | Date for the ReleaseNotes.md heading (today, MM/DD/YYYY) | `05/28/2026` |
| **PRs in scope** | All PRs merged into `ci_prod` since the previous release | (queried below) |

If the user did not provide OLD/NEW, read OLD from `charts/azuremonitor-containerinsights/Chart.yaml` (`version:` field) and ask for NEW.

## Pre-flight: figure out what changed

### Identify the PRs in this release

List every PR merged into `ci_prod` since the previous release's merge commit:

```powershell
# Get the merge commit of the previous release PR (e.g. #1656 for 3.3.0)
gh pr list --repo microsoft/Docker-Provider --state merged --base ci_prod --search "<OLD> release notes in:title" --json number,mergeCommit,mergedAt

# Then list PRs merged after that date
gh pr list --repo microsoft/Docker-Provider --state merged --base ci_prod --search "merged:>=<DATE>" --json number,title,author,mergedAt --limit 100
```

For each PR, capture: number, title, author (`login`), and merged date.

**Author attribution rules:**
- Human authors: use their GitHub login verbatim, prefixed with `@` (e.g. `@zanejohnson-azure`).
- Bot authors: `gh pr view` returns `app/azure-monitor-assistant` — strip the `app/` prefix and write `@azure-monitor-assistant`.

**Title rewriting:** If a PR title is messy (e.g. branch-style `Zane/fix fluentd procstat pattern`), rewrite it to a clean conventional-commit-style title (`fix: fluentd procstat pattern`). Keep clean titles verbatim.

### Classify each PR — Common vs Infra

This is the most error-prone step. Use these rules:

- **Common (Linux + Windows)** — anything that ships *inside* the ciprod image:
  - CVE fixes in gems/packages baked into the image (`erb`, `jwt`, etc.)
  - Go / Telegraf / Fluent-bit / Fluentd / MDSD / Windows AMA upgrades
  - Ruby/plugin code changes (e.g. fluentd config bugs)
- **Infra** — anything that does NOT ship in the image:
  - Pipeline/CI changes (release pipeline, build pipeline, e2e jobs)
  - Helm chart-only fixes that aren't bundled in the image
  - Documentation, test yamls, robot/automation workflows
  - Skill files

When in doubt: "does this change the bits inside `ciprod:<NEW>`?" If yes → Common. If no → Infra.

### Get azurelinux and Ruby versions FROM THE CONTAINER

Do **not** copy these from the previous release entry. Pull the published `ciprod:<OLD>` image (or `ciprod:<NEW>` if it has already been built) and read them out — they may have shifted even if you didn't bump anything explicitly, because `mcr.microsoft.com/azurelinux/base/core:3.0` is a floating base tag.

```powershell
# Docker Desktop must be running. If not:
#   Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
#   Start-Sleep -Seconds 60

docker pull mcr.microsoft.com/azuremonitor/containerinsights/ciprod:<OLD>
docker run --rm --entrypoint cat mcr.microsoft.com/azuremonitor/containerinsights/ciprod:<OLD> /etc/os-release | Select-String '^VERSION='
# => VERSION="3.0.20260517"

docker run --rm --entrypoint ruby mcr.microsoft.com/azuremonitor/containerinsights/ciprod:<OLD> -e "puts RUBY_VERSION"
# => 3.3.10  (x86_64 amalogs; the arm64 build may differ — keep both lines if so)
```

If `ciprod:<NEW>` is already published (CI built it), re-run against `:<NEW>` to confirm nothing shifted.

## File edits — exact list

These eight files **always** change on a release. Do not add or remove files unless the user explicitly asks.

### 1. `charts/azuremonitor-containerinsights/Chart.yaml`
- `version: <OLD>` → `version: <NEW>`
- Leave `appVersion` alone unless the user says otherwise.

### 2. `charts/azuremonitor-containerinsights/values.yaml`
- `imageTagLinux: "<OLD>"` → `"<NEW>"`
- `imageTagWindows: "win-<OLD>"` → `"win-<NEW>"`
- `tag: "<OLD>"` → `"<NEW>"` (inside the `amalogs.image` block)
- `tagWindows: "win-<OLD>"` → `"win-<NEW>"`
- **Do NOT** touch `agentVersion` (MDSD) or `winAgentVersion` (Win AMA) unless those components were actually bumped this cycle.

### 3. `charts/azuremonitor-containers/Chart.yaml`
- `version: <OLD>` → `version: <NEW>`

### 4. `charts/azuremonitor-containers/values.yaml`
- `tag: "<OLD>"` → `"<NEW>"`
- `tagWindows: "win-<OLD>"` → `"win-<NEW>"`

### 5. `charts/azuremonitor-containers-geneva/values.yaml`
- `tag: "<OLD>"` → `"<NEW>"`

### 6. `kubernetes/ama-logs.yaml`
- Replace every `mcr.microsoft.com/azuremonitor/containerinsights/ciprod:<OLD>` with `:<NEW>`.
- Replace every `:win-<OLD>` with `:win-<NEW>`.
- **Include commented-out blocks** — prior release PRs update those too (e.g. the dev/test image comment).
- Do NOT touch `agentVersion:` annotations or RBAC rules unless the user explicitly asked.

### 7. `kubernetes/linux/Dockerfile.multiarch`
- `ARG IMAGE_TAG=<OLD>` → `ARG IMAGE_TAG=<NEW>`

### 8. `kubernetes/windows/Dockerfile`
- `ARG IMAGE_TAG=win-<OLD>` → `ARG IMAGE_TAG=win-<NEW>`

## ReleaseNotes.md entry

Insert at the **top** of the `## Release History` section, immediately below the heading and above the previous release's entry. Follow the exact format of the most recent prior entry. Keep one trailing blank line so entries are visually separated.

```markdown
### <MM/DD/YYYY> -
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:<NEW> (linux)
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-<NEW> (windows)
- Linux
  - [azurelinux <AZL_VERSION>](https://github.com/microsoft/azurelinux/releases/tag/<AZL_VERSION>-3.0)
  - Golang - <GO_VERSION>
  - Ruby - arm64 - <RUBY_ARM64>, x86_64 - <RUBY_X86>
  - MDSD - <MDSD_VERSION>
  - Telegraf - <TELEGRAF_LINUX>
  - Fluent-bit - <FLUENTBIT_LINUX>
  - Fluentd - <FLUENTD>
- Windows
  - Golang - <GO_VERSION>
  - Ruby - <RUBY_WIN>
  - Windows AMA - <WIN_AMA>
  - Telegraf - <TELEGRAF_WIN>
  - Fluent-bit - <FLUENTBIT_WIN>
  - Fluentd - <FLUENTD>
##### Code change log
## What's Changed
- Common (Linux + Windows)
    * <Title> by @<author> in https://github.com/microsoft/Docker-Provider/pull/<num>
    * ...

- Infra
    * <Title> by @<author> in https://github.com/microsoft/Docker-Provider/pull/<num>
    * ...

```

**Formatting rules:**
- One PR per line. If multiple PRs share the same title (e.g. four Go upgrade auto-PRs), still emit one line per PR — do NOT consolidate.
- Always include the full `https://github.com/microsoft/Docker-Provider/pull/<num>` URL — not a markdown link.
- Use a blank line between the `Common` and `Infra` blocks.
- For dependency versions not bumped this cycle, copy the value from the previous entry **but verify against the chart values files and the container** — don't trust the prior entry blindly.

## Verification before commit

Run from the repo root and confirm no stray old-version references remain in files that should have been bumped:

```powershell
git --no-pager diff --stat
git --no-pager grep -n "<OLD>" -- charts kubernetes
git --no-pager grep -n "win-<OLD>" -- charts kubernetes
```

Remaining matches are acceptable **only** in:
- Older `ReleaseNotes.md` entries (anywhere outside the new entry).
- Test fixtures, scripts, or comments that intentionally pin `<OLD>`.

If anything else still references `<OLD>` under `charts/` or `kubernetes/`, fix it before committing.

## Commit, push, PR

**One commit.** Message:

```
<NEW> release notes and chart update

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

Use the auto-created session branch (do not create a new branch manually). Push and open the PR against `ci_prod`:

```powershell
git add charts kubernetes ReleaseNotes.md
git commit -m "<NEW> release notes and chart update`n`nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push 2>&1 | Select-Object -Last 5
```

Open the PR with the `create_pull_request` tool (or `gh pr create`):
- **Title:** `<NEW> Release notes`
- **Base:** `ci_prod`
- **Body:** brief summary mirroring the prior release PR — call out (1) image tag bump `<OLD> → <NEW>` across charts/manifests/Dockerfiles, (2) the release notes entry with dep changes, (3) which components are unchanged this cycle (e.g. MDSD, Windows AMA). Reference the previous release PR as the template.
- **Not** a draft.

## Iteration: moving PRs between sections

Reviewers will often ask to reclassify or rename a PR entry after the initial PR is open. Make one focused commit per move/rename:

```
fix(release-notes): move #<num> <short title> to <Common|Infra> section
```

or

```
fix(release-notes): rename #<num> to "<new title>"
```

Always re-grep the file to make sure each PR appears in exactly one section after the move.

## Important rules

- **Never** invent dependency versions. Pull them from the chart values files or the container.
- **Never** bump MDSD or Windows AMA versions unless the user explicitly says so — they are tracked in `agentVersion` / `winAgentVersion` and are decoupled from the ciprod tag.
- **Never** modify unrelated files (CI yamls, source code, RBAC rules) inside this skill's PR. Other PRs already in the release brought those changes — this PR is *only* the tag bump and the notes.
- **Never** mark the PR as draft.
- Keep edits idempotent: re-running the skill against the same OLD/NEW must not produce a second diff.
