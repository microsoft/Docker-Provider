# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for the Docker-Provider repository. These artifacts make AI assistants (GitHub Copilot, Google Jules, Gemini CLI, Cursor, etc.) understand your codebase deeply and contribute effectively.

## Quick Start

1. Open this repository in VS Code (or your preferred editor with Copilot/AI assistant support).
2. The AI assistant automatically loads `.github/copilot-instructions.md` on every session.
3. When you open a `.go`, `.rb`, `.sh`, `.ps1`, or `.py` file, the corresponding `.instructions.md` auto-activates.
4. Invoke skills by typing trigger phrases in chat (e.g., "add test", "fix bug", "security review").
5. Invoke agents by @-mentioning them (e.g., `@CodeReviewer`, `@DocumentWriter`).

## Generated Artifacts Overview

| Artifact | Path | Loaded | Purpose |
|----------|------|--------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Auto every session | Root router — build commands, skill catalogue, known gotchas |
| `AGENTS.md` | Root | Auto (supported tools) | Setup commands, code style, testing, dev tips |
| `.instructions.md` files | `.github/instructions/` | Auto on file match | Language-specific coding rules (Go, Ruby, Shell, PS, Python) |
| `Prompt.md` | Root | On demand | Reusable task-spec template |
| Skill files | `.github/skills/*/SKILL.md` | On keyword trigger | Step-by-step guides for recurring tasks |
| `CodeReviewer.agent.md` | `.github/agents/` | On @-mention | Structured code review with STRIDE security |
| `SecurityReviewer.agent.md` | `.github/agents/` | On @-mention | Deep STRIDE security analysis |
| `ThreatModelAnalyst.agent.md` | `.github/agents/` | On @-mention | Persistent threat model artifacts with Mermaid diagrams |
| `DocumentWriter.agent.md` | `.github/agents/` | On @-mention | Documentation following repo conventions |
| `prd.agent.md` | `.github/agents/` | On @-mention | PRD generation for this project |
| `.vscode/mcp.json` | `.vscode/mcp.json` | Auto by VS Code | MCP server connections (GitHub, Microsoft Docs) |

## How the Context Loading Chain Works

```
Layer 1: .github/copilot-instructions.md (always loaded)
  ├── General rules, build commands, skill catalogue
  ├── Routes to →
Layer 2: .github/instructions/*.instructions.md (auto-loaded on file match)
  ├── Go, Ruby, Shell, PowerShell, Python coding rules
  ├── Tells agent to follow repo-specific patterns
Layer 3: Skills (loaded on keyword trigger)
  └── Step-by-step procedures for specific tasks
```

## Using Custom Agents

### @CodeReviewer
- **Invoke:** Type `@CodeReviewer` in Copilot Chat.
- **What it does:** Reviews PRs for correctness, style, STRIDE security, telemetry gaps.
- **Example prompts:** `@CodeReviewer review this PR`, `@CodeReviewer check for security issues`

### @SecurityReviewer
- **Invoke:** Type `@SecurityReviewer` in Copilot Chat.
- **What it does:** Deep security assessment — threat modeling, attack surface analysis, STRIDE deep-dive.
- **Example prompts:** `@SecurityReviewer analyze the auth changes`, `@SecurityReviewer audit container security`

### @ThreatModelAnalyst
- **Invoke:** Type `@ThreatModelAnalyst` in Copilot Chat.
- **What it does:** Generates persistent threat model artifacts under `threat-model/YYYY-MM-DD/`.
- **Example prompts:** `@ThreatModelAnalyst perform a full threat model`, `@ThreatModelAnalyst analyze the log pipeline`

### @DocumentWriter
- **Invoke:** Type `@DocumentWriter` in Copilot Chat.
- **Example prompts:** `@DocumentWriter write a README for this module`, `@DocumentWriter update release notes`

### @prd
- **Invoke:** Type `@prd` in Copilot Chat.
- **Example prompts:** `@prd create a PRD for adding new log format support`

## Using Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `security-review` | "security review", "STRIDE analysis", "credential scan" | STRIDE security review with credential detection |
| `telemetry-authoring` | "add telemetry", "add metrics", "instrument code" | Add Application Insights telemetry following repo patterns |
| `fix-critical-vulnerabilities` | "fix CVE", "trivy fix", "patch vulnerability" | Fix critical/high CVEs using repo scanning tools |
| `dependency-update` | "update dependency", "bump package" | Safe dependency updates with testing |
| `bug-fix` | "fix bug", "resolve issue", "hotfix" | Structured bug fix with regression test |
| `feature-development` | "add feature", "implement", "new plugin" | New feature scaffolding with tests |
| `test-authoring` | "add test", "write test" | Create tests across multi-framework infrastructure |
| `ci-cd-pipeline` | "update pipeline", "CI change" | Modify GitHub Actions or Azure DevOps pipelines |
| `infrastructure` | "update Helm", "update Dockerfile" | Helm, Docker, Bicep, Terraform changes |

