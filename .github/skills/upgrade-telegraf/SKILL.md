---
name: upgrade-telegraf
description: "Upgrade Telegraf to a new version in the dalec-build-defs repo. Creates a new spec file, updates version/commit/changelog, and prepares a branch for PR. Use when someone says 'upgrade telegraf', 'new telegraf version', 'bump telegraf', or 'update telegraf package'. DO NOT USE FOR: patching existing versions, modifying build targets, or non-telegraf packages."
argument-hint: "[version] — e.g. '1.38.0' or 'latest' to auto-detect from GitHub"
---

# Upgrade Telegraf Version

This skill creates a new DALEC spec file for a new Telegraf release in the `dalec-build-defs` repository.

## Overview

Telegraf specs live at `specs/telegraf-agent/telegraf-agent-<VERSION>.yml`. Each version is a standalone file copied from the latest existing spec with updated version-specific fields.

## Step-by-step procedure

### Step 1: Determine the target version

If the user did NOT provide a specific version, fetch the latest release from GitHub:

```bash
curl -sL https://api.github.com/repos/influxdata/telegraf/releases/latest | jq -r '.tag_name'
```

The tag is in the format `v1.XX.Y`. Strip the leading `v` to get the VERSION (e.g. `1.38.0`).

If the user provided a version, use that directly.

### Step 2: Get the commit SHA for the release tag

```bash
curl -sL https://api.github.com/repos/influxdata/telegraf/git/refs/tags/v<VERSION> | jq -r '.object.sha'
```

**IMPORTANT**: If the tag object type is `"tag"` (annotated tag), you must dereference it to get the actual commit SHA:

```bash
# First get the tag object
TAG_SHA=$(curl -sL https://api.github.com/repos/influxdata/telegraf/git/refs/tags/v<VERSION> | jq -r '.object.sha')
TAG_TYPE=$(curl -sL https://api.github.com/repos/influxdata/telegraf/git/refs/tags/v<VERSION> | jq -r '.object.type')

# If it's an annotated tag, dereference to get the commit
if [ "$TAG_TYPE" = "tag" ]; then
  COMMIT=$(curl -sL https://api.github.com/repos/influxdata/telegraf/git/tags/$TAG_SHA | jq -r '.object.sha')
else
  COMMIT=$TAG_SHA
fi
```

Verify the commit SHA is a full 40-character hex string.

### Step 3: Verify the version doesn't already exist

Check that the file `specs/telegraf-agent/telegraf-agent-<VERSION>.yml` does NOT already exist in the workspace. If it does, inform the user and stop.

### Step 4: Identify the latest existing spec file

Find the latest (highest version) existing spec file in `specs/telegraf-agent/`:

```bash
ls specs/telegraf-agent/telegraf-agent-*.yml | sort -V | tail -1
```

Read this file — it will be used as the template for the new spec.

### Step 5: Create the new spec file

Copy the latest spec and update these fields:

| Field | Old value | New value |
|-------|-----------|-----------|
| `args.VERSION` | old version | `<VERSION>` (e.g. `1.38.0`) |
| `args.COMMIT` | old commit SHA | new commit SHA from Step 2 |
| `args.REVISION` | any value | `"1"` (always reset to 1 for new versions) |
| `tests[].steps[].stdout.contains[]` | old version string | `"<VERSION>"` |
| `changelog` | old entries | **Replace** with a single new entry. Each spec file should only contain a changelog entry for its own version — do NOT carry forward changelog entries from the previous spec file. |

#### Changelog entry format

```yaml
changelog:
  - date: "<TODAY in YYYY-MM-DD format>"
    author: "<git user.name> <<git user.email>>"
    changes:
      - Upgrade telegraf package version to <VERSION>
```

Get the author info from git config:
```bash
GIT_NAME=$(git config user.name)
GIT_EMAIL=$(git config user.email)
```

**Do NOT change any other fields** — keep the same `#syntax` frontend version (copied from the latest existing spec file), build targets, dependencies, build steps, LDFLAGS pattern, artifact paths, test structure, etc.

**NOTE on `#syntax` version**: The `#syntax=ghcr.io/azure/dalec/frontend:X.XX` line changes over time. Do NOT hardcode it. Always copy it verbatim from the latest existing spec file found in Step 4.

### Step 6: Pull latest main, create a git branch and commit

**IMPORTANT**: Always fetch and rebase onto the latest `origin/main` before creating the branch. This ensures the new spec is based on the current state of the repository and avoids conflicts with specs already merged to main.

```bash
git fetch origin main
git checkout main
git rebase origin/main
git checkout -b copilot/upgrade-telegraf-<VERSION>
git add specs/telegraf-agent/telegraf-agent-<VERSION>.yml
git commit -m "Upgrade telegraf package version to <VERSION>"
```

### Step 7: Push branch, create PR

Push the branch and create the PR automatically — no user confirmation needed.

```bash
git push origin copilot/upgrade-telegraf-<VERSION>
```

Create the PR using the GitHub REST API via `curl`. Extract the auth token from the git credential helper:

```bash
TOKEN=$(echo "protocol=https
host=github.com" | git credential fill 2>/dev/null | grep password | cut -d= -f2)
```

Then create the PR:

```bash
curl -s -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/Azure/dalec-build-defs/pulls \
  -d '{
  "title": "Upgrade telegraf package version to <VERSION>",
  "head": "copilot/upgrade-telegraf-<VERSION>",
  "base": "main",
  "body": "<PR_BODY>"
}'
```

