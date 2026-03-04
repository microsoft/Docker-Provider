# Agentify This Repository — Declarative Agent Prompt

You are a staff level developer. Your task is to analyze this repository and generate a complete set of "agent artifacts" that will enable AI coding assistants (like GitHub Copilot, Google Jules, Gemini CLI, etc.) to understand and contribute to this codebase effectively.

No code installation, no CLI tool, no API keys required — the coding agent IS the tool.

---

## Goal

Analyze this repository's codebase, structure, conventions, CI/CD configuration, and **git commit history (last 12 months)** to auto-generate the following files that make this repo "agent-ready" for AI coding assistants:

| Output File | Standard | Where |
|-------------|----------|-------|
| `copilot-instructions.md` | GitHub official | `.github/copilot-instructions.md` (GitHub) or root (other SCMs) |
| `AGENTS.md` | Open standard (AAIF / Linux Foundation) | Root (+ nested per subproject for monorepos) |
| `.instructions.md` files | GitHub official | `.github/instructions/` (GitHub only) |
| `Prompt.md` | Workspace convention | Root |
| `SKILL.md` files | Azure extension pattern | `.agents/skills/<name>/SKILL.md` |
| `CodeReviewer.agent.md` | Custom | `.github/agents/CodeReviewer.agent.md` (GitHub) or root (other SCMs) |
| `DocumentWriter.agent.md` | Custom | `.github/agents/DocumentWriter.agent.md` (GitHub) or root (other SCMs) |

---

## Execution Plan

Complete these phases IN ORDER. Do not skip phases. Do not hallucinate — every command, path, and pattern you reference MUST actually exist in this repo.

### Phase 1 — Detect SCM Provider

Determine which source control host this repo uses:

1. Read `.git/config` and extract the remote `url` value.
2. Match the URL against known providers:
   - `github.com` or `github.dev` → **GitHub**
   - `dev.azure.com` or `visualstudio.com` → **Azure DevOps**
   - `gitlab.com` → **GitLab**
   - `bitbucket.org` → **Bitbucket**
   - No `.git/` directory or unrecognized remote → **Unknown**
3. Cross-check with provider-specific files (`.github/`, `azure-pipelines.yml`, `.gitlab-ci.yml`).
4. Record the provider — it determines file placement and which files to generate.

**SCM Adaptation Matrix:**

| File | GitHub | Azure DevOps | GitLab / Other |
|------|--------|-------------|----------------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Root `copilot-instructions.md` | Root `copilot-instructions.md` |
| `.instructions.md` files | `.github/instructions/*.instructions.md` | **Skip** (not supported) | **Skip** |
| `AGENTS.md` | Root + nested for monorepos | Root + nested for monorepos | Root + nested for monorepos |
| `Prompt.md` | Root | Root | Root |
| Skill files | `.agents/skills/` | `.agents/skills/` | `.agents/skills/` |
| `CodeReviewer.agent.md` | `.github/agents/CodeReviewer.agent.md` | Root `CodeReviewer.agent.md` | Root `CodeReviewer.agent.md` |
| `DocumentWriter.agent.md` | `.github/agents/DocumentWriter.agent.md` | Root `DocumentWriter.agent.md` | Root `DocumentWriter.agent.md` |

---

### Phase 2 — Scan Repository Structure

Analyze the codebase to build a mental model of the repo. Collect ALL of the following:

#### 2.1 Languages & Percentages

Walk the file tree (**excluding** `.git`, `node_modules`, `__pycache__`, `venv`, `.venv`, `dist`, `build`, `vendor`, `.tox`, `.eggs`, `*.egg-info`). Map file extensions to languages and compute percentages:

- `.py` → Python, `.ts`/`.tsx` → TypeScript, `.js`/`.jsx` → JavaScript, `.java` → Java, `.go` → Go, `.rs` → Rust, `.cs` → C#, `.rb` → Ruby, `.php` → PHP, `.swift` → Swift, `.kt` → Kotlin, `.cpp`/`.cc`/`.h` → C++, `.c` → C, `.sh` → Shell, `.sql` → SQL

Report top languages with file counts.

#### 2.2 Frameworks & Libraries

Parse dependency/build files to identify frameworks:

| File | What to Extract |
|------|----------------|
| `requirements.txt`, `pyproject.toml`, `setup.py`, `Pipfile` | Python packages — look for Django, Flask, FastAPI, agent-framework, copilot-sdk, pytest, etc. |
| `package.json` | Node packages — look for React, Next.js, Vue, Angular, Express, Jest, Vitest, etc. |
| `pom.xml`, `build.gradle`, `build.gradle.kts` | Java/Kotlin — Spring Boot, Quarkus, JUnit, TestNG, etc. |
| `go.mod` | Go modules — gin, echo, fiber, etc. |
| `Cargo.toml` | Rust crates — actix, tokio, serde, etc. |
| `*.csproj`, `*.sln`, `Directory.Build.props` | .NET — ASP.NET Core, xUnit, NUnit, etc. |
| `Gemfile` | Ruby — Rails, RSpec, Sinatra, etc. |
| `composer.json` | PHP — Laravel, Symfony, PHPUnit, etc. |

Record framework name + version constraint for each.

#### 2.3 Build Systems & CI/CD

Identify build configuration:

- **Build files:** `Makefile`, `Dockerfile`, `docker-compose.yml`, `Taskfile.yml`, `justfile`, `Earthfile`
- **CI/CD configs and extract build/test/lint commands from them:**
  - `.github/workflows/*.yml` (GitHub Actions)
  - `azure-pipelines.yml` or `.azure-pipelines/` (Azure Pipelines)
  - `.gitlab-ci.yml` (GitLab CI)
  - `Jenkinsfile` (Jenkins)
  - `.circleci/config.yml` (CircleCI)
  - `bitbucket-pipelines.yml` (Bitbucket)
- **Package manager scripts:** `package.json` `scripts` block, `Makefile` targets, `pyproject.toml` `[tool.taskipy]` or `[project.scripts]`