## Prompt Engineering Best Practices

### Structuring Effective Prompts
1. **Break complex tasks into smaller prompts** — "Explain the Fluent Bit output flow" then "Add error handling to the flush function."
2. **Be specific** — Reference actual paths: "Fix the liveness probe in `source/plugins/go/src/oms.go`".
3. **Provide examples** — "Parse container logs like `2024-01-15T10:30:00Z stdout F message`".
4. **State constraints** — "Using Go 1.23.8, follow existing `if err != nil` patterns."
5. **Ask for explanations** — "Explain what `FLBPluginFlushCtx` does before I modify it."

### Anti-Patterns to Avoid
- Vague requests without specifying the affected component
- Asking for changes across all languages in one prompt
- Skipping test validation after accepting generated code

## Choosing the Right Copilot Tool

| Task | Best Tool | Why |
|------|-----------|-----|
| Completing code as you type | Inline suggestions | Fast for patterns, variable names |
| Questions about code, @agents | Copilot Chat (IDE) | Context-aware, supports @-agents |
| Autonomous multi-file tasks | Copilot CLI | Terminal-native, supports `/plan` |
| Reviewing code changes | @CodeReviewer | Structured review against repo conventions |
| Async branch work | Coding agent (`/delegate`) | Runs in cloud, creates PRs |

## Recommended Workflow: Explore → Plan → Code → Commit

1. **Explore** — "Read `source/plugins/go/src/oms.go` and explain the data flow"
2. **Plan** — "/plan Add support for a new log format in the output plugin"
3. **Code** — "Implement step 1: add the log format parser"
4. **Test** — "Run `./test/unit-tests/run_go_tests.sh` and fix failures"
5. **Commit** — "Commit with a descriptive message"

| Use for | Skip for |
|---------|----------|
| New features, multi-file refactoring | Quick bug fixes, single-file edits |
| Architecture changes, new plugins | Documentation-only updates |

## Validating AI-Generated Code

1. **Understand** — Read the code; ask for explanation if unclear.
2. **Build** — `cd build/linux && make`
3. **Test** — Run appropriate test suite (`run_go_tests.sh`, `run_ruby_tests.sh`, etc.)
4. **Security** — Check for hardcoded secrets, proper error handling.
5. **Patterns** — Compare against existing code for consistency.

## Test-Driven Development with AI

1. Write failing tests first: "Write a Go test for the new flush timeout handling"
2. Review and approve the tests.
3. Implement to pass: "Write code to make all tests pass"
4. Refactor while keeping tests green.

## Codebase Onboarding with AI

- "How does container log collection work in this project?"
- "What's the pattern for adding a new Fluentd input plugin?"
- "Explain the Kubernetes inventory collection flow in Ruby"
- "Where are the Helm chart templates for the DaemonSet?"
- "What environment variables does the agent need to start?"

## Context Management

1. **Open relevant files** before prompting — Copilot uses open tabs as context.
2. **Close unrelated files** — too many tabs dilute focus.
3. **Start fresh** for new tasks — residual context from previous tasks can confuse responses.
4. **Use @-references** — `#file:source/plugins/go/src/oms.go` to focus on specific code.

## Security When Using AI Assistants

- Never commit secrets — verify AI code doesn't hardcode API keys or connection strings.
- Review all proposed changes — AI can produce subtly incorrect security code.
- Don't share credentials via prompts — use environment variables and `.env` files.
- Run security tools after changes — CodeQL, DevSkim, Trivy.

## Measuring AI-Assisted Productivity

- **Time from issue to PR** — How quickly tasks move from backlog to PR.
- **Review iteration cycles** — Number of rounds needed on AI-assisted vs. manual PRs.
- **Test coverage** — Whether AI-assisted development maintains or improves coverage.
- **Bug rate** — Post-merge defects to calibrate trust in AI suggestions.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow conventions | Verify `.instructions.md` `applyTo` glob matches your file |
| Skill not activating | Use exact trigger phrases from the skills table |
| Agent not available | Ensure `.agent.md` is in `.github/agents/` |
| MCP server not connecting | Check `.vscode/mcp.json` and provide credentials when prompted |
| Build/test commands fail | Verify Setup Commands in `AGENTS.md` match your environment |
| AI gives generic advice | Open the relevant `.instructions.md` file in your editor |
