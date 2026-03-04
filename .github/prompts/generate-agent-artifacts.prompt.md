# Agentify This Repository — Declarative Agent Prompt

Drop this file into any source code repository and submit it to a coding agent (GitHub Copilot, Codex CLI, Google Jules, Gemini CLI, Cursor, Amp, or any AGENTS.md-compatible tool). The agent will analyze the repo and generate a complete set of coding-agent best-practice files.

No code installation, no CLI tool, no API keys required — the coding agent IS the tool.

---

## Goal

Analyze this repository's codebase, structure, conventions, CI/CD configuration, and **git commit history (last 6 months)** to auto-generate the following files that make this repo "agent-ready" for AI coding assistants:

| Output File | Standard | Where |
|-------------|----------|-------|
| `copilot-instructions.md` | GitHub official | `.github/copilot-instructions.md` (GitHub) or root (other SCMs) |
| `AGENTS.md` | Open standard (AAIF / Linux Foundation) | Root (+ nested per subproject for monorepos) |
| `.instructions.md` files | GitHub official | `.github/instructions/` (GitHub only) |
| `Prompt.md` | Workspace convention | Root |
| `SKILL.md` files | Azure extension pattern | `.agents/skills/<name>/SKILL.md` |

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

Check what already exists: `.github/copilot-instructions.md`, `AGENTS.md`, `.github/instructions/`, `Prompt.md`, `DESIGN.md`, `.agents/`. Report what's present and what's missing.

---

### Phase 3 — Analyze Git Commit History (Last 6 Months)

Run `git log` to analyze the last 6 months of commit history. This data drives **skill file generation**.

```bash
git log --since="6 months ago" --pretty=format:"%h|%s|%an|%ad" --date=short
```

Also get file-level change stats:

```bash
git log --since="6 months ago" --pretty=format:"%h|%s" --stat --diff-filter=AMRD
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
1. **Count** how many commits match (minimum 3 commits in 6 months to qualify as a skill).
2. **Extract** the specific files, directories, and commands involved.
3. **Identify** the typical workflow: what files are touched together, what tests should be run, what CI checks matter.
4. **Note** any team conventions: commit message format, branch naming, review requirements.

#### 3.3 Frequency-Based Prioritization

Rank patterns by commit frequency. Generate skill files only for patterns with ≥ 3 occurrences. Order skills from most to least frequent.

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

Generate skill files ONLY for patterns detected in Phase 3 (git commit history analysis) with **≥ 3 occurrences in the last 6 months**.

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

---

## Quality Constraints

Apply these rules to ALL generated files:

1. **No hallucination** — Every file path, command, package name, and version you reference MUST exist in this repository. Verify before writing.
2. **No secrets** — Never include API keys, tokens, passwords, connection strings, or any credential values. Reference env var NAMES only.
3. **Specific, not generic** — Write instructions for THIS repo, not generic language/framework advice. If you can't determine something specific, omit it rather than guess.
4. **Actionable** — Every instruction should be something a developer or AI agent can execute literally.
5. **Consistent** — File cross-references must be valid (e.g., if AGENTS.md says "see Testing Instructions", that section must exist).
6. **SCM-aware** — Place files in the correct location per the SCM adaptation matrix. Skip `.instructions.md` files for non-GitHub repos.
7. **Commit-based skills only** — Only generate skill files for patterns with ≥ 3 commits in the last 6 months. Do not invent skills for patterns that don't exist in the commit history.
8. **Preserve existing content** — If any target file already exists, read it first. Preserve human-authored sections and only add/update generated sections. Mark generated sections with `<!-- generated -->` comments so they can be distinguished from human content.
9. **Size limits** — `copilot-instructions.md` ≤ 4000 characters. `.instructions.md` files ≤ 15 rules each. SKILL.md files ≤ 2 pages each.

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
- [ ] Skill files — each has ≥ 3 supporting commits from the last 6 months
- [ ] Skill files — instructions reference actual files and commands in this repo
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
| Skill | Commits (6mo) | Key Files |
|-------|---------------|-----------|
| <name> | <count> | <top files involved> |
...

### Files Skipped
- <path> — <reason (e.g., "already exists with matching content", "SCM not supported")>

### Warnings
- <any issues encountered during generation>
```