Extract the exact commands for: **install/bootstrap**, **build**, **test**, **lint/format**, **run/start**.

#### 2.4 Directory Structure

Compute a depth-limited tree (max 4 levels). Identify standard patterns:

- `src/`, `lib/`, `app/`, `pkg/` → source code
- `test/`, `tests/`, `spec/`, `__tests__/` → test code
- `docs/`, `doc/` → documentation
- `config/`, `conf/`, `settings/` → configuration
- `scripts/`, `tools/`, `bin/` → utilities
- `infra/`, `infrastructure/`, `deploy/`, `k8s/`, `terraform/`, `bicep/` → infrastructure
- `.github/`, `.azure-pipelines/` → CI/CD

#### 2.5 Monorepo Detection

Check for monorepo indicators:

- Multiple `package.json` files at different depths
- `pnpm-workspace.yaml`, `lerna.json`, `nx.json`, `turbo.json`
- Multiple `requirements.txt` or `pyproject.toml` at different paths
- Cargo workspace (`[workspace]` in root `Cargo.toml`)
- Multiple `go.mod` files
- `*.sln` referencing multiple `*.csproj`

If monorepo: identify each subproject's path, languages, and frameworks.

#### 2.6 Testing Patterns

- Detect test frameworks from dependencies (pytest, jest, mocha, vitest, JUnit, go test, xUnit, RSpec, PHPUnit)
- Identify test file locations and naming conventions (`test_*.py`, `*.test.ts`, `*_test.go`, `*Test.java`)
- Extract test commands from CI config or package manager scripts

#### 2.7 Code Conventions (sample up to 5 files per language)

- Naming: `snake_case` vs `camelCase` vs `PascalCase`
- Import style: absolute vs relative, grouped vs ungrouped
- Type annotations: present or absent
- Docstrings/comments: style and density
- Error handling patterns
- Logging patterns

#### 2.8 Entry Points

- `main()` functions, `if __name__ == "__main__"` blocks
- `package.json` `main`/`bin` fields
- Dockerfile `CMD`/`ENTRYPOINT`
- Startup scripts (`startup.sh`, `entrypoint.sh`)

#### 2.9 Existing Agent/Copilot Files

Check what already exists: `.github/copilot-instructions.md`, `AGENTS.md`, `.github/instructions/`, `Prompt.md`, `DESIGN.md`, `.agents/`, `CodeReviewer.agent.md` (or `.github/agents/CodeReviewer.agent.md`), `DocumentWriter.agent.md` (or `.github/agents/DocumentWriter.agent.md`). Report what's present and what's missing.

#### 2.10 Linter, Formatter & Static Analysis Configs

Search the repo for tool configuration files that define enforceable code quality rules. These are the **authoritative source** for code review criteria — more reliable than sampling code manually.

| Config File | Tool | Language |
|-------------|------|----------|
| `.eslintrc`, `.eslintrc.js`, `.eslintrc.json`, `.eslintrc.yml`, `eslint.config.js` | ESLint | JavaScript/TypeScript |
| `.prettierrc`, `prettier.config.js` | Prettier | JS/TS/CSS/Markdown |
| `.rubocop.yml` | RuboCop | Ruby |
| `.pylintrc`, `.flake8`, `pyproject.toml` `[tool.pylint]`/`[tool.ruff]`/`[tool.flake8]` | Pylint/Flake8/Ruff | Python |
| `mypy.ini`, `pyproject.toml` `[tool.mypy]` | mypy | Python |
| `.golangci.yml`, `.golangci.yaml` | golangci-lint | Go |
| `rustfmt.toml`, `.rustfmt.toml` | rustfmt | Rust |
| `clippy.toml`, `.clippy.toml` | Clippy | Rust |
| `.editorconfig` | EditorConfig | All languages |
| `.clang-format`, `.clang-tidy` | clang-format/clang-tidy | C/C++ |
| `checkstyle.xml`, `pmd.xml` | Checkstyle/PMD | Java |
| `.luacheckrc` | Luacheck | Lua |
| `shellcheck` directives in scripts, `.shellcheckrc` | ShellCheck | Shell/Bash |

For each config found:
1. **Parse the rules** — extract severity levels, disabled rules, custom rule overrides.
2. **Identify enforced patterns** — what the team has explicitly chosen to enforce (these become review checklist items).
3. **Identify suppressed rules** — what the team has intentionally disabled (do NOT flag these in reviews).
4. **Record CI integration** — is this tool run in CI? If so, the review can defer to automation for those checks.

#### 2.11 Security Posture & Tooling

Scan the repo for security-related configurations, tools, and patterns. This data feeds directly into the CodeReviewer's STRIDE-based security checks and the `security-review` skill.

**Security tool configs to detect:**

| Config / File | Tool | Purpose |
|---------------|------|--------|
| `.trivyignore`, `trivy.yaml` | Trivy | Container/dependency vulnerability scanning |
| `.snyk`, `.snyk.d/` | Snyk | Dependency vulnerability scanning |
| `dependabot.yml` / `renovate.json` | Dependabot/Renovate | Automated dependency updates |
| `.gitleaks.toml` | Gitleaks | Secret/credential leak detection |
| `.secretlintrc.json` | Secretlint | Secret detection |
| `.pre-commit-config.yaml` | pre-commit | Pre-commit hooks (often includes secret scanners) |
| `codeql-analysis.yml` or `codeql/` | CodeQL | Static analysis / SAST |
| `devskim.json`, `.devskim/` | DevSkim | Security pattern matching |
| `bandit.yaml`, `.bandit` | Bandit | Python security linter |
| `gosec` config in `.golangci.yml` | gosec | Go security linter |
| `brakeman.yml` | Brakeman | Ruby/Rails security scanner |
| `semgrep.yml`, `.semgrep/` | Semgrep | Multi-language SAST |
| `SECURITY.md` | Convention | Security policy / responsible disclosure |
| `security/`, `certs/`, `tls/` | Convention | Security-related code directories |