**Why not `gh` CLI?** In this environment, `gh` CLI installation requires `sudo` (which may not be available or may block on a password prompt), and even when installed, `gh auth login` fails because the git credential manager token typically lacks the `read:org` scope that `gh` requires. The `curl` approach works reliably with the existing git credentials.

Use the following PR body (with proper JSON escaping — `\n` for newlines, `\\` for backslashes in shell):

```
**What this PR does / why we need it**:
Telegraf upgrade to resolve CVE

**Which issue(s) this PR fixes** *(optional, using `fixes #<issue number>(, fixes #<issue_number>, ...)` format, will close the issue(s) when the PR gets merged)*:

Fixes #

**Checklist**:

- [x] Is this contribution for a third-party (non-Microsoft) open-source CNCF (Cloud Native Computing Foundation) or Kubernetes-related project.
- [x] You are willing to maintain the contributed DALEC specs and update it when necessary.
- [x] Have the corresponding test requirements been met?
  - [x] Are there baseline tests within the test section of the spec(s) that validate the artifact is being built?
  - [x] Is there a test.sh script that performs some level of E2E testing?
  - [x] Are there unit tests for any patches/code changes?
- [ ] In addition to a spec PR for this repo, you will have to submit corresponding PRs for MCR Onboarding for `oss/v2` repository.
  - [ ] [MCR](https://github.com/microsoft/mcr/blob/main/teams/oss/azurecontainerupstream-v2.yml) PR
  - [ ] [mcrdocs](https://github.com/microsoft/mcrdocs/tree/main/teams/oss) PR
- [x] Have you deconflicted the package name with existing packages?
  - [ ] [Azure Linux 3.0 packages](https://github.com/microsoft/azurelinux/tree/3.0/SPECS)
- [x] If these images already exist in [`mcr.microsoft.com/oss`](https://mcr.microsoft.com/en-us/catalog?search=/oss), have you checked the repository and image name is kept the same?
- [x] Have you updated the [CODEOWNERS file](https://github.com/Azure/dalec-build-defs/blob/main/.github/CODEOWNERS)?
- [ ] Have you updated the [upstream_mapping.yml file](https://github.com/Azure/dalec-build-defs/blob/main/upstream_mapping.yml)?

**Special notes for your reviewer**:
```

Parse the PR URL from the JSON response:

```bash
curl ... | jq -r '.html_url'
```

### Step 8: Summary

After all steps, print a summary:
- New file path
- Version and commit SHA used
- Branch name
- PR URL (from `gh pr create` output)

## Reference: Spec file template

Here is the general structure of a telegraf spec file for reference. **The `#syntax` line below is an example only — always copy the actual value from the latest existing spec file (Step 4).**

```yaml
#syntax=ghcr.io/azure/dalec/frontend:<COPY_FROM_LATEST_SPEC>

args:
  VERSION: <VERSION>
  COMMIT: <COMMIT_SHA>
  REVISION: "1"

name: telegraf-agent
packager: Azure Container Upstream
vendor: Microsoft Corporation
license: MIT
website: https://github.com/influxdata/telegraf
description: telegraf
version: ${VERSION}
revision: ${REVISION}
x-build-extensions:
  build-targets:
    - azlinux3/rpm

sources:
  telegraf-agent:
    git:
      url: https://github.com/influxdata/telegraf.git
      commit: ${COMMIT}
    generate:
      - gomod: {}

dependencies:
  build:
    msft-golang:
  runtime:
    openssl-libs:

build:
  env:
    VERSION: ${VERSION}
    COMMIT: ${COMMIT}
    GOPROXY: direct
    GOEXPERIMENT: systemcrypto
    CGO_ENABLED: "1"
    INTERNAL_PKG: github.com/influxdata/telegraf/internal
  steps:
    - command: |
        cd telegraf-agent
        export LDFLAGS="-s -w -X ${INTERNAL_PKG}.Commit=${COMMIT} -X ${INTERNAL_PKG}.Version=${VERSION}-${COMMIT}"
        go build -o telegraf-agent -ldflags "${LDFLAGS}" ./cmd/telegraf

artifacts:
  binaries:
    telegraf-agent/telegraf-agent: {}
  licenses:
    telegraf-agent/LICENSE: {}

tests:
  - name: Check permissions
    files:
      /usr/bin/telegraf-agent:
        permissions: 0755
  - name: Validate telegraf version
    steps:
      - command: /usr/bin/telegraf-agent --version
        stdout:
          contains:
            - "<VERSION>"

changelog:
  - date: "<YYYY-MM-DD>"
    author: "Copilot on behalf of <Name> <<email>>"
    changes:
      - Upgrade telegraf package version to <VERSION>
```

## Important rules

- **REVISION** is always `"1"` for a new version file.
- **Dates** must be ISO 8601 format: `YYYY-MM-DD`.
- **Do NOT** modify any existing spec files.
- **Do NOT** update `index.yml` or `upstream_mapping.yml` — telegraf-agent is not listed there.
- **Do NOT** change build dependencies, build steps, or artifact paths unless the upstream project changed its structure.
- **Always** dereference annotated tags to get the actual commit SHA.
- The `#syntax` frontend version is NOT fixed — always copy it from the latest existing spec file (Step 4). Never hardcode a specific version.
