# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for the Azure Monitor Container Insights agent repository. These artifacts make AI assistants (GitHub Copilot, Google Jules, Gemini CLI, Cursor, etc.) understand your codebase deeply and contribute effectively.

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
| `AGENTS.md` | Root | Automatically (supported tools) | Setup commands, code style, testing instructions, architecture diagram |
| Go instructions | `.github/instructions/go.instructions.md` | Auto on `**/*.go` | Go coding conventions for Fluent Bit plugins |
| Ruby instructions | `.github/instructions/ruby.instructions.md` | Auto on `**/*.rb` | Ruby conventions for Fluentd plugins |
| Shell instructions | `.github/instructions/shell.instructions.md` | Auto on `**/*.sh` | Shell script conventions |
| PowerShell instructions | `.github/instructions/powershell.instructions.md` | Auto on `**/*.ps1` | PowerShell conventions |
| `Prompt.md` | Root | On demand | Reusable task-spec template for new work |
| `CodeReviewer.agent.md` | `.github/agents/CodeReviewer.agent.md` | On @-mention | Structured code review with STRIDE security checks |
| `SecurityReviewer.agent.md` | `.github/agents/SecurityReviewer.agent.md` | On @-mention | Deep security analysis and threat modeling |
| `DocumentWriter.agent.md` | `.github/agents/DocumentWriter.agent.md` | On @-mention | Documentation authoring following repo conventions |
| `prd.agent.md` | `.github/agents/prd.agent.md` | On @-mention | PRD generation tailored to this project |
| Test AGENTS.md | `test/AGENTS.md` | Auto in test directories | Test framework guide and decision tree |

## How the Context Loading Chain Works

```
Layer 1: .github/copilot-instructions.md (always loaded)
  ├── General rules, skill catalogue, build instructions
  ├── Routes to →
  │
Layer 2: .github/instructions/*.instructions.md (auto-loaded when you open matching files)
  ├── go.instructions.md → Go plugin conventions
  ├── ruby.instructions.md → Ruby plugin conventions
  ├── shell.instructions.md → Shell script conventions
  ├── powershell.instructions.md → PowerShell conventions
  │
Layer 3: Skills (loaded only when invoked by trigger phrase)
  └── Step-by-step procedures for specific tasks
```

## Using Custom Agents

### @CodeReviewer
- **Invoke:** Type `@CodeReviewer` in Copilot Chat.
- **What it does:** Performs structured code reviews covering correctness, style, STRIDE security checklist, telemetry gaps, and adherence to project conventions.
- **Example prompts:**
  - `@CodeReviewer review this PR`
  - `@CodeReviewer check this file for security issues`
  - `@CodeReviewer review my changes for telemetry gaps`

### @SecurityReviewer
- **Invoke:** Type `@SecurityReviewer` in Copilot Chat.
- **What it does:** Performs deep security assessments including threat modeling, attack surface analysis, and STRIDE deep-dive for the Container Insights agent.
- **Example prompts:**
  - `@SecurityReviewer review the authentication changes in this PR`
  - `@SecurityReviewer assess the Dockerfile security configuration`
  - `@SecurityReviewer audit our Helm chart RBAC definitions`

### @DocumentWriter
- **Invoke:** Type `@DocumentWriter` in Copilot Chat.
- **What it does:** Creates and maintains documentation following this repo's doc structure and conventions.
- **Example prompts:**
  - `@DocumentWriter write release notes for version 3.1.36`
  - `@DocumentWriter update the README with new prerequisites`

### @prd (PRD Generator)
- **Invoke:** Type `@prd` in Copilot Chat.
- **What it does:** Generates structured Product Requirements Documents tailored to the Container Insights agent architecture.
- **Example prompts:**
  - `@prd create a PRD for adding OpenTelemetry metrics support`
  - `@prd write requirements for a new log filtering feature`

## Using Skills

Skills are step-by-step guides that activate when you use their trigger phrases in chat.

### Always-Available Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `security-review` | "security review", "threat model", "STRIDE analysis" | STRIDE-based security review with credential scanning |
| `telemetry-authoring` | "add telemetry", "add metrics", "instrument code" | Add Application Insights telemetry following existing patterns |
| `fix-critical-vulnerabilities` | "fix CVE", "trivy fix", "patch vulnerability" | Fix critical/high CVEs using Trivy and repo scanning tools |

### Commit-History-Driven Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `dependency-update` | "update dependency", "bump package" | Update Go modules, Ruby gems, or base images safely |
| `bug-fix` | "fix bug", "resolve issue", "hotfix" | Structured bug fix workflow with regression test |
| `feature-development` | "add feature", "implement", "new plugin" | New feature scaffolding for Go/Ruby plugins |
| `test-authoring` | "add test", "write test" | Create tests following repo test framework conventions |
| `ci-cd-pipeline` | "update pipeline", "fix CI" | Modify GitHub Actions or Azure Pipelines |
| `infrastructure` | "update Dockerfile", "Helm chart" | Infrastructure and deployment changes |
| `documentation` | "update docs", "release notes" | Documentation and release note updates |

**Example usage:**
```
# In Copilot Chat, just describe the task naturally:
"Add a test for the network flow logs feature"
"Fix the critical CVE in our container image"
"Add telemetry to the new OTLP handler"
"Update Fluent Bit to the latest version"
```

## Using Prompt.md for New Work

`Prompt.md` is a reusable template for describing new tasks or features. Use it when:
- Starting a new feature and want to give the AI full context.
- Handing off a task specification to another developer or AI agent.
- Creating a structured brief for a complex change.

## Using AGENTS.md

`AGENTS.md` provides setup, style, and testing instructions. Most AI tools load it automatically. It's useful for:
- **Onboarding:** Follow the Setup Commands to get a working dev environment.
- **Consistency:** Code Style and Testing Instructions ensure AI-generated code matches repo conventions.
- **PR readiness:** PR Instructions help format commits and PRs correctly.

## Tips for Maximum Productivity

1. **Let auto-loading work for you** — Just open the file you're working on. The `.instructions.md` files activate automatically.
2. **Use natural language for skills** — Don't invoke skills by name. Just describe: "add a test", "bump dependencies", "review security".
3. **Start reviews with @CodeReviewer** — It knows the repo's review patterns, linter rules, and security requirements.
4. **Use @prd before big features** — A structured PRD helps scope the work before writing code.
5. **Check test/AGENTS.md for test guidance** — It has a decision tree for choosing the right test type.
6. **Trust the context chain** — The layered system ensures the AI has the right context at the right time.

## Customizing These Artifacts

These files are meant to evolve with your project:
- **Add rules** to `.instructions.md` files when you establish new coding conventions.
- **Add skills** when you identify a new recurring workflow.
- **Update `copilot-instructions.md`** when project structure or build commands change.
- **Update `AGENTS.md`** when setup commands or test strategies change.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow Go conventions | Verify `.github/instructions/go.instructions.md` exists and `applyTo` matches `**/*.go` |
| Skill not activating | Use the trigger phrases listed in the skill table above |
| Agent not available | Ensure the `.agent.md` file is in `.github/agents/` |
| AI gives generic advice | It may not be loading `copilot-instructions.md` — verify the file is at `.github/copilot-instructions.md` |
| Build commands fail | Update the Setup Commands section in `AGENTS.md` to match your current environment |
