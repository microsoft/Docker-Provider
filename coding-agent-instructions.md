# Coding Agent Instructions — Azure Monitor for Containers (Docker-Provider)

> Comprehensive guide for developers and AI coding agents working in the
> `microsoft/Docker-Provider` repository.

---

## 1. Quick Start

```bash
# 1. Clone and enter the repo
git clone https://github.com/microsoft/Docker-Provider.git && cd Docker-Provider

# 2. Build the agent
cd build/linux && make

# 3. Build the container image
docker build -f kubernetes/linux/Dockerfile.multiarch -t ama-logs:dev .

# 4. Run unit tests
./test/unit-tests/run_go_tests.sh   # Go
ruby test/unit-tests/test_driver.rb # Ruby
./test/unit-tests/test_main.sh      # Bash

# 5. Run E2E tests (requires a configured AKS cluster)
pytest -xvs test/e2e/src/tests/
```

---

## 2. Generated Artifacts Overview

| File | Purpose |
|------|---------|
| `.github/agents/CodeReviewer.agent.md` | Code review agent persona |
| `.github/agents/SecurityReviewer.agent.md` | Security-focused review agent |
| `.github/agents/ThreatModelAnalyst.agent.md` | Threat-modelling agent |
| `.github/agents/DocumentWriter.agent.md` | Documentation authoring agent |
| `.github/agents/prd.agent.md` | Product requirements document agent |
| `.github/skills/dependency-update.skill.md` | Skill: update dependencies safely |
| `.github/skills/bug-fix.skill.md` | Skill: diagnose and fix bugs |
| `.github/skills/test-authoring.skill.md` | Skill: write tests |
| `.github/skills/feature-development.skill.md` | Skill: implement new features |
| `.github/skills/code-refactoring.skill.md` | Skill: refactor code |
| `.github/skills/documentation.skill.md` | Skill: write/update docs |
| `.github/skills/ci-cd-pipeline.skill.md` | Skill: CI/CD changes |
| `.github/skills/infrastructure.skill.md` | Skill: infra & Dockerfile changes |
| `.github/skills/security-patch.skill.md` | Skill: apply security patches |
| `.github/skills/performance-optimization.skill.md` | Skill: performance tuning |
| `.github/skills/security-review.skill.md` | Skill: security review (always-on) |
| `.github/skills/telemetry-authoring.skill.md` | Skill: telemetry instrumentation |
| `.github/skills/fix-critical-vulnerabilities.skill.md` | Skill: fix critical CVEs |
| `.vscode/mcp.json` | MCP server configuration |
| `test/AGENTS.md` | Test-directory agent guide |
| `coding-agent-instructions.md` | This file |
| `agentify.prompt.md` | Repository prompt file |
| `AGENTS.md` | Root agent instructions |

---

## 3. How the Context Loading Chain Works

AI coding agents load context in layers. Each layer adds specificity:

```
Layer 1 — Repository Prompt (agentify.prompt.md)
  │  Global repo description, tech stack, conventions
  ▼
Layer 2 — AGENTS.md (root + nested like test/AGENTS.md)
  │  Directory-specific build/test/style rules
  ▼
Layer 3 — Skills (.github/skills/*.skill.md)
  │  Task-specific playbooks activated by commit type or user request
  ▼
Layer 4 — Agents (.github/agents/*.agent.md)
     Persona definitions with specialized expertise and review checklists
```

**Rule of thumb:** Put stable, rarely-changing context in Layers 1–2. Put
task-specific, frequently-tuned context in Layers 3–4.

---

## 4. Using Custom Agents

Invoke agents with `@AgentName` in GitHub Copilot Chat or by referencing them
in a delegated task.

| Agent | When to use | Example prompt |
|-------|-------------|----------------|
| `@CodeReviewer` | PR reviews, code quality | _"@CodeReviewer Review this PR for correctness, error handling, and Go idioms."_ |
| `@SecurityReviewer` | Security-focused review | _"@SecurityReviewer Check this change for secret leaks, injection, and RBAC issues."_ |
| `@ThreatModelAnalyst` | Threat modelling | _"@ThreatModelAnalyst Produce a STRIDE analysis for the new custom-metrics endpoint."_ |
| `@DocumentWriter` | Docs authoring | _"@DocumentWriter Write a runbook for the Fluent-Bit output plugin reload procedure."_ |
| `@prd` | Feature specs / PRDs | _"@prd Draft a PRD for adding Prometheus remote-write support."_ |

---

## 5. Using Skills

### Always-Available Skills
These are active in every session:
- **security-review** — Automatically flags security concerns.
- **telemetry-authoring** — Guides App Insights / Geneva telemetry instrumentation.
- **fix-critical-vulnerabilities** — Prioritises and patches critical CVEs.

