# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for the Docker-Provider repository. These artifacts make AI assistants (GitHub Copilot, Google Jules, Gemini CLI, Cursor, etc.) understand your codebase deeply and contribute effectively.

## Quick Start

1. Open this repository in VS Code (or your preferred editor with Copilot/AI assistant support).
2. The AI assistant automatically loads `.github/copilot-instructions.md` on every session — no action needed.
3. When you open a file matching a language pattern (`.rb`, `.go`, `.sh`, `.ps1`), the corresponding `.instructions.md` file auto-activates.
4. Invoke skills by typing their trigger phrases in chat (e.g., "add test", "fix bug", "security review").
5. Invoke agents by @-mentioning them in chat (e.g., `@CodeReviewer`, `@DocumentWriter`).

## Generated Artifacts Overview

| Artifact | Path | Loaded | Purpose |
|----------|------|--------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Automatically every session | Root router — general rules, skill catalogue |
| `AGENTS.md` | Root | Automatically (supported tools) | Setup commands, code style, testing, architecture |
| `ruby.instructions.md` | `.github/instructions/` | Auto on `**/*.rb` match | Ruby coding conventions |
| `go.instructions.md` | `.github/instructions/` | Auto on `**/*.go` match | Go coding conventions |
| `shell.instructions.md` | `.github/instructions/` | Auto on `**/*.sh` match | Shell/Bash coding conventions |
| `powershell.instructions.md` | `.github/instructions/` | Auto on `**/*.ps1` match | PowerShell coding conventions |
| `Prompt.md` | Root | On demand | Reusable task-spec template |
| Skill files (`SKILL.md`) | `.github/skills/<name>/` | On keyword trigger | Step-by-step development guides |
| `CodeReviewer.agent.md` | `.github/agents/` | On @-mention | Structured code review |
| `SecurityReviewer.agent.md` | `.github/agents/` | On @-mention | Deep security analysis |
| `ThreatModelAnalyst.agent.md` | `.github/agents/` | On @-mention | STRIDE threat modeling with Mermaid diagrams |
| `DocumentWriter.agent.md` | `.github/agents/` | On @-mention | Documentation authoring |
| `prd.agent.md` | `.github/agents/` | On @-mention | PRD generation |
| `.vscode/mcp.json` | `.vscode/mcp.json` | Automatically by VS Code | MCP server configuration |
| `test/AGENTS.md` | `test/AGENTS.md` | When working in test directory | Test framework guide and decision tree |

## How the Context Loading Chain Works

