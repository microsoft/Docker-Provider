# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for the Azure Monitor for containers agent repository. These artifacts make AI assistants (GitHub Copilot, Google Jules, Gemini CLI, Cursor, etc.) understand your codebase deeply and contribute effectively.

## Quick Start

1. Open this repository in VS Code (or your preferred editor with Copilot/AI assistant support).
2. The AI assistant automatically loads `copilot-instructions.md` on every session — no action needed.
3. When you open a file matching a language pattern (`.go`, `.rb`, `.sh`), the corresponding `.instructions.md` file auto-activates.
4. Invoke skills by typing their trigger phrases in chat (e.g., "add test", "fix bug", "security review").
5. Invoke agents by @-mentioning them in chat (e.g., `@CodeReviewer`, `@DocumentWriter`).

## Generated Artifacts Overview

| Artifact | Path | Loaded | Purpose |
|----------|------|--------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Automatically every session | Root router — general rules, build instructions, known patterns |
| `AGENTS.md` | Root | Automatically (supported tools) | Setup commands, code style, testing instructions, architecture diagram |
| `.instructions.md` files | `.github/instructions/` | Auto on file match (`applyTo` glob) | Language-specific coding rules (Go, Ruby, Shell) |
| `Prompt.md` | Root | On demand | Reusable task-spec template for describing new work |
| Skill files (`SKILL.md`) | `.github/skills/` | On keyword trigger | Step-by-step guides for recurring development tasks |
| `CodeReviewer.agent.md` | `.github/agents/CodeReviewer.agent.md` | On @-mention | Structured code review following repo conventions |
| `SecurityReviewer.agent.md` | `.github/agents/SecurityReviewer.agent.md` | On @-mention | Deep security analysis, threat modeling, attack surface review |
| `ThreatModelAnalyst.agent.md` | `.github/agents/ThreatModelAnalyst.agent.md` | On @-mention | STRIDE threat modeling with Mermaid diagrams under `threat-model/` |
| `DocumentWriter.agent.md` | `.github/agents/DocumentWriter.agent.md` | On @-mention | Documentation authoring following repo doc standards |
| `prd.agent.md` | `.github/agents/prd.agent.md` | On @-mention | PRD generation tailored to this project's architecture |
| `.vscode/mcp.json` | `.vscode/mcp.json` | Automatically by VS Code | MCP server connections (GitHub, Microsoft Docs) |
| `test/AGENTS.md` | `test/AGENTS.md` | Automatically in test directory | Test framework guide and decision tree |

## How the Context Loading Chain Works

```
Layer 1: copilot-instructions.md (always loaded)
  ├── General rules, build instructions, known patterns
  ├── Routes to →
  │
Layer 2: .instructions.md files (auto-loaded when you open matching files)
  ├── go.instructions.md — Go coding rules (*.go files)
  ├── ruby.instructions.md — Ruby coding rules (*.rb files)
  ├── shell.instructions.md — Shell scripting rules (*.sh files)
  │
Layer 3: Skills (loaded only when invoked by trigger phrase)
  └── Step-by-step procedures for specific tasks
```

## Using Custom Agents

### @CodeReviewer
- **Invoke:** Type `@CodeReviewer` in Copilot Chat.
- **What it does:** Performs structured code reviews covering correctness, style, security (STRIDE), telemetry gaps, and adherence to project conventions.
- **Example prompts:**
  - `@CodeReviewer review this PR`
  - `@CodeReviewer check this file for security issues`
  - `@CodeReviewer review my changes for telemetry gaps`

### @DocumentWriter
- **Invoke:** Type `@DocumentWriter` in Copilot Chat.
- **What it does:** Creates and maintains documentation following repo conventions and structure.
- **Example prompts:**
  - `@DocumentWriter write release notes for version 3.1.36`
  - `@DocumentWriter update the README with the new network flow logs feature`