### Commit-Driven Skills
Activated based on the type of change:
- **dependency-update** — Bump Go modules, Ruby gems, Python packages.
- **bug-fix** — Root-cause analysis → fix → regression test.
- **test-authoring** — Write tests matching the framework decision tree.
- **feature-development** — End-to-end feature implementation.
- **code-refactoring** — Refactor without behaviour changes.
- **documentation** — Update READMEs, runbooks, inline docs.
- **ci-cd-pipeline** — Modify GitHub Actions, build pipelines.
- **infrastructure** — Dockerfile, Helm chart, deployment manifests.
- **security-patch** — Apply targeted security fixes.
- **performance-optimization** — Profile, benchmark, optimise hot paths.

---

## 6. Using Prompt.md

`agentify.prompt.md` at the repo root is the first file an AI agent reads. It
contains the repository description, tech stack, coding conventions, and key
architecture decisions. Edit it to change global agent behaviour across all
tools (Copilot Chat, CLI, PR agents).

---

## 7. Using AGENTS.md

`AGENTS.md` files provide directory-scoped instructions. The root `AGENTS.md`
covers build commands, project structure, and contribution rules. Nested files
like `test/AGENTS.md` add test-specific guidance. Agents automatically pick up
the nearest `AGENTS.md` when working in a directory.

---

## 8. MCP Server Integration

The `.vscode/mcp.json` configures two Model Context Protocol servers:

| Server | Purpose | Auth |
|--------|---------|------|
| **github** | Search issues, PRs, code, commits on GitHub | `GITHUB_TOKEN` (prompted) |
| **microsoft-docs** | Query Azure Monitor, AKS, App Insights docs | None required |

These give the AI agent live access to GitHub data and Azure documentation
without leaving the editor.

---

## 9. Prompt Engineering Best Practices

**Structure prompts clearly:**
```
TASK: <what you want>
CONTEXT: <relevant files, constraints, tech>
OUTPUT: <expected deliverable format>
```

**Anti-patterns to avoid:**
- ❌ Vague: _"Fix the bug"_ — Which bug? Where?
- ❌ Over-broad: _"Rewrite the whole agent"_ — Too large for one session.
- ❌ No context: _"Add a test"_ — For which function? Which framework?

**Good examples:**
- ✅ _"Add a Go testify unit test for `ParseCAdvisorMetric()` in
  `source/plugins/go/src/cadvisor.go`. Cover valid input, empty input, and
  malformed JSON."_
- ✅ _"Update the Helm values.yaml to support a `proxy.noProxy` list. Follow
  the existing pattern for `proxy.httpProxy`."_

---

## 10. Choosing the Right Copilot Tool

| Tool | Best for | Scope |
|------|----------|-------|
| Inline suggestions | Small edits, auto-complete | Current file |
| Copilot Chat | Q&A, explain code, plan changes | Workspace |
| Copilot CLI | Terminal tasks, multi-file changes | Full repo |
| `@agents` | Specialised reviews (security, docs) | PR / workspace |
| `/delegate` | Offload sub-tasks to background agents | Task-scoped |

---

## 11. Context Management

- **Open relevant files** before prompting — the agent sees open editor tabs.
- **Close unrelated files** to reduce noise and token usage.
- **Start fresh sessions** for unrelated tasks to avoid context bleed.
- **Reference files by path** when working in the CLI:
  `"Look at source/plugins/go/src/oms.go lines 100–150."`

---

## 12. Recommended Workflow: Explore → Plan → Code → Commit

```
1. EXPLORE  — Understand the area you are changing.
   "How does the container log pipeline work from Fluent-Bit to Log Analytics?"

2. PLAN     — Outline the change before writing code.
   "I need to add a new field 'PodLabels' to the ContainerLog schema.
    Files affected: oms.go, out_oms.go, containerlog.rb, schema.json."

3. CODE     — Implement with AI assistance.
   "Add the PodLabels field to the ContainerLog struct in oms.go and
    populate it in the enrichment step in out_oms.go."

4. COMMIT   — Build, test, and commit.
   cd build/linux && make
   ./test/unit-tests/run_go_tests.sh
   git add -A && git commit -m "feat: add PodLabels to ContainerLog schema"
```

---

## 13. Validating AI-Generated Code

Every AI-generated change must pass:

| Check | Command |
|-------|---------|
| Build | `cd build/linux && make` |
| Go tests | `./test/unit-tests/run_go_tests.sh` |
| Ruby tests | `ruby test/unit-tests/test_driver.rb` |
| Bash tests | `./test/unit-tests/test_main.sh` |
| E2E tests | `pytest -xvs test/e2e/src/tests/` |
| Docker build | `docker build -f kubernetes/linux/Dockerfile.multiarch .` |

