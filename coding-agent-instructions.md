# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for this repository. These artifacts make AI assistants (GitHub Copilot, Google Jules, Gemini CLI, Cursor, etc.) understand the codebase deeply and contribute effectively.

## Quick Start

1. Open this repository in VS Code with Copilot enabled.
2. `copilot-instructions.md` loads automatically every session — no action needed.
3. When you open a `.rb`, `.go`, `.sh`, or `.ps1` file, the matching `.instructions.md` auto-activates.
4. Invoke skills by typing trigger phrases in chat (e.g., "add test", "fix CVE", "security review").
5. Invoke agents by @-mentioning them (e.g., `@CodeReviewer`, `@DocumentWriter`).

## Generated Artifacts Overview

| Artifact | Path | Loaded | Purpose |
|----------|------|--------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Auto (every session) | Root router — build commands, skills, guidelines |
| `AGENTS.md` | Root | Auto (supported tools) | Setup, code style, testing, dev tips, AI workflow |
| Ruby instructions | `.github/instructions/ruby.instructions.md` | Auto on `*.rb` | Ruby/Fluentd plugin conventions |
| Go instructions | `.github/instructions/go.instructions.md` | Auto on `*.go` | Go/Fluent Bit plugin conventions |
| Shell instructions | `.github/instructions/shell.instructions.md` | Auto on `*.sh` | Bash scripting conventions |
| PowerShell instructions | `.github/instructions/powershell.instructions.md` | Auto on `*.ps1` | PowerShell conventions |
| `Prompt.md` | Root | On demand | Reusable task-spec template |
| Skill files | `.github/skills/*/SKILL.md` | On keyword trigger | Step-by-step task guides |
| `CodeReviewer.agent.md` | `.github/agents/` | On @-mention | Structured code review |
| `SecurityReviewer.agent.md` | `.github/agents/` | On @-mention | Deep security analysis |
| `ThreatModelAnalyst.agent.md` | `.github/agents/` | On @-mention | STRIDE threat modeling with artifacts |
| `DocumentWriter.agent.md` | `.github/agents/` | On @-mention | Documentation authoring |
| `prd.agent.md` | `.github/agents/` | On @-mention | PRD generation |
| `.vscode/mcp.json` | `.vscode/mcp.json` | Auto by VS Code | MCP server connections |
| Test AGENTS.md | `test/AGENTS.md` | Auto in test dirs | Test framework guide |

## How the Context Loading Chain Works

```
Layer 1: copilot-instructions.md (always loaded)
  ├── General rules, build commands, skill catalogue
  ├── Routes to →
Layer 2: .instructions.md files (auto-loaded on file match)
  ├── ruby.instructions.md → when editing *.rb
  ├── go.instructions.md → when editing *.go
  ├── shell.instructions.md → when editing *.sh
  └── powershell.instructions.md → when editing *.ps1
Layer 3: Skills (loaded on trigger phrase)
  └── Step-by-step procedures for specific tasks
```

## Using Custom Agents

### @CodeReviewer
- **Invoke:** `@CodeReviewer` in Copilot Chat
- **Does:** Reviews PRs for correctness, style, security (STRIDE), telemetry gaps
- **Examples:** `@CodeReviewer review this PR`, `@CodeReviewer check for security issues`

### @SecurityReviewer
- **Invoke:** `@SecurityReviewer` in Copilot Chat
- **Does:** Deep security analysis — threat modeling, attack surface, STRIDE deep-dive
- **Examples:** `@SecurityReviewer audit the authentication changes`, `@SecurityReviewer review container security`

### @ThreatModelAnalyst
- **Invoke:** `@ThreatModelAnalyst` in Copilot Chat
- **Does:** Generates persistent threat model artifacts under `threat-model/YYYY-MM-DD/`
- **Examples:** `@ThreatModelAnalyst perform a full threat model`, `@ThreatModelAnalyst analyze the MDSD data flow`

### @DocumentWriter
- **Invoke:** `@DocumentWriter` in Copilot Chat
- **Does:** Creates documentation following repo conventions
- **Examples:** `@DocumentWriter write a README for the Go plugins`, `@DocumentWriter update release notes`

### @prd
- **Invoke:** `@prd` in Copilot Chat
- **Does:** Generates Product Requirements Documents tailored to this project
- **Examples:** `@prd create a PRD for adding OTLP metric support`

