# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for the Docker-Provider repository. These artifacts make AI assistants (GitHub Copilot, Google Jules, Gemini CLI, Cursor, etc.) understand this codebase deeply and contribute effectively.

## Quick Start

1. Open this repository in VS Code (or your preferred editor with Copilot/AI assistant support).
2. The AI assistant automatically loads `.github/copilot-instructions.md` on every session — no action needed.
3. When you open a `.go`, `.rb`, `.sh`, or `.ps1` file, the corresponding `.instructions.md` file auto-activates.
4. Invoke skills by typing their trigger phrases in chat (e.g., "add test", "fix bug", "security review").
5. Invoke agents by @-mentioning them in chat (e.g., `@CodeReviewer`, `@DocumentWriter`).

## Generated Artifacts Overview

| Artifact | Path | Loaded | Purpose |
|----------|------|--------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Automatically every session | Root router — general rules, build commands, skill catalogue |
| `AGENTS.md` | Root | Automatically (supported tools) | Setup commands, code style, testing instructions, architecture |
| `.instructions.md` files | `.github/instructions/` | Auto on file match (`applyTo` glob) | Language-specific coding conventions |
| `Prompt.md` | Root | On demand | Reusable task-spec template for describing new work |
| Skill files (`SKILL.md`) | `.github/skills/` | On keyword trigger | Step-by-step guides for recurring development tasks |
| `CodeReviewer.agent.md` | `.github/agents/CodeReviewer.agent.md` | On @-mention | Structured code review following repo conventions |
| `SecurityReviewer.agent.md` | `.github/agents/SecurityReviewer.agent.md` | On @-mention | Deep security analysis, threat modeling, STRIDE review |
| `DocumentWriter.agent.md` | `.github/agents/DocumentWriter.agent.md` | On @-mention | Documentation authoring following repo doc standards |
| `prd.agent.md` | `.github/agents/prd.agent.md` | On @-mention | PRD generation tailored to this project's architecture |
| `.vscode/mcp.json` | `.vscode/mcp.json` | Automatically by VS Code | MCP server connections (GitHub, Microsoft Docs) |
| `test/AGENTS.md` | `test/AGENTS.md` | Automatically (supported tools) | Test framework guide and decision tree |

## How the Context Loading Chain Works

```
Layer 1: .github/copilot-instructions.md (always loaded)
  ├── General rules, build commands, skill catalogue
  ├── Routes to →
  │
Layer 2: .github/instructions/*.instructions.md (auto-loaded on file match)
  ├── go.instructions.md — Go coding conventions (*.go files)
  ├── ruby.instructions.md — Ruby coding conventions (*.rb files)
  ├── shell.instructions.md — Shell conventions (*.sh files)
  ├── powershell.instructions.md — PowerShell conventions (*.ps1/*.psm1 files)
  │
Layer 3: Skills (loaded only when invoked by trigger phrase)
  └── Step-by-step procedures for specific tasks
```

**You don't need to manually load anything.** The system activates automatically based on what file you're editing and what you ask the AI to do.

## Using Custom Agents

### @CodeReviewer
- **Invoke:** Type `@CodeReviewer` in Copilot Chat.
- **What it does:** Performs structured code reviews covering correctness, STRIDE security, telemetry gaps, and adherence to Ruby/Go/Shell/PowerShell conventions.
- **Example prompts:**
  - `@CodeReviewer review this PR`
  - `@CodeReviewer check this file for security issues`
  - `@CodeReviewer review my changes for telemetry gaps`

### @DocumentWriter
- **Invoke:** Type `@DocumentWriter` in Copilot Chat.
- **What it does:** Creates and maintains documentation following the project's doc structure and conventions.
- **Example prompts:**
  - `@DocumentWriter write a README for this module`
  - `@DocumentWriter update the release notes for 3.1.36`

### @SecurityReviewer
- **Invoke:** Type `@SecurityReviewer` in Copilot Chat.
- **What it does:** Deep security assessments including threat modeling, attack surface analysis for the Kubernetes agent, and STRIDE analysis.
- **Example prompts:**
  - `@SecurityReviewer review the authentication changes in this PR`
  - `@SecurityReviewer assess the security of our new data stream`
  - `@SecurityReviewer audit the container security configuration`

