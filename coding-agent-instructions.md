# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for this repository. These artifacts make AI assistants (GitHub Copilot, Google Jules, Gemini CLI, Cursor, etc.) understand your codebase deeply and contribute effectively.

## Quick Start

1. Open this repository in VS Code (or your preferred editor with Copilot/AI assistant support).
2. The AI assistant automatically loads `copilot-instructions.md` on every session — no action needed.
3. When you open a file matching a language pattern, the corresponding `.instructions.md` file auto-activates.
4. Invoke skills by typing their trigger phrases in chat (e.g., "add test", "fix bug", "security review").
5. Invoke agents by @-mentioning them in chat (e.g., `@CodeReviewer`, `@DocumentWriter`).

## Generated Artifacts Overview

| Artifact | Path | Loaded | Purpose |
|----------|------|--------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Automatically every session | Root router — general rules, skill catalogue, build instructions |
| `AGENTS.md` | Root | Automatically (supported tools) | Setup commands, code style, testing instructions, architecture |
| `.instructions.md` files | `.github/instructions/` | Auto on file match (`applyTo` glob) | Language-specific coding rules (Ruby, Go, Shell, PowerShell) |
| `Prompt.md` | Root | On demand | Reusable task-spec template for describing new work |
| Skill files (`SKILL.md`) | `.github/skills/` | On keyword trigger | Step-by-step guides for recurring development tasks |
| `CodeReviewer.agent.md` | `.github/agents/` | On @-mention | Structured code review following repo conventions |
| `SecurityReviewer.agent.md` | `.github/agents/` | On @-mention | Deep security analysis, threat modeling, STRIDE review |
| `DocumentWriter.agent.md` | `.github/agents/` | On @-mention | Documentation authoring following repo standards |
| `prd.agent.md` | `.github/agents/` | On @-mention | PRD generation tailored to this project |
| `.vscode/mcp.json` | `.vscode/mcp.json` | Automatically by VS Code | MCP server connections (GitHub, Microsoft Docs) |

## How the Context Loading Chain Works

```
Layer 1: copilot-instructions.md (always loaded)
  ├── General rules, skill catalogue, build instructions
  ├── Routes to →
  │
Layer 2: .instructions.md files (auto-loaded when you open matching files)
  ├── ruby.instructions.md → *.rb files
  ├── go.instructions.md → *.go files
  ├── shell.instructions.md → *.sh files
  ├── powershell.instructions.md → *.ps1 files
  │
Layer 3: Skills (loaded only when invoked by trigger phrase)
  └── Step-by-step procedures for specific tasks
```

**You don't need to manually load anything.** The system activates automatically based on what file you're editing and what you ask the AI to do.

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
- **What it does:** Creates and maintains documentation following this repo's structure and conventions.
- **Example prompts:**
  - `@DocumentWriter write release notes for version 3.1.36`
  - `@DocumentWriter update the README for this module`

### @SecurityReviewer
- **Invoke:** Type `@SecurityReviewer` in Copilot Chat.
- **What it does:** Performs deep security assessments including STRIDE threat modeling, attack surface analysis, dependency auditing, and infrastructure security review.
- **Example prompts:**
  - `@SecurityReviewer perform a threat model for the Go output plugin`
  - `@SecurityReviewer review the Dockerfile security configuration`
  - `@SecurityReviewer audit our container security context`
- **When to use vs. @CodeReviewer:** Use `@SecurityReviewer` for dedicated, deep security analysis. The CodeReviewer applies a lightweight security checklist during routine reviews.

### @prd (PRD Generator)
- **Invoke:** Type `@prd` in Copilot Chat.
- **What it does:** Generates structured Product Requirements Documents tailored to this project's architecture and tech stack.
- **Example prompts:**
  - `@prd create a PRD for adding network flow log support`
  - `@prd write requirements for a new telemetry stream`

## Using Skills

Skills are step-by-step guides that activate when you use their trigger phrases in chat.

### Always-Available Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `security-review` | "security review", "threat model", "STRIDE analysis" | STRIDE-based security review with credential scanning |
| `telemetry-authoring` | "add telemetry", "add metrics", "instrument code" | Add Application Insights telemetry following existing patterns |
| `fix-critical-vulnerabilities` | "fix CVE", "trivy fix", "patch vulnerability" | Fix critical/high vulnerabilities using repo scanning tools |