**Security patterns to identify in source code (sample up to 10 files):**

1. **Authentication/authorization patterns** — How does the codebase handle authn/authz? (OAuth, JWT, mTLS, RBAC, service accounts)
2. **Secret management** — Are secrets loaded from env vars, Key Vault, config files? Look for `os.Getenv`, `ENV[]`, `process.env`, Key Vault SDK usage.
3. **Input validation** — Are there validation/sanitization libraries in use? Where are trust boundaries?
4. **Cryptography usage** — Any hashing, encryption, TLS configuration? Note algorithms used.
5. **Network exposure** — Exposed ports in Dockerfiles, ingress configs, API endpoints.
6. **Privilege levels** — Container security context, `USER` directives in Dockerfiles, file permissions in scripts.

---

### Phase 3 — Analyze Git Commit History (Last 12 months)

Run `git log` to analyze the last 12 months of commit history. This data drives **skill file generation**.

```bash
git log --since="12 months ago" --pretty=format:"%h|%s|%an|%ad" --date=short
```

Also get file-level change stats:

```bash
git log --since="12 months ago" --pretty=format:"%h|%s" --stat --diff-filter=AMRD
```

From the commit history, identify **recurring development patterns** by categorizing commits:

#### 3.1 Pattern Categories to Detect

| Pattern | Commit Signal | Skill Name |
|---------|--------------|------------|
| **Dependency Updates** | Commits touching `requirements.txt`, `package.json`, `pom.xml`, `go.mod`, `Cargo.toml`, `*.csproj`; messages matching `bump`, `update`, `upgrade`, `dependabot`, `renovate` | `dependency-update` |
| **Adding Tests for Features** | Commits that add both a source file and a corresponding test file (e.g., `foo.py` + `test_foo.py`); messages matching `add test`, `test for`, `coverage` | `test-authoring` |
| **Bug Fixes** | Messages matching `fix`, `bugfix`, `hotfix`, `patch`, `resolve`; touching existing source files without new files | `bug-fix` |
| **New Feature Development** | Commits adding new source files + updating route/config/schema files; messages matching `feat`, `feature`, `add`, `implement` | `feature-development` |
| **Refactoring** | Messages matching `refactor`, `restructure`, `rename`, `extract`, `move`; modifying many files without adding new ones | `code-refactoring` |
| **Documentation Updates** | Commits touching only `.md`, `docs/`, `README`, `CHANGELOG`; messages matching `doc`, `readme`, `changelog` | `documentation` |
| **CI/CD Changes** | Commits touching `.github/workflows/`, `azure-pipelines.yml`, `.gitlab-ci.yml`, `Dockerfile`, `docker-compose.yml` | `ci-cd-pipeline` |
| **Configuration & Infrastructure** | Commits touching `*.bicep`, `*.tf`, `k8s/`, `helm/`, `chart/`, config files | `infrastructure` |
| **Database Migrations** | Commits touching `migrations/`, `alembic/`, files matching `*migration*`, `*schema*` | `database-migration` |
| **API Changes** | Commits touching route files, API schemas, OpenAPI specs, GraphQL schemas | `api-development` |
| **Security Fixes** | Messages matching `security`, `CVE`, `vulnerability`, `auth`; touching auth/security files | `security-patch` |
| **Performance Optimization** | Messages matching `perf`, `optimize`, `cache`, `speed`, `latency` | `performance-optimization` |

#### 3.2 Pattern Analysis Method

For each detected pattern:
1. **Count** how many commits match (minimum 3 commits in 12 months to qualify as a skill).
2. **Extract** the specific files, directories, and commands involved.
3. **Identify** the typical workflow: what files are touched together, what tests should be run, what CI checks matter.
4. **Note** any team conventions: commit message format, branch naming, review requirements.

#### 3.3 Frequency-Based Prioritization

Rank patterns by commit frequency. Generate skill files only for patterns with ≥ 3 occurrences. Order skills from most to least frequent.

#### 3.4 PR Review Feedback Analysis (Last 12 Months)

Analyze pull request review comments to identify **what reviewers repeatedly flag**. This data directly feeds the CodeReviewer agent's language-specific best practices and common issues sections.

**For GitHub repos**, use the `gh` CLI:

```bash
# List merged PRs from the last 12 months
gh pr list --state merged --limit 100 --json number,title,createdAt,mergedAt,changedFiles

# For each PR with review comments, extract review feedback
gh pr view <number> --json reviews,reviewRequests,comments

# Get review comments (the richest signal for review patterns)
gh api repos/{owner}/{repo}/pulls/comments --paginate --jq '.[] | select(.created_at > "<12-months-ago>") | {body: .body, path: .path, diff_hunk: .diff_hunk}'
```

**For Azure DevOps repos**, use the `az` CLI:

```bash
az repos pr list --status completed --top 100 --output json
az repos pr reviewer list --id <pr-id>
```

**For repos without CLI access**, fall back to analyzing commit patterns:
- Commits with `fixup!`, `squash!`, or amended messages suggest reviewer-requested changes.
- Commits immediately following a merge that touch the same files suggest post-review fixes.
- Force-push patterns in branch history indicate review iterations.

**From the review comments, extract:**

1. **Recurring feedback themes** — Group comments by category:
   - Style/formatting issues (naming, imports, whitespace)
   - Missing tests or insufficient test coverage
   - Error handling gaps
   - Security concerns (secrets, input validation)
   - Performance concerns (N+1 queries, memory leaks, unnecessary allocations)
   - Documentation gaps (missing docstrings, unclear comments)
   - Logic errors or edge cases
   - API design issues (breaking changes, inconsistent patterns)

