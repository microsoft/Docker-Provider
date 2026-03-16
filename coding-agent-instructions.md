# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for the Docker-Provider (Container Insights) repository.

## Quick Start

1. Open this repository in VS Code with Copilot enabled.
2. `copilot-instructions.md` loads automatically every session — no action needed.
3. When you open a `.go`, `.rb`, `.sh`, or `.py` file, the matching `.instructions.md` auto-activates.
4. Invoke skills by typing trigger phrases: "add test", "fix bug", "security review".
5. Invoke agents via @-mention: `@CodeReviewer`, `@DocumentWriter`, `@SecurityReviewer`.

## Generated Artifacts Overview

| Artifact | Path | Loaded | Purpose |
|----------|------|--------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Automatically | Root router — build commands, conventions, gotchas |
| `AGENTS.md` | Root | Automatically | Setup, code style, testing, dev environment, AI workflow |
| `.instructions.md` files | `.github/instructions/` | Auto on file match | Language-specific coding rules (Go, Ruby, Shell, Python) |
| `Prompt.md` | Root | On demand | Reusable task-spec template |
| Skill files (`SKILL.md`) | `.github/skills/` | On keyword trigger | Step-by-step guides for recurring tasks |
| `CodeReviewer.agent.md` | `.github/agents/` | On @-mention | Structured code review with STRIDE security |
| `SecurityReviewer.agent.md` | `.github/agents/` | On @-mention | Deep security analysis and threat modeling |
| `ThreatModelAnalyst.agent.md` | `.github/agents/` | On @-mention | STRIDE threat models with Mermaid diagrams |
| `DocumentWriter.agent.md` | `.github/agents/` | On @-mention | Documentation following repo conventions |
| `prd.agent.md` | `.github/agents/` | On @-mention | PRD generation for this project |
| `test/AGENTS.md` | `test/AGENTS.md` | Automatically | Test framework guide and decision tree |
| `.vscode/mcp.json` | `.vscode/mcp.json` | Automatically | MCP server connections (GitHub, Microsoft Docs) |

## How the Context Loading Chain Works

```
Layer 1: copilot-instructions.md (always loaded)
  ├── Build commands, conventions, known gotchas
  ├── Routes to →
  │
Layer 2: .instructions.md files (auto-loaded when you open matching files)
  ├── go.instructions.md → *.go files
  ├── ruby.instructions.md → *.rb files
  ├── shell.instructions.md → *.sh files
  ├── python.instructions.md → *.py files
  │
Layer 3: Skills (loaded only when invoked by trigger phrase)
  └── Step-by-step procedures for specific tasks
```

## Using Custom Agents

### @CodeReviewer
- **Invoke:** `@CodeReviewer` in Copilot Chat.
- **What it does:** Reviews PRs for correctness, code style, security (STRIDE), telemetry gaps, and test coverage.
- **Example prompts:**
  - `@CodeReviewer review this PR`
  - `@CodeReviewer check this file for security issues`
  - `@CodeReviewer review changes for telemetry gaps`

### @SecurityReviewer
- **Invoke:** `@SecurityReviewer` in Copilot Chat.
- **What it does:** Deep STRIDE security analysis, attack surface review, dependency audit.
- **Example prompts:**
  - `@SecurityReviewer perform a threat model for the Go output plugin`
  - `@SecurityReviewer review the Dockerfile security configuration`
  - `@SecurityReviewer assess the authentication changes`

### @ThreatModelAnalyst
- **Invoke:** `@ThreatModelAnalyst` in Copilot Chat.
- **What it does:** Generates persistent threat model artifacts under `threat-model/YYYY-MM-DD/`.
- **Example prompts:**
  - `@ThreatModelAnalyst perform a full threat model analysis`
  - `@ThreatModelAnalyst threat model the log ingestion pipeline`

### @DocumentWriter
- **Invoke:** `@DocumentWriter` in Copilot Chat.
- **What it does:** Creates/maintains documentation following repo conventions.
- **Example prompts:**
  - `@DocumentWriter write release notes for v3.1.36`
  - `@DocumentWriter update the README with new features`

### @prd (PRD Generator)
- **Invoke:** `@prd` in Copilot Chat.
- **What it does:** Generates structured PRDs tailored to Docker-Provider architecture.
- **Example prompts:**
  - `@prd create a PRD for adding OpenTelemetry trace support`

## Using Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `security-review` | "security review", "STRIDE analysis", "credential leak check" | STRIDE-based security review |
| `telemetry-authoring` | "add telemetry", "add metrics", "instrument code" | Add Application Insights telemetry |
| `fix-critical-vulnerabilities` | "fix CVE", "trivy fix", "patch vulnerability" | Fix CRITICAL/HIGH CVEs using Trivy |
| `bug-fix` | "fix bug", "resolve issue", "hotfix" | Structured bug fix workflow |
| `dependency-update` | "update dependency", "bump package", "upgrade" | Safe dependency updates |
| `feature-development` | "add feature", "implement", "new support" | New feature scaffolding |
| `test-authoring` | "add test", "write test", "test coverage" | Test creation following conventions |
| `ci-cd-pipeline` | "pipeline change", "CI fix", "workflow update" | CI/CD modifications |
| `infrastructure` | "Terraform update", "Helm chart", "Bicep template" | IaC and deployment changes |
| `documentation` | "release notes", "readme update", "doc update" | Documentation updates |

