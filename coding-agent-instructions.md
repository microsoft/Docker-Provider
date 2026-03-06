# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for the Docker-Provider repository. These artifacts make AI assistants (GitHub Copilot, Google Jules, Gemini CLI, Cursor, etc.) understand this codebase deeply and contribute effectively.

## Quick Start

1. Open this repository in VS Code (or your preferred editor with Copilot/AI assistant support).
2. The AI assistant automatically loads `copilot-instructions.md` on every session — no action needed.
3. When you open a file matching a language pattern, the corresponding `.instructions.md` file auto-activates.
4. Invoke skills by typing their trigger phrases in chat (e.g., "add test", "fix bug", "security review").
5. Invoke agents by @-mentioning them in chat (e.g., `@CodeReviewer`, `@DocumentWriter`).

## Generated Artifacts Overview

| Artifact | Path | Loaded | Purpose |
|----------|------|--------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Automatically every session | Root router — general rules, build commands, conventions |
| `AGENTS.md` | Root | Automatically (supported tools) | Setup commands, code style, testing instructions, architecture |
| `.instructions.md` files | `.github/instructions/` | Auto on file match (`applyTo` glob) | Language-specific coding rules (Go, Ruby, Shell, PowerShell) |
| `Prompt.md` | Root | On demand | Reusable task-spec template for new work |
| Skill files (`SKILL.md`) | `.github/skills/` | On keyword trigger | Step-by-step guides for recurring tasks |
| `CodeReviewer.agent.md` | `.github/agents/` | On @-mention | Structured code review with STRIDE security |
| `SecurityReviewer.agent.md` | `.github/agents/` | On @-mention | Deep security analysis and threat modeling |
| `DocumentWriter.agent.md` | `.github/agents/` | On @-mention | Documentation authoring following repo standards |
| `prd.agent.md` | `.github/agents/` | On @-mention | PRD generation tailored to this project |
| `.vscode/mcp.json` | `.vscode/mcp.json` | Automatically by VS Code | MCP server configuration (GitHub, Microsoft Docs) |

## How the Context Loading Chain Works

```
Layer 1: copilot-instructions.md (always loaded)
  ├── General rules, build commands, conventions
  ├── Routes to →
  │
Layer 2: .instructions.md files (auto-loaded when you open matching files)
  ├── go.instructions.md → activates for *.go files
  ├── ruby.instructions.md → activates for *.rb files
  ├── shell.instructions.md → activates for *.sh files
  ├── powershell.instructions.md → activates for *.ps1 files
  │
Layer 3: Skills (loaded only when invoked by trigger phrase)
  └── Step-by-step procedures for specific tasks
```

## Using Custom Agents

### @CodeReviewer
- **Invoke:** Type `@CodeReviewer` in Copilot Chat.
- **What it does:** Reviews PRs for correctness, style, STRIDE security, telemetry gaps, and project conventions.
- **Example prompts:**
  - `@CodeReviewer review this PR`
  - `@CodeReviewer check this file for security issues`
  - `@CodeReviewer review my changes for telemetry gaps`

### @DocumentWriter
- **Invoke:** Type `@DocumentWriter` in Copilot Chat.
- **What it does:** Creates and maintains documentation following repo doc conventions.
- **Example prompts:**
  - `@DocumentWriter write release notes for version 3.1.36`
  - `@DocumentWriter update the README`

### @SecurityReviewer
- **Invoke:** Type `@SecurityReviewer` in Copilot Chat.
- **What it does:** Deep security analysis including threat modeling, STRIDE deep-dive, and dependency auditing.
- **Example prompts:**
  - `@SecurityReviewer perform a threat model for the new auth changes`
  - `@SecurityReviewer audit our container security configuration`
- **When to use:** For dedicated security analysis beyond routine code review — before releases or after architecture changes.

### @prd (PRD Generator)
- **Invoke:** Type `@prd` in Copilot Chat.
- **What it does:** Generates structured PRDs tailored to this project's container monitoring architecture.
- **Example prompts:**
  - `@prd create a PRD for adding OpenTelemetry metrics support`
  - `@prd write requirements for Windows ARM64 support`

## Using Skills

Skills activate when you use their trigger phrases in chat. Just describe what you want to do naturally.

### Always-Available Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `security-review` | "security review", "threat model", "STRIDE analysis" | STRIDE-based security review and credential scanning |
| `telemetry-authoring` | "add telemetry", "add metrics", "instrument code" | Guides adding Application Insights telemetry |
| `fix-critical-vulnerabilities` | "fix critical vulnerability", "CVE fix", "trivy fix" | Identifies and fixes CRITICAL/HIGH CVEs |

### Commit-History-Driven Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `dependency-update` | "update dependency", "bump package", "update go.mod" | Safe dependency updates across Go modules |
| `bug-fix` | "fix bug", "resolve issue", "hotfix" | Structured bug fix workflow with regression tests |
| `ci-cd-pipeline` | "update pipeline", "fix pipeline", "modify CI" | CI/CD pipeline modifications |
| `infrastructure` | "update Dockerfile", "modify Helm chart", "upgrade base image" | Container and infrastructure changes |
| `feature-development` | "add feature", "implement", "new stream" | New feature scaffolding |
| `test-authoring` | "add test", "write test" | Test creation following repo patterns |
| `documentation` | "update docs", "release notes", "write README" | Documentation updates |

**Example usage:**
```
# In Copilot Chat, just describe the task:
"Fix the critical CVE in our Go dependencies"
"Add telemetry to the new network flow log handler"
"Update the Dockerfile to Fluent Bit 4.1"
"Add a unit test for the container inventory plugin"
```

## Using Prompt.md for New Work

`Prompt.md` is a reusable template for describing new tasks or features. Copy it and fill in sections when starting complex work.

## MCP Server Integration

The `.vscode/mcp.json` configures:
- **GitHub MCP:** PR management, issues, and branch operations from chat.
- **Microsoft Docs MCP:** Azure documentation search for validating patterns against official docs.

## Tips for Maximum Productivity

1. **Let auto-loading work** — Just open the file. Language-specific rules activate automatically.
2. **Use natural language** — Don't invoke skills by name. Just describe: "add a test", "fix the CVE".
3. **Start reviews with @CodeReviewer** — It knows the team's patterns, linter rules, and security requirements.
4. **Use @prd before big features** — A structured PRD helps scope the work before writing code.
5. **Check AGENTS.md for setup** — If the AI struggles with build commands, verify they match your environment.

## Customizing These Artifacts

These files evolve with the project:
- **Add rules** to `.instructions.md` when new conventions are established.
- **Add skills** when you identify recurring workflows.
- **Update `copilot-instructions.md`** when build commands or project structure change.
- **Re-run generation** periodically to refresh skills from commit patterns.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow Go conventions | Check `.github/instructions/go.instructions.md` `applyTo` matches `**/*.go` |
| Skill not activating | Use exact trigger phrases from the skill table above |
| Agent not available | Ensure `.github/agents/*.agent.md` files exist |
| Build commands fail | Update Setup Commands in `AGENTS.md` to match current environment |
| Trivy scan fails | Run `trivy image --severity CRITICAL,HIGH --ignore-unfixed <image>` locally |