```
Layer 1: copilot-instructions.md (always loaded)
  ├── General rules, skill catalogue, build instructions
  ├── Routes to →
  │
Layer 2: .instructions.md files (auto-loaded when you open matching files)
  ├── Language-specific coding rules (Ruby, Go, Shell, PowerShell)
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

### @SecurityReviewer
- **Invoke:** Type `@SecurityReviewer` in Copilot Chat.
- **What it does:** Performs deep security assessments including threat modeling, attack surface analysis, STRIDE deep-dive, and dependency security auditing.
- **Example prompts:**
  - `@SecurityReviewer perform a security review of the authentication changes`
  - `@SecurityReviewer assess the attack surface of our new Kubernetes RBAC changes`
  - `@SecurityReviewer audit our container security configuration`

### @ThreatModelAnalyst
- **Invoke:** Type `@ThreatModelAnalyst` in Copilot Chat.
- **What it does:** Generates comprehensive, persistent threat model artifacts — Mermaid architecture diagrams with security boundaries, full STRIDE analysis matrices, and prioritized threat catalogues under `threat-model/YYYY-MM-DD/`.
- **Example prompts:**
  - `@ThreatModelAnalyst perform a full threat model analysis`
  - `@ThreatModelAnalyst threat model the log ingestion pipeline`
  - `@ThreatModelAnalyst analyze the Kubernetes RBAC and secrets management`

### @DocumentWriter
- **Invoke:** Type `@DocumentWriter` in Copilot Chat.
- **What it does:** Creates and maintains documentation following this repo's conventions.
- **Example prompts:**
  - `@DocumentWriter write release notes for version 3.1.36`
  - `@DocumentWriter update the README with new prerequisites`

### @prd (PRD Generator)
- **Invoke:** Type `@prd` in Copilot Chat.
- **What it does:** Generates structured Product Requirements Documents tailored to this project's architecture.
- **Example prompts:**
  - `@prd create a PRD for adding OpenTelemetry trace export`
  - `@prd write requirements for the new multi-tenant logging feature`

## Using Skills

Skills are invoked automatically when you describe a task using natural language. Available skills:

| Skill | Trigger Phrases | Description |
|-------|----------------|-------------|
| `dependency-update` | "bump package", "update go.mod", "upgrade fluent-bit" | Update Go modules, Ruby gems, or base images |
| `bug-fix` | "fix bug", "patch", "hotfix", "debug" | Fix bugs with regression tests |
| `feature-development` | "add feature", "implement", "new plugin" | Add new features following repo patterns |
| `ci-cd-pipeline` | "update pipeline", "fix CI", "migrate workflow" | Modify CI/CD workflows |
| `infrastructure` | "update Dockerfile", "Helm chart", "k8s manifest" | Modify container/deployment infrastructure |
| `test-authoring` | "add test", "write test", "increase coverage" | Add unit, E2E, or Ginkgo tests |
| `documentation` | "update docs", "release notes", "write README" | Update documentation |
| `security-review` | "security review", "STRIDE", "credential check" | STRIDE-based security review |
| `telemetry-authoring` | "add telemetry", "add metrics", "instrument code" | Add Application Insights telemetry |
| `fix-critical-vulnerabilities` | "fix CVE", "patch vulnerability", "trivy fix" | Fix critical/high vulnerabilities |

## Using Prompt.md for New Work

`Prompt.md` is a reusable template for describing new tasks or features. Use it when:
- Starting a new feature and want to give the AI full context
- Creating a structured brief for a complex change

**How to use:**
1. Copy `Prompt.md` to a new file (e.g., `feature-xyz-prompt.md`)
2. Fill in the sections with your specific requirements
3. Reference it in Copilot Chat: "Implement the feature described in feature-xyz-prompt.md"

## MCP Server Integration

The `.vscode/mcp.json` file configures connections to external data sources:
- **GitHub MCP:** Enables PR creation, issue management, and branch operations from chat.
- **Microsoft Docs MCP:** Enables validation of Azure patterns against official documentation.

MCP servers use `${input:variable}` prompts — you'll be asked for credentials on first use.

## Tips for Maximum Productivity

1. **Let auto-loading work** — Just open the file you're editing. Language-specific rules activate automatically.
2. **Use natural language for skills** — Just describe the task: "add a test for the liveness probe handler".
3. **Start reviews with @CodeReviewer** — It knows the repo's review patterns, linter rules, and security requirements.
4. **Use @prd before big features** — A structured PRD helps plan the implementation scope.
5. **Check test/AGENTS.md for test patterns** — The test decision tree helps choose the right test type.
6. **Check AGENTS.md for setup** — If the AI struggles with build commands, verify Setup Commands are accurate.

## Customizing These Artifacts

These files evolve with your project:
- **Add rules** to `.instructions.md` when new coding conventions are established.
- **Add skills** for new recurring workflows (create `SKILL.md` in `.github/skills/<name>/`).
- **Update `copilot-instructions.md`** when project structure or build commands change.
- **Update `AGENTS.md`** when setup commands or test strategies change.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow coding conventions | Verify `.instructions.md` `applyTo` glob matches your file |
| Skill not activating | Use trigger phrases from the skills table above |
| Agent not available | Ensure `.agent.md` file is in `.github/agents/` |
| MCP server not connecting | Check `.vscode/mcp.json` and provide credentials when prompted |
| Build/test commands fail | Update Setup Commands in `AGENTS.md` |