### Commit-History-Driven Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `dependency-update` | "update dependency", "bump package" | Update Go modules and system packages safely |
| `bug-fix` | "fix bug", "resolve issue", "hotfix" | Structured bug fix with regression test requirement |
| `feature-development` | "add feature", "implement", "new plugin" | New feature scaffolding for plugins and components |
| `test-authoring` | "add test", "write test" | Create tests following repo conventions (Bash/Go/Ruby/PS) |
| `ci-cd-pipeline` | "update pipeline", "modify workflow" | CI/CD and Azure Pipeline changes |
| `infrastructure` | "update Dockerfile", "modify Helm chart" | Container, Helm, and Kubernetes changes |
| `code-refactoring` | "refactor", "restructure", "rename" | Code refactoring workflow |
| `security-patch` | "security fix", "CVE patch" | Security-specific code fixes |
| `documentation` | "update docs", "write release notes" | Documentation and release notes updates |

**Example usage:**
```
# In Copilot Chat, just describe the task naturally:
"Add a test for the new Ruby inventory plugin"
"Fix the critical CVE in our Go dependencies"
"Add telemetry to the network flow log handler"
"Update the Fluent Bit version in the Dockerfile"
```

## Using Prompt.md for New Work

`Prompt.md` is a reusable template for describing new tasks or features. Use it when:
- Starting a new feature and want to give the AI full context.
- Handing off a task specification to another developer or AI agent.
- Creating a structured brief for a complex change.

**How to use:**
1. Copy `Prompt.md` to a new file (e.g., `feature-xyz-prompt.md`).
2. Fill in the sections with your specific requirements.
3. Reference it in Copilot Chat: "Implement the feature described in feature-xyz-prompt.md".

## Using AGENTS.md

`AGENTS.md` provides setup, style, and testing instructions. Most AI tools load it automatically. It's useful for:
- **Onboarding:** Follow the Setup Commands to get a working build environment.
- **Consistency:** Code Style sections ensure AI-generated code matches repo conventions.
- **PR readiness:** PR Instructions help format commits and PRs correctly.

## MCP Server Integration

The `.vscode/mcp.json` file configures connections to external data sources:
- **GitHub MCP:** Enables PR management, issue tracking, and branch operations directly from chat.
- **Microsoft Docs MCP:** Enables validation of Azure SDK usage against official Microsoft documentation.

MCP servers are configured in `.vscode/mcp.json`. Secrets use `${input:variable}` prompts — you'll be asked for credentials on first use.

## Tips for Maximum Productivity

1. **Let auto-loading work for you** — Just open the file you're working on. The `.instructions.md` files activate automatically based on file type.
2. **Use natural language for skills** — Don't invoke skills by name. Just describe the task: "add a test", "bump dependencies", "review security".
3. **Start reviews with @CodeReviewer** — It knows the repo's review patterns, linter rules, and security requirements.
4. **Use @prd before big features** — A structured PRD helps the AI and your team understand the full scope before writing code.
5. **Reference Prompt.md for complex tasks** — When a task needs more context than a chat message, fill in a copy of Prompt.md.
6. **Check AGENTS.md for setup** — If the AI struggles with build or test commands, verify the Setup Commands in AGENTS.md.

## Customizing These Artifacts

These files are meant to evolve with your project:
- **Add rules** to `.instructions.md` files when you establish new coding conventions.
- **Add skills** when you identify a new recurring workflow (create a `SKILL.md` in `.github/skills/`).
- **Update `copilot-instructions.md`** when project structure or build commands change.
- **Update `AGENTS.md`** when setup commands, test strategies, or dev environment requirements change.
- **Re-run generation** periodically (e.g., quarterly) to pick up new commit patterns.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow coding conventions | Verify `.instructions.md` `applyTo` glob matches the file you're editing |
| Skill not activating | Use the exact trigger phrases listed in the skill table above |
| Agent not available | Ensure the `.agent.md` file is in `.github/agents/` |
| MCP server not connecting | Check `.vscode/mcp.json` config and provide credentials when prompted |
| AI gives generic advice | It may not be loading `copilot-instructions.md` — verify the file exists in `.github/` |
| Build/test commands fail | Update the Setup Commands section in `AGENTS.md` to match your current environment |