2. **Language-specific review patterns** — For each detected language, identify what reviewers focus on:
   - **Go**: error handling (`if err != nil`), goroutine leaks, context propagation, interface compliance
   - **Python**: type hints, exception handling specificity, f-string vs format, async patterns
   - **Ruby**: frozen string literal, method visibility, block vs proc, idiomatic patterns
   - **TypeScript/JavaScript**: strict typing, null checks, async/await vs promises, import hygiene
   - **Shell/Bash**: quoting, `set -e` usage, portability, shellcheck compliance
   - **Java**: null safety, resource management (try-with-resources), generics, exception hierarchy
   - **C#**: nullable reference types, IDisposable, async patterns, LINQ usage
   - **Rust**: ownership patterns, unwrap avoidance, error type design, lifetime annotations

3. **Top-N issues by frequency** — Rank the most commonly flagged issues. The top 10 become the CodeReviewer agent's priority checklist items.

4. **Reviewer personas** — Identify if different reviewers focus on different aspects (e.g., one reviewer focuses on security, another on performance). This informs review scope.

---

### Phase 4 — Generate Output Files

Now generate each file using the data collected in Phases 1–3. Follow the exact format specifications below.

---

## Output File Specifications

### File 1: `copilot-instructions.md`

**Location:** `.github/copilot-instructions.md` (GitHub) or root `copilot-instructions.md` (other SCMs).

**Constraint:** Keep to ≤ 2 pages (~4000 characters). Be concise and specific.

**Format:**

```markdown
# Repository Instructions

## Summary
<!-- One paragraph: what this repo is, primary languages, frameworks, runtime requirements -->

## Build Instructions
<!-- EXACT commands to bootstrap, build, test, lint, and run. Include prerequisites and versions.
     Every command must actually work in this repo. -->

## Project Layout
<!-- Top-level directories and their purposes. Key config files and where to find them. -->

## Validation Steps
<!-- CI/CD workflows the agent should replicate locally before pushing.
     Pre-commit hooks, required checks, formatting gates. -->

## Known Patterns & Gotchas
<!-- Build quirks, timing-sensitive commands, required env setup, common pitfalls.
     Things that would trip up someone (or an agent) new to this repo. -->
```

**Rules:**
- Every command you list MUST exist in the repo (verify against CI config, package.json scripts, Makefile targets).
- Every path you reference MUST exist in the directory tree.
- Do NOT include generic advice — only repo-specific facts.
- Do NOT include credentials, secrets, or connection strings.

---

### File 2: `AGENTS.md`

**Location:** Root of the repository.

