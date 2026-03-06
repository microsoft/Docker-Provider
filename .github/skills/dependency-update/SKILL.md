# Dependency Update

## Purpose
Updates Go module dependencies and Ruby gem versions across the Container Insights agent codebase. Keeps Fluent Bit input/output plugins, Fluentd Ruby plugins, and Ginkgo e2e test dependencies current with security patches and upstream releases.

USE FOR: "update go modules", "bump dependency", "upgrade gem", "update go.sum", "refresh dependencies", "renovate", "dependabot PR"
DO NOT USE FOR: Changing plugin business logic, adding new dependencies for new features, Helm chart version bumps (use infrastructure skill)

## When to Use
- Dependabot or Renovate opens a PR to bump a Go module or Ruby gem
- A CVE is published against a transitive dependency (coordinate with security-patch skill)
- Upstream Fluent Bit, Fluentd, or Azure SDK releases a new version
- Periodic monthly dependency refresh cycle
- `go mod tidy` reports stale or unused modules

## Inputs
- Name and target version of the dependency to update
- Which module(s) are affected (there are multiple independent go.mod files)
- Reason for update (security, compatibility, routine maintenance)

## Outputs
- Updated `go.mod` and `go.sum` files in affected modules
- Updated Gemfile / gemspec if Ruby gems change
- Passing unit tests (`test/unit-tests/run_go_tests.sh`, `test/unit-tests/run_ruby_tests.sh`)
- Passing CI checks (pr-checker.yml, run_unit_tests.yml)
- Clean Trivy scan with no new HIGH/CRITICAL vulnerabilities

## Steps
1. Identify all Go modules that depend on the target package:
   - `source/plugins/go/src/go.mod` — core Fluent Bit output plugins
   - `source/plugins/go/input/go.mod` — Fluent Bit input plugins
   - `test/ginkgo-e2e/livenessprobe/go.mod` — liveness probe e2e tests
   - `test/ginkgo-e2e/utils/go.mod` — e2e test utilities
   - `test/ginkgo-e2e/containerstatus/go.mod` — container status e2e tests
   - `test/ginkgo-e2e/querylogs/go.mod` — log query e2e tests
2. For each affected module, run `go get <package>@<version>` then `go mod tidy`
3. For Ruby gem updates, update the relevant require/version in `source/plugins/ruby/` and run `bundle update` if a Gemfile is present
4. Run Go unit tests: `cd test/unit-tests && bash run_go_tests.sh`
5. Run Ruby unit tests: `cd test/unit-tests && bash run_ruby_tests.sh`
6. Build the Linux container image using `build/linux/Makefile` to verify compilation
7. Run Trivy scan against the built image to check for new vulnerabilities; update `.trivyignore` only if the finding is a false positive with documented justification
8. Update `ReleaseNotes.md` with the dependency version change if it affects a top-level component (Golang, Fluent-bit, Fluentd, Ruby, MDSD, Telegraf)

## Validation
- `go build ./...` succeeds in `source/plugins/go/src/` and `source/plugins/go/input/`
- `make` succeeds in `source/plugins/go/src/Makefile`
- `bash test/unit-tests/run_go_tests.sh` passes
- `bash test/unit-tests/run_ruby_tests.sh` passes
- PR checks pass: pr-checker.yml (includes Trivy scan), run_unit_tests.yml
- No new entries needed in `.trivyignore` (or entries are justified)
- `go mod tidy` produces no diff (modules are clean)

## Risks and Guardrails
- **Multiple go.mod files**: Forgetting to update one module can cause version skew; always grep all `go.mod` files for the dependency
- **Breaking API changes**: Major version bumps in Azure SDK or Fluent Bit Go API may require code changes in `source/plugins/go/`
- **Ruby compatibility**: Fluentd plugins must remain compatible with the Fluentd version pinned in `kubernetes/linux/Dockerfile.multiarch`
- **Trivy exceptions**: Never add blanket ignores to `.trivyignore`; each entry must reference a specific CVE with justification
- **Windows builds**: Go dependency changes can affect the Windows build; verify `kubernetes/windows/Dockerfile` still builds
- **E2E test modules**: The `test/ginkgo-e2e/*/go.mod` files are independent modules; update them in the same PR to keep versions consistent

## Examples from This Repo
- Go module bumps typically touch 2-4 `go.mod`/`go.sum` file pairs in a single commit
- Ruby gem updates are less frequent and usually tied to Fluentd base image upgrades
- Dependency PRs often pair with Trivy scan result updates in `.trivyignore`
- Component version changes are recorded in `ReleaseNotes.md` under the next release heading
