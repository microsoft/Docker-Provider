# Dependency Update

## Description
Update Go modules, Ruby gems, or container base images in the Docker-Provider agent.

USE FOR: update dependency, bump package, upgrade library, update go.mod, update base image, bump fluent-bit, upgrade telegraf
DO NOT USE FOR: adding a brand new dependency, removing a dependency, major framework migration

## Instructions

### When to Apply
When a dependency needs to be updated for security fixes, new features, or version currency. Common triggers include Dependabot alerts, Trivy scan findings, or upstream release announcements.

### Step-by-Step Procedure
1. **Identify the dependency type:**
   - Go modules → modify `go.mod` files in `source/plugins/go/src/` and `source/plugins/go/input/`
   - Ruby gems → modify gem install in `kubernetes/linux/setup.sh`
   - Fluent Bit → update version in build scripts and Dockerfile
   - Telegraf → update version in build scripts
   - Container base image → update `FROM` line in `kubernetes/linux/Dockerfile.multiarch` or `kubernetes/windows/Dockerfile`

2. **Update the dependency:**
   - For Go: `cd source/plugins/go/src && go get <package>@<version> && go mod tidy`
   - Also update any other `go.mod` files that depend on the same package (check `test/ginkgo-e2e/*/go.mod`)
   - For base images: Update the `FROM` tag/digest in the Dockerfile

3. **Build and verify:**
   - `cd source/plugins/go/src && make fbplugin` (Go plugin)
   - `cd source/plugins/go/src && make test` (Go tests)
   - Docker image build to verify no compilation errors

4. **Run vulnerability scan:**
   - Verify the update resolves the targeted CVE/vulnerability
   - Check `.trivyignore` — remove entries for now-fixed CVEs

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/*/go.mod`, `source/plugins/go/input/*/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/linux/setup.sh`
- `.trivyignore`

### Validation
- `go mod tidy` completes without errors
- `make test` passes in `source/plugins/go/src/`
- Docker image builds successfully
- Trivy scan shows no new critical/high CVEs

## Examples from This Repo
- `6f4c31f91` — 3.1.32 CVE fixes
- `733532d7f` — 3.1.31 CVEs fixes
- `090c1dd49` — Upgrade Fluent Bit to 4.0.9