**Standard:** [AGENTS.md open standard](https://agents-md.org/) — supported by GitHub Copilot, Codex CLI, Google Jules, Gemini CLI, Cursor, Amp, RooCode, Zed, Factory, and 60k+ open-source projects.

**Format:**

```markdown
# AGENTS.md

## Setup Commands
<!-- Step-by-step commands to get a working dev environment from a fresh clone.
     Include: install dependencies, create env files, start services, seed data. -->

## Code Style
<!-- Language-specific conventions ACTUALLY used in this repo (detected from code samples).
     Naming conventions, import ordering, type annotation policy, formatter/linter config. -->

## Testing Instructions
<!-- Test framework, exact command to run tests, expected behavior.
     Where test files live, naming convention, how to add a new test.
     CI test plan and required coverage thresholds if any. -->

## Dev Environment Tips
<!-- Editor config, recommended extensions, env var setup, debugging instructions.
     Local service dependencies (databases, queues, etc.). -->

## PR Instructions
<!-- Commit message format, branch naming convention, required checks.
     Review expectations, merge strategy, changelog requirements. -->
```

**For monorepos:** Generate a root `AGENTS.md` covering repo-wide conventions, PLUS a nested `AGENTS.md` inside each subproject directory with project-specific instructions. Nested files inherit from root (nearest-file-wins).

**Rules:**
- Setup Commands must produce a working environment when followed literally.
- Code Style must reflect what the code ACTUALLY does, not generic best practices.
- Testing Instructions must include the exact test command that CI runs.

---

### File 3: `.github/instructions/*.instructions.md` (GitHub repos only)

**Skip this file entirely for Azure DevOps, GitLab, Bitbucket, or unknown SCMs.**

Generate one file per detected language/framework. Name the file after the language or framework (e.g., `python.instructions.md`, `typescript-react.instructions.md`).

**Format:**

```markdown
---
applyTo: "<glob pattern>"
---

<!-- Concise, actionable coding rules for this language/framework in THIS repo.
     5-15 bullet points. Derived from actual code conventions detected in Phase 2. -->
```

**Frontmatter fields:**
- `applyTo` (required): glob pattern — `"**/*.py"`, `"**/*.ts,**/*.tsx"`, `"src/**/*.java"`, etc.

**Examples of what to include:**
- Type annotation policy (e.g., "Use type hints on all function signatures")
- Import ordering convention
- Error handling pattern used in this repo
- Naming convention for files, classes, functions, variables
- Test file naming and placement convention
- Framework-specific patterns (e.g., "Use async/await for all endpoint handlers")
- Logging conventions

**Rules:**
- Each rule must be observable in the existing codebase.
- Do NOT include generic language best practices unless the repo actually follows them.
- Keep each file to 5–15 rules.

---

### File 4: `Prompt.md`

**Location:** Root of the repository.

**Purpose:** A reusable task-spec template that any developer (or agent) can use to describe new work in this repo.

**Format:**

```markdown
# <Project Name>

<One-paragraph high-level description of what this project is>

## Tech Stack

| Component | Technology |
|-----------|------------|
<!-- Populated from Phase 2 scan data -->

## Architecture Overview
<!-- Brief description of how the codebase is structured, key modules, data flow -->

## Functional Requirements
### 1) <Requirement description>
### 2) <Requirement description>

## Non-Functional Requirements
<!-- Performance, security, observability, deployment requirements detected from the repo -->

## Expected Project Files
<!-- Key files and their purposes, based on actual directory structure -->

## Environment Variables
<!-- List env vars found in .env.example, .env.template, config files, CI configs.
     Do NOT include actual secret values — only variable names and descriptions. -->

## Acceptance Criteria
<!-- Derived from CI checks, test requirements, linting rules -->
```

---

### File 5: `.agents/skills/<name>/SKILL.md` — Commit-History-Driven Skills

**Location:** `.agents/skills/<skill-name>/SKILL.md`

Generate skill files ONLY for patterns detected in Phase 3 (git commit history analysis) with **≥ 3 occurrences in the last 12 months**.

**Format for each skill:**

```markdown
# <Skill Name>

## Description
<What this skill helps the agent do, derived from the commit pattern>

USE FOR: <comma-separated trigger phrases that should activate this skill>
DO NOT USE FOR: <anti-patterns — tasks that sound similar but should NOT use this skill>

## Instructions

### When to Apply
<Conditions under which this pattern is used in this repo>

### Step-by-Step Procedure
1. <Step based on actual workflow observed in commits>
2. <Step>
3. ...

### Files Typically Involved
<!-- List the specific files/directories that commits in this pattern touch -->

### Validation
<!-- How to verify the change is correct — test commands, CI checks, review criteria -->

## Examples from This Repo
<!-- Reference 2-3 actual commit messages/SHAs that demonstrate this pattern -->

## References
<!-- Links to relevant docs, style guides, or related files in this repo -->
```

#### Required Skill Definitions (generate if pattern detected)

**`dependency-update` — Updating packages/dependencies:**

```
USE FOR: update dependency, bump package, upgrade library, renovate, dependabot, update requirements, update package.json
DO NOT USE FOR: adding a brand new dependency, removing a dependency, major version migration

Instructions should cover:
- Which dependency files to modify (specific to this repo)
- How to run install/lock after changes
- What tests to run to verify nothing broke
- CI checks that validate dependency changes
- Whether lockfiles should be committed
```

**`test-authoring` — Adding tests for new code:**

```
USE FOR: add test, write test, test coverage, test for feature, add unit test, add integration test
DO NOT USE FOR: fixing a flaky test, refactoring tests, test infrastructure changes

Instructions should cover:
- Test framework and config used in this repo
- File naming convention (test_*.py, *.test.ts, etc.)
- Where test files should be placed (relative to source)
- How to run tests locally
- Coverage requirements if any
- Common test patterns/fixtures used in this repo (detected from existing tests)
```

**`bug-fix` — Fixing bugs:**

```
USE FOR: fix bug, resolve issue, patch, hotfix, debug, error fix
DO NOT USE FOR: feature development, refactoring, performance optimization

Instructions should cover:
- How to reproduce issues in this repo's environment
- Testing expectations (must add regression test)
- Commit message format for fixes
- Related CI checks
```

**`feature-development` — Adding new features:**

```
USE FOR: add feature, implement, new endpoint, new component, new module, create
DO NOT USE FOR: bug fixes, refactoring, documentation only changes

Instructions should cover:
- File placement conventions (where new modules go)
- Required accompanying files (tests, docs, schemas)
- Configuration/registration steps (routes, providers, plugins)
- PR checklist for new features
```

**`code-refactoring` — Refactoring existing code:**

```
USE FOR: refactor, restructure, rename, extract method, move file, simplify, clean up
DO NOT USE FOR: adding features, changing behavior, fixing bugs

Instructions should cover:
- How to verify behavior is preserved (test commands)
- Import/reference update procedure
- When to split into multiple commits
```

Generate additional skills for any other patterns found with ≥ 3 occurrences:
- `ci-cd-pipeline` — modifying CI/CD workflows
- `documentation` — updating docs and READMEs
- `infrastructure` — changing IaC, Dockerfiles, Helm charts
- `database-migration` — schema changes and migrations
- `api-development` — API endpoint changes
- `security-patch` — security-related fixes
- `performance-optimization` — speed/memory improvements

#### Always-Generated Skill: `security-review`

Unlike other skills that require ≥ 3 commit occurrences, the `security-review` skill is **always generated** because security review is a universal requirement regardless of commit history.

**`security-review` — STRIDE-Based Security Review:**

```
USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit, hardening review, attack surface review
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

Instructions should cover:

1. STRIDE Threat Model Checklist — Apply to every PR that modifies:
   - Authentication/authorization logic
   - Network-facing code (API endpoints, listeners, ingress)
   - Data handling (parsing, serialization, storage)
   - Infrastructure (Dockerfiles, Helm charts, Terraform, scripts)
   - Dependency changes

   For each STRIDE category, check:

   **Spoofing (Identity)**
   - Are authentication checks present at all entry points?
   - Are tokens/credentials validated before use (not just checked for presence)?
   - Is there protection against token replay or session hijacking?
   - Are service-to-service calls authenticated (mTLS, service accounts, managed identity)?

   **Tampering (Data Integrity)**
   - Is input validated and sanitized at trust boundaries?
   - Are checksums or signatures verified for external data (downloads, API responses, configs)?
   - Are file permissions restrictive (no world-writable files)?
   - Is data integrity maintained in transit (TLS) and at rest (encryption)?

   **Repudiation (Auditability)**
   - Are security-relevant actions logged (auth attempts, permission changes, data access)?
   - Do logs include sufficient context (who, what, when) without leaking sensitive data?
   - Are audit logs tamper-resistant (append-only, shipped to external system)?

   **Information Disclosure (Confidentiality)**
   - No hardcoded secrets, API keys, tokens, passwords, or connection strings in code.
   - No secrets in log output, error messages, or stack traces.
   - Are env vars used for secrets (not config files committed to repo)?
   - Is sensitive data masked in logs (`***`, `[REDACTED]`)?
   - Are debug endpoints or verbose error responses disabled in production configs?
   - Are TLS certificates and private keys excluded from the repo (check .gitignore)?

   **Denial of Service (Availability)**
   - Are there resource limits (timeouts, max payload sizes, rate limiting)?
   - Are unbounded loops or recursive calls protected against pathological input?
   - Are goroutines/threads bounded (no goroutine leaks, thread pool limits)?
   - Are container resource limits set (CPU/memory limits in k8s manifests, Dockerfiles)?

   **Elevation of Privilege (Authorization)**
   - Is authorization checked at the correct granularity (not just "is authenticated")?
   - Are containers running as non-root (USER directive in Dockerfile)?
   - Are RBAC roles following least-privilege principle?
   - Are privileged operations (exec, mount, hostNetwork) justified and documented?
   - Are security contexts set in Kubernetes manifests (readOnlyRootFilesystem, drop capabilities)?

2. Credential & Secret Leak Detection — Scan every changed file for:
   - Hardcoded strings matching secret patterns:
     - API keys: patterns like `AKIA[0-9A-Z]{16}` (AWS), `AIza[0-9A-Za-z\-_]{35}` (GCP), hex strings > 32 chars
     - Connection strings: `Server=...;Password=...`, `mongodb://...@...`, `postgres://...:...@`
     - Tokens: `Bearer <token>`, `ghp_`, `gho_`, `github_pat_`, `xoxb-`, `xoxp-`
     - Private keys: `-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----`
     - Passwords in config: `password=`, `passwd=`, `secret=`, `api_key=` followed by non-variable values
   - Secrets in test fixtures or example configs (even test secrets can leak)
   - `.env` files or secret configs that should be in `.gitignore`
   - Base64-encoded blobs that decode to credentials

3. Weak Security Patterns — Flag these anti-patterns per language:

   **All Languages:**
   - Disabled TLS verification (`InsecureSkipVerify`, `verify=False`, `NODE_TLS_REJECT_UNAUTHORIZED=0`)
   - Weak crypto algorithms (MD5, SHA1 for security purposes, DES, RC4)
   - Hardcoded IP addresses or hostnames (should be configurable)
   - Broad file permissions (0777, 0666, world-readable)
   - Empty catch/except blocks that swallow security errors
   - HTTP instead of HTTPS in production URLs

   **Go:**
   - `#nosec` annotations — verify each is justified with a comment explaining why
   - Unchecked `err` returns from security-sensitive functions (crypto, auth, TLS)
   - Using `fmt.Sprintf` to build SQL queries (SQL injection)
   - `exec.Command` with unsanitized user input (command injection)

   **Python:**
   - `eval()`, `exec()`, `__import__()` with user input
   - `pickle.loads()` on untrusted data (deserialization attack)
   - `subprocess.shell=True` with user input
   - SQL string formatting instead of parameterized queries
   - `assert` used for security checks (stripped in optimized mode)

   **Ruby:**
   - `eval`, `send`, `public_send` with user-controlled input
   - `system()`, backtick execution with unsanitized input
   - `YAML.load` instead of `YAML.safe_load` (deserialization)
   - Mass assignment without strong parameters

   **Shell/Bash:**
   - Unquoted variables in commands (injection risk)
   - `curl | sh` or `curl | bash` patterns
   - `chmod 777` or overly permissive permissions
   - Secrets passed as command-line arguments (visible in process list)
   - Missing `set -e` allowing silent failures in security-critical scripts

   **TypeScript/JavaScript:**
   - `innerHTML` with user input (XSS)
   - `eval()`, `Function()` constructor with dynamic input
   - `child_process.exec` with unsanitized input
   - Disabled CORS restrictions or `Access-Control-Allow-Origin: *`

   **Infrastructure (Dockerfiles, k8s, Helm):**
   - Running as root without justification
   - Using `latest` tags (non-reproducible builds)
   - Secrets in ENV instead of mounted secrets
   - Privileged containers or hostNetwork without justification
   - Missing security contexts (readOnlyRootFilesystem, runAsNonRoot)
   - Exposed ports that should be internal-only

4. CI Security Integration — Verify:
   - Are SAST tools (CodeQL, Semgrep, DevSkim) running in CI? (Phase 2.11)
   - Are dependency scanners (Trivy, Snyk, Dependabot) configured? (Phase 2.11)
   - Are secret scanners (Gitleaks, detect-secrets) in pre-commit or CI?
   - If tools are missing, recommend their addition in the review.

Validation:
- Run existing security CI checks (CodeQL, Trivy, DevSkim from Phase 2.11)
- Verify .gitignore excludes secret files (*.pem, *.key, .env)
- Confirm SECURITY.md exists and describes responsible disclosure
```

---

### File 6: `CodeReviewer.agent.md`

**Location:** `.github/agents/CodeReviewer.agent.md` (GitHub) or root `CodeReviewer.agent.md` (other SCMs).

**Purpose:** A custom agent definition that enables AI assistants to perform structured code reviews following this repo's conventions, CI checks, and quality standards.

**Format:**

```markdown
# CodeReviewer Agent

## Description
You are a code reviewer for this repository. Your job is to review pull requests and code changes for correctness, style, security, and adherence to project conventions.

## Scope
<!-- Define what this reviewer focuses on and what it should skip -->
- File types and directories to review (derived from Phase 2.4)
- Types of changes to focus on (logic, config, tests, infra)
- What to skip (auto-generated files, vendored code, lock files)

## Review Triggers
<!-- When this agent should be invoked -->
- On pull requests targeting primary branches
- On code changes exceeding a threshold (e.g., > 10 lines changed)
- Excluded: documentation-only PRs, dependency bumps (unless config changes)

## Review Checklist
<!-- Derived from CI checks, linting rules, and team conventions detected in Phases 2–3 -->
- [ ] Code follows naming conventions (`<detected conventions>`)
- [ ] All new/modified functions have appropriate tests
- [ ] No secrets, credentials, or hardcoded configuration values
- [ ] Error handling follows repo patterns (`<detected patterns>`)
- [ ] Logging uses the project's logging conventions (`<detected logging approach>`)
- [ ] Imports follow the project's ordering/grouping style
- [ ] CI checks would pass (lint, build, test)
- [ ] No TODO/FIXME comments introduced without a linked issue

### Security Review Checklist (STRIDE)
<!-- Applied to every PR. Intensity scales with the type of change:
     - Auth/network/data changes → full STRIDE review
     - Internal logic changes → credential leak + weak pattern scan
     - Documentation-only → skip -->
- [ ] **Spoofing** — Authentication present at entry points; tokens validated, not just checked for presence
- [ ] **Tampering** — Input validated at trust boundaries; file permissions restrictive; data integrity in transit/rest
- [ ] **Repudiation** — Security-relevant actions logged with context (who/what/when); no sensitive data in logs
- [ ] **Information Disclosure** — No hardcoded secrets, keys, or credentials; secrets not in logs/errors; debug endpoints disabled
- [ ] **Denial of Service** — Resource limits set (timeouts, payload sizes, container CPU/memory); no unbounded loops/goroutines
- [ ] **Elevation of Privilege** — Authorization at correct granularity; containers non-root; RBAC least-privilege; security contexts set
- [ ] **Credential Leak Scan** — No API keys, tokens, passwords, private keys, or connection strings in changed files
- [ ] **Weak Pattern Scan** — No disabled TLS verification, weak crypto, shell injection vectors, or unsafe deserialization

## Language-Specific Best Practices
<!-- Generate one subsection PER detected language. Derive rules from THREE sources:
     1. Phase 2.7 code conventions (what the code actually does)
     2. Phase 2.10 linter/formatter configs (what tools enforce)
     3. Phase 3.4 PR review feedback (what reviewers repeatedly flag)
     Cross-reference all three to produce authoritative, repo-specific rules. -->

### <Language 1> (e.g., Go)
<!-- For each language, include: -->
- **Enforced by tooling** — Rules from linter configs (Phase 2.10) that CI runs automatically. The reviewer can trust these are caught.
- **Reviewer-focus items** — Patterns NOT caught by tooling that reviewers must check manually. Prioritize by frequency from Phase 3.4.
- **Idiomatic patterns** — Language-specific idioms observed in this repo's code (Phase 2.7). Flag deviations.
- **Common mistakes** — Top issues from PR review feedback (Phase 3.4) for this language.

### <Language 2> (e.g., Ruby)
<!-- Repeat for each detected language -->

## Security Checks
<!-- Derived from Phase 2.11 security posture scan and the `security-review` skill's STRIDE checklist.
     This section should be populated with REPO-SPECIFIC security patterns, not generic advice. -->

### Credential & Secret Detection
- Scan all changed files for hardcoded secrets (API keys, tokens, passwords, private keys, connection strings)
- Verify `.gitignore` excludes secret file patterns (`*.pem`, `*.key`, `.env`, `*credentials*`)
- Check that env vars are used for secrets — not config files committed to the repo
- Flag Base64-encoded blobs that may contain credentials
- Verify test fixtures don't contain real credentials (even "test" secrets can leak)

### STRIDE Threat Assessment
<!-- For each changed file/module, evaluate which STRIDE categories apply.
     Not every category applies to every change — scale review intensity appropriately. -->
- **Spoofing**: Auth checks at entry points, token validation, service-to-service authentication
- **Tampering**: Input validation, checksum verification, file permission restrictions
- **Repudiation**: Security action logging, audit trail completeness
- **Information Disclosure**: Secret leaks in logs/errors, debug endpoint exposure, TLS configuration
- **Denial of Service**: Resource limits, timeout configuration, bounded concurrency
- **Elevation of Privilege**: Non-root containers, RBAC least-privilege, security contexts

### Weak Security Patterns
- No disabled TLS verification (`InsecureSkipVerify`, `verify=False`, `NODE_TLS_REJECT_UNAUTHORIZED=0`)
- No weak crypto (MD5/SHA1 for security, DES, RC4)
- No shell injection vectors (`eval`, `exec`, `system` with user input)
- No unsafe deserialization (`pickle.loads`, `YAML.load`, `JSON.parse` on untrusted input without schema validation)
- No SQL injection (string concatenation for queries instead of parameterized)
- No overly permissive file/directory permissions (0777, 0666)
- No HTTP in production URLs (must be HTTPS)
- No `latest` tags in container images (non-reproducible, potential supply chain risk)

### CI Security Tool Coverage
<!-- Report which security tools from Phase 2.11 are active in CI.
     For gaps, recommend additions. -->
- SAST: `<CodeQL / Semgrep / DevSkim — from Phase 2.11>`
- Dependency scanning: `<Trivy / Snyk / Dependabot — from Phase 2.11>`
- Secret scanning: `<Gitleaks / detect-secrets — from Phase 2.11 or recommend>`
- Container scanning: `<Trivy / Grype — from Phase 2.11 or recommend>`

## Testing Expectations
<!-- From Phase 2.6 testing patterns — what test coverage is expected for changes -->

## Review Feedback Patterns
<!-- Derived from Phase 3.4 PR review feedback analysis -->

### Top Recurring Review Comments
<!-- Ranked list of most frequently flagged issues from PR reviews in the last 12 months.
     Each item should include: the issue pattern, approximate frequency, and an example. -->

### Review Anti-Patterns
<!-- Things that reviewers have explicitly accepted or approved that should NOT be flagged.
     Derived from suppressed linter rules (Phase 2.10) and approved PR patterns. -->

## Common Issues to Flag
<!-- Patterns from BOTH bug-fix commits (Phase 3.1) AND reviewer feedback (Phase 3.4).
     Prioritize issues that appear in both sources — these are the most impactful. -->
```

**Rules:**
- Review checklist items must map to actual CI checks and linting rules in this repo.
- Language-specific best practices MUST be derived from the three-source cross-reference (code conventions, linter configs, PR feedback) — not from generic language guides.
- Review Feedback Patterns must reference real themes observed in PR review comments from the last 12 months.
- Security Checks must be populated from Phase 2.11 security posture scan — STRIDE categories, credential patterns, and weak security patterns must be repo-specific.
- Common issues should reference real patterns observed in both the commit history and review feedback.

---

### File 7: `DocumentWriter.agent.md`

**Location:** `.github/agents/DocumentWriter.agent.md` (GitHub) or root `DocumentWriter.agent.md` (other SCMs).

**Purpose:** A custom agent definition that enables AI assistants to write and maintain documentation following this repo's doc structure, conventions, and standards.

**Format:**

```markdown
# DocumentWriter Agent

## Description
You are a technical writer for this repository. Your job is to create and maintain documentation that is accurate, consistent, and follows the project's documentation conventions.

## Audience & Tone
<!-- Detected from existing documentation -->
- Primary audience (developers, operators, end-users, or mixed)
- Writing tone (formal technical, conversational, tutorial-style)
- Use of second person ("you") vs third person vs imperative
- Assumed knowledge level of readers

## Documentation Structure
<!-- Detected from Phase 2.4 directory structure — where docs live, how they're organized -->

## Writing Conventions
<!-- Detected from existing .md files in the repo -->
- Heading style (ATX vs Setext)
- List formatting conventions
- Code block language annotation style
- Link style (inline vs reference)
- File naming convention for docs
- Maximum line length or wrapping convention

## Documentation Types
<!-- What kinds of documentation exist in this repo — READMEs, API docs, guides, changelogs, etc. -->

## Templates
<!-- Common documentation patterns observed in existing files -->

### README Template
<!-- Based on existing README structure in this repo -->

### Code Comment Conventions
<!-- Docstring/comment style detected from Phase 2.7 -->

## Cross-References
<!-- How docs reference other docs, code, or external resources in this repo -->

## Validation
- All file paths referenced in documentation must exist
- All code examples must be syntactically valid
- All links must point to valid targets
- Documentation must match actual codebase behavior
```

**Rules:**
- Documentation structure must reflect the actual `docs/`, `Documentation/`, or README layout in this repo.
- Writing conventions must be derived from existing documentation files, not generic style guides.
- Templates should mirror patterns found in existing documentation.

---

## Quality Constraints

Apply these rules to ALL generated files:

1. **No hallucination** — Every file path, command, package name, and version you reference MUST exist in this repository. Verify before writing.
2. **No secrets** — Never include API keys, tokens, passwords, connection strings, or any credential values. Reference env var NAMES only.
3. **Specific, not generic** — Write instructions for THIS repo, not generic language/framework advice. If you can't determine something specific, omit it rather than guess.
4. **Actionable** — Every instruction should be something a developer or AI agent can execute literally.
5. **Consistent** — File cross-references must be valid (e.g., if AGENTS.md says "see Testing Instructions", that section must exist).
6. **SCM-aware** — Place files in the correct location per the SCM adaptation matrix. Skip `.instructions.md` files for non-GitHub repos.
7. **Commit-based skills only** — Only generate skill files for patterns with ≥ 3 commits in the last 12 months. Do not invent skills for patterns that don't exist in the commit history. **Exception:** The `security-review` skill is always generated regardless of commit frequency.
8. **Preserve existing content** — If any target file already exists, read it first. Preserve human-authored sections and only add/update generated sections. Mark generated sections with `<!-- generated -->` comments so they can be distinguished from human content.
9. **Size limits** — `copilot-instructions.md` ≤ 4000 characters. `.instructions.md` files ≤ 15 rules each. SKILL.md files ≤ 2 pages each. `CodeReviewer.agent.md` ≤ 5 pages. `DocumentWriter.agent.md` ≤ 3 pages. `security-review` SKILL.md ≤ 4 pages.

---

## Execution Checklist

After generating all files, verify:

- [ ] `copilot-instructions.md` — references only real paths and commands
- [ ] `copilot-instructions.md` — is ≤ 2 pages
- [ ] `AGENTS.md` — Setup Commands produce a working environment
- [ ] `AGENTS.md` — Testing Instructions include the exact CI test command
- [ ] `AGENTS.md` — Code Style reflects actual codebase conventions
- [ ] `.instructions.md` files — each has valid `applyTo` frontmatter (GitHub repos only)
- [ ] `.instructions.md` files — rules are observable in existing code
- [ ] `Prompt.md` — tech stack matches detected languages/frameworks
- [ ] `Prompt.md` — env vars listed are real (from `.env.example` or config)
- [ ] Skill files — each has ≥ 3 supporting commits from the last 12 months
- [ ] Skill files — instructions reference actual files and commands in this repo
- [ ] `CodeReviewer.agent.md` — placed in correct SCM-specific location
- [ ] `CodeReviewer.agent.md` — review instructions reference actual CI checks and linting rules
- [ ] `CodeReviewer.agent.md` — language-specific best practices derived from code conventions + linter configs + PR feedback (3-source cross-reference)
- [ ] `CodeReviewer.agent.md` — review feedback patterns section references real themes from PR review comments
- [ ] `CodeReviewer.agent.md` — STRIDE security checklist populated with repo-specific auth/network/data patterns from Phase 2.11
- [ ] `CodeReviewer.agent.md` — credential leak patterns include repo-specific secret formats (from Phase 2.11)
- [ ] `CodeReviewer.agent.md` — weak security patterns are language-specific to detected languages
- [ ] `security-review` skill — always generated with STRIDE checklist, credential detection rules, and weak pattern catalog
- [ ] `DocumentWriter.agent.md` — placed in correct SCM-specific location
- [ ] `DocumentWriter.agent.md` — writing instructions reference actual doc structure and conventions
- [ ] Monorepo — nested `AGENTS.md` generated for each subproject (if applicable)
- [ ] No secrets or credentials in any generated file
- [ ] All file paths in the SCM adaptation matrix are correct for the detected provider

---

## Output Summary

After completing all phases, provide a summary:

```
## Generated Files Summary

SCM Provider: <detected provider>
Monorepo: <yes/no>
Languages: <detected languages with percentages>
Frameworks: <detected frameworks>

### Files Generated
- [ ] <path> — <brief description>
- [ ] <path> — <brief description>
...

### Skills Generated (from commit history)
| Skill | Commits (12mo) | Key Files |
|-------|----------------|-----------|
| <name> | <count> | <top files involved> |
...

### Files Skipped
- <path> — <reason (e.g., "already exists with matching content", "SCM not supported")>

### Warnings
- <any issues encountered during generation>
```