### @prd (PRD Generator)
- **Invoke:** Type `@prd` in Copilot Chat.
- **What it does:** Generates structured Product Requirements Documents tailored to this project's Kubernetes monitoring architecture.
- **Example prompts:**
  - `@prd create a PRD for adding Windows container log filtering`
  - `@prd write requirements for a new Prometheus scraping feature`

## Using Skills

Skills are step-by-step guides that activate when you use their trigger phrases in chat.

### Always-Available Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `security-review` | "security review", "threat model", "STRIDE analysis" | STRIDE-based security review with credential scanning |
| `telemetry-authoring` | "add telemetry", "add metrics", "instrument code" | Add Application Insights telemetry following existing patterns |
| `fix-critical-vulnerabilities` | "fix CVE", "trivy fix", "vulnerability fix" | Fix critical/high CVEs using Trivy scan results |

### Commit-History-Driven Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `dependency-update` | "update dependency", "bump package" | Safe dependency update (Go modules, Dockerfile packages) |
| `test-authoring` | "add test", "write test" | Create tests across Go, Ruby, Bash, and PowerShell |
| `bug-fix` | "fix bug", "resolve issue", "hotfix" | Structured bug fix with regression test |
| `feature-development` | "add feature", "implement", "new plugin" | New feature scaffolding for the agent |
| `code-refactoring` | "refactor", "restructure", "rename" | Behavior-preserving refactoring workflow |
| `infrastructure` | "update Dockerfile", "Helm chart", "k8s manifest" | Infrastructure change workflow |

**Example usage:**
```
# In Copilot Chat, just describe the task naturally:
"Add a test for the network flow log processing"
"Fix the critical CVEs in our container image"
"Add telemetry to the new Kubernetes event handler"
"Update the Fluent Bit version in the Dockerfile"
```

## Using Prompt.md for New Work

`Prompt.md` is a reusable template for describing new tasks or features. Use it when:
- Starting a new feature and want to give the AI full context.
- Handing off a task specification to another developer or AI agent.

**How to use:**
1. Copy `Prompt.md` to a new file (e.g., `feature-xyz-prompt.md`).
2. Fill in the sections with your specific requirements.
3. Reference it in Copilot Chat: "Implement the feature described in feature-xyz-prompt.md".

## Using AGENTS.md

`AGENTS.md` provides setup, style, and testing instructions. Most AI tools load it automatically. It's useful for:
- **Onboarding:** Follow Setup Commands to get a working build environment.
- **Consistency:** Code Style section ensures AI-generated code matches repo conventions.
- **PR readiness:** PR Instructions help format commits correctly.

## MCP Server Integration

The `.vscode/mcp.json` configures connections to external data sources:
- **GitHub MCP:** Enables PR creation, issue management, and branch operations from chat.
- **Microsoft Docs MCP:** Enables validation against official Azure Monitor documentation.

MCP servers use `${input:variable}` prompts — you'll be asked for credentials on first use.

## Tips for Maximum Productivity

1. **Let auto-loading work for you** — Just open the file you're working on. The `.instructions.md` files activate based on file type.
2. **Use natural language for skills** — Don't invoke skills by name. Just say "add a test" or "fix this CVE".
3. **Start reviews with @CodeReviewer** — It knows the STRIDE checklist, telemetry patterns, and language conventions.
4. **Use @prd before big features** — A structured PRD helps scope work before writing code.
5. **Check AGENTS.md for setup** — If the AI struggles with builds, verify Setup Commands.
6. **Trust the context chain** — The layered system ensures the right context at the right time.

## Customizing These Artifacts

These files evolve with the project:
- **Add rules** to `.instructions.md` files when new conventions are established.
- **Add skills** when you identify new recurring workflows (create a `SKILL.md` in `.github/skills/`).
- **Update `copilot-instructions.md`** when build commands or project structure changes.
- **Update `AGENTS.md`** when setup commands or test strategies change.
- **Re-run generation** periodically to pick up new commit patterns and refresh skills.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow coding conventions | Verify `.instructions.md` `applyTo` glob matches the file type you're editing |
| Skill not activating | Use exact trigger phrases from the skills table |
| Agent not available | Ensure `.agent.md` file is in `.github/agents/` |
| MCP server not connecting | Check `.vscode/mcp.json` config and provide credentials when prompted |
| AI gives generic advice | It may not be loading `copilot-instructions.md` — verify the file exists at `.github/copilot-instructions.md` |
| Build/test commands fail | Update Setup Commands in `AGENTS.md` to match your environment |