## Using Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `security-review` | "security review", "STRIDE analysis" | STRIDE-based security review |
| `telemetry-authoring` | "add telemetry", "instrument code" | Add Application Insights telemetry |
| `fix-critical-vulnerabilities` | "fix CVE", "trivy fix" | Fix critical/high CVEs via Trivy |
| `dependency-update` | "update dependency", "bump package" | Safe dependency updates |
| `bug-fix` | "fix bug", "resolve issue" | Structured bug fix with regression test |
| `feature-development` | "add feature", "new plugin" | New feature scaffolding |
| `ci-cd-pipeline` | "update pipeline", "fix CI" | CI/CD pipeline modifications |
| `infrastructure` | "update Dockerfile", "modify Helm" | Infrastructure changes |

## Prompt Engineering Best Practices

### Structuring Effective Prompts
1. **Break complex tasks into smaller prompts** — one plugin, one function, one test at a time.
2. **Be specific** — "Add error telemetry to the rescue block in `in_kube_nodes.rb` line 150" beats "add error handling".
3. **Provide examples** — Show sample Kubernetes API responses when asking for parsing logic.
4. **State constraints** — "Using Go 1.23, follow the existing testify pattern in `oms_test.go`".

### Anti-Patterns to Avoid
- Vague: "Fix this" without specifying what or where.
- Overloaded: Multiple unrelated changes in one prompt.
- Skipping validation: Never accept code without running tests.

## Choosing the Right Copilot Tool

| Task | Best Tool |
|------|-----------|
| Completing code as you type | Inline suggestions |
| Questions about code, using @agents | Copilot Chat (IDE) |
| Autonomous multi-file tasks | Copilot CLI |
| Reviewing code changes | @CodeReviewer agent |
| Async work on separate branches | Coding agent (`/delegate`) |

## Recommended Workflow: Explore → Plan → Code → Commit

1. **Explore** — "Read the container inventory plugin and explain the data collection flow"
2. **Plan** — "Plan how to add network flow log collection. List all files that need changes."
3. **Code** — "Implement step 1: add the NetworkFlowLog data type constant in oms.go"
4. **Test** — "Run `./test/unit-tests/run_go_tests.sh` and fix any failures"
5. **Commit** — "Commit with a descriptive message"

| Use this workflow for | Skip for |
|----------------------|----------|
| New features, multi-file refactoring | Quick bug fixes, single-file edits |
| Architecture changes | Documentation-only updates |

## Validating AI-Generated Code

1. **Understand** the suggestion — ask the AI to explain if unclear.
2. **Build** — Verify Go plugins compile: `cd source/plugins/go/src && make fbplugin`.
3. **Test** — Run all relevant test suites.
4. **Security** — Check for hardcoded secrets, proper input validation.
5. **Patterns** — Compare against similar code in the repo for consistency.

## Test-Driven Development with AI

1. Write failing tests first: "Write a Go test for parsing malformed container log entries"
2. Review and approve the tests.
3. Implement: "Write code to make all tests pass"
4. Refactor while keeping tests green.

## Codebase Onboarding with AI

- "How does container log collection work end-to-end?"
- "What's the pattern for adding a new Fluentd input plugin?"
- "Explain the difference between DaemonSet and ReplicaSet plugins"
- "How is Application Insights telemetry initialized in Ruby plugins?"
- "What environment variables does the agent container need?"

## Security When Using AI Assistants

- Never commit secrets — verify no hardcoded `APPLICATIONINSIGHTS_AUTH` or tokens.
- Review all changes for credential leakage.
- Run CodeQL and DevSkim after AI-generated changes.
- Don't paste secrets into chat prompts.

## Context Management

1. **Open relevant files** before prompting — Copilot uses open tabs as context.
2. **Close unrelated files** to focus the AI.
3. **Start fresh sessions** for unrelated tasks.

## Customizing These Artifacts

- Add rules to `.instructions.md` files when establishing new conventions.
- Add skills when you identify new recurring workflows.
- Update `copilot-instructions.md` when project structure changes.
- Update `AGENTS.md` when setup commands or test strategies change.
- Re-run generation quarterly to refresh skills from commit history.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow Ruby conventions | Verify `ruby.instructions.md` `applyTo` matches `*.rb` |
| Skill not activating | Use exact trigger phrases from the skills table |
| Build commands fail | Check `AGENTS.md` Setup Commands match your environment |
| AI gives generic advice | Open `copilot-instructions.md` in your editor for context |
| Context feels confused | Start a new chat session to reset |