### @SecurityReviewer
- **Invoke:** Type `@SecurityReviewer` in Copilot Chat.
- **What it does:** Performs deep security assessments including STRIDE analysis, dependency auditing, and infrastructure review.
- **Example prompts:**
  - `@SecurityReviewer review the authentication changes in this PR`
  - `@SecurityReviewer assess the attack surface of our Fluent Bit configuration`

### @ThreatModelAnalyst
- **Invoke:** Type `@ThreatModelAnalyst` in Copilot Chat.
- **What it does:** Generates persistent threat model artifacts under `threat-model/YYYY-MM-DD/`.
- **Example prompts:**
  - `@ThreatModelAnalyst perform a full threat model analysis`
  - `@ThreatModelAnalyst analyze the Kubernetes RBAC and secrets management`

### @prd (PRD Generator)
- **Invoke:** Type `@prd` in Copilot Chat.
- **What it does:** Generates structured Product Requirements Documents tailored to the container agent architecture.
- **Example prompts:**
  - `@prd create a PRD for adding OpenTelemetry trace collection`
  - `@prd write requirements for a new health check endpoint`

## Using Skills

Skills are step-by-step guides that activate when you use their trigger phrases in chat.

### Always-Available Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `security-review` | "security review", "STRIDE analysis", "credential leak check" | STRIDE-based security review with credential scanning |
| `telemetry-authoring` | "add telemetry", "add metrics", "instrument code" | Guides adding telemetry following existing AppInsights patterns |
| `fix-critical-vulnerabilities` | "fix critical vulnerability", "CVE fix", "trivy fix" | Identifies and fixes CVEs using repo's scanning tools |

### Commit-History-Driven Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `dependency-update` | "update dependency", "bump package" | Safe dependency updates with proper testing |
| `bug-fix` | "fix bug", "resolve issue", "hotfix" | Structured bug fix workflow with regression testing |
| `feature-development` | "add feature", "implement", "new plugin" | New feature scaffolding — plugin development, config, tests |
| `test-authoring` | "add test", "write test" | Creates tests following repo conventions |
| `documentation` | "update docs", "release notes" | Documentation updates following existing patterns |
| `ci-cd-pipeline` | "modify CI", "update pipeline" | CI/CD pipeline configuration changes |
| `infrastructure` | "update Dockerfile", "modify Helm chart" | Container and deployment infrastructure changes |
| `security-patch` | "security fix", "CVE patch" | Security vulnerability remediation |

## Using Prompt.md for New Work

`Prompt.md` is a reusable template for describing new tasks or features. Copy it, fill in the sections, and reference it in Copilot Chat.

## MCP Server Integration

The `.vscode/mcp.json` file configures two MCP servers:
- **GitHub MCP:** Enables PR management, issue tracking, and branch operations from chat.
- **Microsoft Docs MCP:** Enables searching official Azure Monitor documentation for validation.

Secrets use `${input:variable}` prompts — you'll be asked for credentials on first use.

## Tips for Maximum Productivity

1. **Let auto-loading work for you** — Just open the file you're working on. The `.instructions.md` files activate automatically.
2. **Use natural language for skills** — Just describe the task: "add a test", "bump dependencies", "review security".
3. **Start reviews with @CodeReviewer** — It knows the review patterns, linter rules, and security requirements.
4. **Use @prd before big features** — A structured PRD helps plan the full scope before coding.
5. **Check AGENTS.md for setup** — Verify Setup Commands are accurate for your environment.
6. **Check test/AGENTS.md for testing** — Use the decision tree to pick the right test framework.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow coding conventions | Verify `.instructions.md` `applyTo` glob matches the file you're editing |
| Skill not activating | Use the exact trigger phrases listed in the skill table above |
| Agent not available | Ensure the `.agent.md` file is in `.github/agents/` |
| MCP server not connecting | Check `.vscode/mcp.json` config and provide credentials when prompted |
| Build commands fail | Update the Setup Commands section in `AGENTS.md` to match your environment |