Never merge AI-generated code that has not been built and tested locally.

---

## 14. Test-Driven Development with AI

1. **Describe the behaviour** you want to test.
2. **Ask the agent to write a failing test first** using the appropriate
   framework (see `test/AGENTS.md` for the decision tree).
3. **Implement the production code** to make the test pass.
4. **Refactor** while keeping tests green.

Example prompt:
> _"Write a Go testify test that verifies `FilterContainerLogs()` drops log
> lines matching the exclude regex. Then implement `FilterContainerLogs()`
> in `source/plugins/go/src/logfilter.go`."_

---

## 15. Codebase Onboarding with AI

Use the AI agent to ramp up on the codebase quickly. Example questions:

- _"How are container logs collected from the node and forwarded to Log
  Analytics?"_
- _"What is the pattern for adding a new Fluent-Bit input plugin?"_
- _"Where is the health/liveness probe logic and how does it determine the
  agent is healthy?"_
- _"How do the Ruby output plugins transform records before sending to
  Application Insights?"_
- _"What environment variables control agent behaviour at runtime?"_
- _"Walk me through the Dockerfile.multiarch build stages."_

---

## 16. Security When Using AI Assistants

- **Never paste secrets, tokens, or certificates** into prompts.
- **Review generated code for hard-coded credentials** before committing.
- **Use `@SecurityReviewer`** for any change touching auth, RBAC, TLS, or
  network policies.
- **Scan generated dependencies** — verify new packages are not malicious.
- **Keep `.env` and kubeconfig files in `.gitignore`.**

---

## 17. Measuring AI-Assisted Productivity

Track these metrics to understand AI impact:

| Metric | How to measure |
|--------|---------------|
| Time to first PR | Calendar time from task start to PR opened |
| Test coverage delta | Coverage % before and after AI-assisted changes |
| Review round-trips | Number of review cycles before merge |
| Bug escape rate | Post-merge bugs in AI-assisted vs manual code |
| Onboarding time | Days until a new contributor opens their first PR |

---

## 18. Tips for Maximum Productivity

1. **Be specific** — Name files, functions, and line ranges in prompts.
2. **One task per session** — Avoid context pollution across unrelated tasks.
3. **Use the decision tree** — Pick the right test framework before writing.
4. **Leverage agents** — `@CodeReviewer` catches issues before human review.
5. **Build often** — Run `make` after every significant change.
6. **Read before writing** — Explore existing code patterns first.
7. **Use skills for commit messages** — They encode team conventions.
8. **Keep prompts under 500 words** — Concise prompts get better results.
9. **Pin file references** — Open files you want the agent to see.
10. **Test incrementally** — Run the relevant test suite, not the whole matrix.
11. **Review diffs** — Always read the AI-generated diff before committing.
12. **Use MCP servers** — Query live GitHub issues and Azure docs in-context.
13. **Iterate** — If the first result is wrong, refine the prompt, don't start over.
14. **Commit frequently** — Small, well-tested commits are easier to review.
15. **Customise artifacts** — Tune `agentify.prompt.md` and skills as the
    team's conventions evolve.

---

## 19. Customizing These Artifacts

| Want to… | Edit this file |
|----------|---------------|
| Change global repo context | `agentify.prompt.md` |
| Change build/test instructions | `AGENTS.md` (root or nested) |
| Add a new agent persona | `.github/agents/<Name>.agent.md` |
| Add a new skill | `.github/skills/<name>.skill.md` |
| Add an MCP server | `.vscode/mcp.json` |
| Change test guidance | `test/AGENTS.md` |

---

## 20. Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Agent ignores repo conventions | `agentify.prompt.md` not loaded | Open the file or reference it in your prompt |
| Wrong test framework chosen | No test guidance in context | Open `test/AGENTS.md` before prompting |
| MCP server not connecting | Missing token | Set `GITHUB_TOKEN` when prompted by VS Code |
| Agent generates stale API calls | Outdated docs in context | Use `microsoft-docs` MCP for live Azure docs |
| Build fails after AI edit | Partial code generation | Re-prompt with the compiler error as context |
| Tests pass locally but fail in CI | Environment differences | Check CI logs; ensure env vars match CI config |
| Agent hallucinates file paths | Unfamiliar repo structure | Open `AGENTS.md` or run `find` to ground the agent |
| Large PR with mixed concerns | Prompt was too broad | Split into smaller, focused prompts |
| Security review missed an issue | `@SecurityReviewer` not invoked | Always invoke for auth, RBAC, TLS, and network changes |
| Slow agent responses | Too many open files / large context | Close unrelated files; start a fresh session |