## Prompt Engineering Best Practices

### Structuring Effective Prompts
1. **Break complex tasks into smaller prompts** — "Add error telemetry to `in_kube_nodes.rb`" not "refactor all Ruby plugins".
2. **Be specific** — Reference file paths: `source/plugins/go/src/oms.go`, function names: `FLBPluginFlush`.
3. **Provide examples** — "Parse container log lines like `2024-01-15T10:30:00Z stdout F log message`".
4. **State constraints** — "Using Go 1.25, follow the existing ApplicationInsights-Go pattern".
5. **Ask for explanations** — "Explain the Fluent Bit plugin flush lifecycle before implementing".

### Anti-Patterns
- Vague requests without specifying the component or file.
- Asking for multiple unrelated changes in one prompt.
- Skipping validation — always run tests after changes.

## Choosing the Right Copilot Tool

| Task | Best Tool | Why |
|------|-----------|-----|
| Code completion | **Inline suggestions** | Fast for Go/Ruby boilerplate |
| Questions about code | **Copilot Chat** | Context-aware, supports @agents |
| Multi-file changes | **Copilot CLI** | Terminal-native, autonomous |
| Code review | **@CodeReviewer** | Repo-specific review checklist |
| Async work | **Coding agent (`/delegate`)** | Creates PRs without blocking |

## Context Management

1. **Open relevant files** before prompting — Copilot uses open tabs.
2. **Close unrelated files** — too many tabs dilute AI focus.
3. **Start fresh** for new tasks — new chat session resets context.
4. **Use @-references** — `#file:source/plugins/go/src/oms.go` for precision.

## Recommended Workflow: Explore → Plan → Code → Commit

1. **Explore** — `"Read the container log collection pipeline and explain how logs flow from Fluent Bit to Azure Monitor"`
2. **Plan** — `"/plan Add network flow log support to the Go output plugin"`
3. **Code** — `"Implement step 1: add the network flow log data structure"`
4. **Test** — `"Run ./test/unit-tests/run_go_tests.sh and fix failures"`
5. **Commit** — `"Commit with descriptive message"`

| Use this workflow for | Skip for |
|----------------------|----------|
| New feature implementations | Quick bug fixes |
| Multi-file refactoring | Single file edits |
| Architecture changes | Doc-only updates |

## Validating AI-Generated Code

1. **Understand** the code — ask AI to explain if unclear.
2. **Build** — `cd build/linux && make`
3. **Test** — Run unit tests for affected languages.
4. **Scan** — `trivy fs --severity CRITICAL,HIGH --scanners vuln .`
5. **Security** — No hardcoded secrets, proper env var usage.
6. **Match patterns** — Compare against similar existing code.

## Test-Driven Development with AI

1. Write failing tests first: `"Write a Go test for a new container restart detection function"`
2. Review tests, approve edge cases.
3. Implement: `"Write code to make all tests pass"`
4. Refactor while keeping tests green.

## Codebase Onboarding with AI

- "How does container log collection work from Fluent Bit through Go plugins to MDSD?"
- "What's the pattern for adding a new Ruby Fluentd input plugin?"
- "Explain the ApplicationInsightsUtility telemetry pattern"
- "Where are the Kubernetes RBAC definitions for the DaemonSet?"
- "What environment variables control the agent's behavior?"

## Security When Using AI Assistants

- Never commit secrets — verify no `APPLICATIONINSIGHTS_AUTH` values or tokens in code.
- Review all changes — AI can miss security patterns specific to this agent.
- Run security scanners after changes: Trivy, CodeQL.
- Don't share credentials via prompts.

## Measuring AI-Assisted Productivity

- Time from issue to pull request
- Review iteration count on AI-assisted PRs
- Test coverage improvements
- Bug rate in AI-assisted code
- Developer satisfaction with AI workflows

## Customizing These Artifacts

- Add rules to `.instructions.md` when establishing new conventions.
- Add skills when identifying new recurring workflows.
- Update `copilot-instructions.md` when build commands change.
- Update `AGENTS.md` when setup or test strategies change.
- Re-run generation quarterly to refresh skills from commit patterns.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow conventions | Verify `.instructions.md` `applyTo` matches the file type |
| Skill not activating | Use exact trigger phrases from the skill table |
| Agent not available | Ensure `.agent.md` is in `.github/agents/` |
| MCP server not connecting | Check `.vscode/mcp.json` and provide credentials |
| Build commands fail | Update Setup Commands in `AGENTS.md` |
| Context feels stale | Start a new chat session |
