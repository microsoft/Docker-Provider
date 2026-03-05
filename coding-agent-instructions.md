# Coding Agent Instructions

This document explains how to use the AI coding agent artifacts generated for the Docker-Provider (Azure Monitor Container Insights) repository. These artifacts make AI assistants (GitHub Copilot, Google Jules, Gemini CLI, Cursor, etc.) understand your codebase deeply and contribute effectively.

## Quick Start

1. Open this repository in VS Code (or your preferred editor with Copilot/AI assistant support).
2. The AI assistant automatically loads `.github/copilot-instructions.md` on every session — no action needed.
3. When you open a file matching a language pattern, the corresponding `.instructions.md` file auto-activates.
4. Invoke skills by typing their trigger phrases in chat (e.g., "add test", "fix bug", "security review").
5. Invoke agents by @-mentioning them in chat (e.g., `@CodeReviewer`, `@DocumentWriter`).

## Generated Artifacts Overview

| Artifact | Path | Loaded | Purpose |
|----------|------|--------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Automatically every session | Root router — general rules, build instructions, skill catalogue |
| `AGENTS.md` | Root | Automatically (supported tools) | Setup commands, code style, testing instructions, dev environment tips |
| Go instructions | `.github/instructions/go.instructions.md` | Auto on `**/*.go` | Go coding conventions for Fluent Bit plugins |
| Ruby instructions | `.github/instructions/ruby.instructions.md` | Auto on `**/*.rb` | Ruby conventions for Fluentd plugins |
| Shell instructions | `.github/instructions/shell.instructions.md` | Auto on `**/*.sh` | Shell/Bash scripting conventions |
| PowerShell instructions | `.github/instructions/powershell.instructions.md` | Auto on `**/*.ps1` | PowerShell conventions |
| `Prompt.md` | Root | On demand | Reusable task-spec template for describing new work |
| Skill files (`SKILL.md`) | `.agents/skills/<name>/SKILL.md` | On keyword trigger | Step-by-step guides for recurring development tasks |
| `CodeReviewer.agent.md` | `.github/agents/CodeReviewer.agent.md` | On @-mention | Structured code review with STRIDE security + telemetry gap detection |
| `DocumentWriter.agent.md` | `.github/agents/DocumentWriter.agent.md` | On @-mention | Documentation authoring following repo doc standards |
| `prd.agent.md` | `.github/agents/prd.agent.md` | On @-mention | PRD generation tailored to this project |
| Test `AGENTS.md` | `test/AGENTS.md` | Auto in test directories | Test framework guide with decision tree |

## How the Context Loading Chain Works

```
Layer 1: .github/copilot-instructions.md (always loaded)
  ├── General rules, build instructions, skill catalogue
  ├── Routes to →
  │
Layer 2: .github/instructions/*.instructions.md (auto-loaded on file match)
  ├── Go, Ruby, Shell, PowerShell coding rules
  │
Layer 3: Skills (.agents/skills/*/SKILL.md) — loaded on trigger phrase
  └── Step-by-step procedures for specific tasks
```

**You don't need to manually load anything.** The system activates automatically based on what file you're editing and what you ask the AI to do.

## Using Custom Agents

### @CodeReviewer
- **Invoke:** Type `@CodeReviewer` in Copilot Chat.
- **What it does:** Reviews PRs for correctness, style, security (STRIDE), telemetry gaps, and adherence to project conventions across Go, Ruby, Shell, and PowerShell.
- **Example prompts:**
  - `@CodeReviewer review this PR`
  - `@CodeReviewer check this file for security issues`
  - `@CodeReviewer review my changes for telemetry gaps`
- **What it checks:** Naming conventions, test coverage, secrets/credentials, error handling, import ordering, CI compliance, STRIDE security, telemetry instrumentation.

### @DocumentWriter
- **Invoke:** Type `@DocumentWriter` in Copilot Chat.
- **What it does:** Creates and maintains documentation following this repo's structure and conventions.
- **Example prompts:**
  - `@DocumentWriter write release notes for version 3.1.36`
  - `@DocumentWriter update the Helm chart README`
  - `@DocumentWriter write a README for this new module`

### @prd (PRD Generator)
- **Invoke:** Type `@prd` in Copilot Chat.
- **What it does:** Generates structured Product Requirements Documents tailored to the container monitoring agent architecture.
- **Example prompts:**
  - `@prd create a PRD for adding OpenTelemetry trace export support`
  - `@prd write requirements for multi-tenant Windows support`

## Using Skills

Skills are step-by-step guides that activate when you use their trigger phrases in chat.

### Always-Available Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `security-review` | "security review", "STRIDE analysis", "credential leak check" | STRIDE-based security review, credential scanning, weak pattern detection |
| `telemetry-authoring` | "add telemetry", "add metrics", "instrument code" | Guides adding Application Insights telemetry following existing patterns |
| `fix-critical-vulnerabilities` | "fix CVE", "trivy fix", "patch vulnerability" | Identifies and fixes CRITICAL/HIGH vulnerabilities using Trivy |

### Commit-History-Driven Skills

| Skill | Trigger Phrases | What It Does |
|-------|----------------|--------------|
| `dependency-update` | "update dependency", "bump package", "fix CVE in deps" | Safe dependency updates for Go modules, Ruby gems |
| `bug-fix` | "fix bug", "resolve issue", "hotfix" | Structured bug fix with regression test requirements |
| `feature-development` | "add feature", "implement", "new plugin" | New feature scaffolding with test and telemetry requirements |
| `ci-cd-pipeline` | "update pipeline", "fix CI", "modify workflow" | CI/CD workflow and build system changes |
| `infrastructure` | "update Dockerfile", "Helm chart change", "Bicep update" | Infrastructure-as-code changes |
| `test-authoring` | "add test", "write test", "test coverage" | Test creation following multi-language conventions |

**Example usage:**
```
# In Copilot Chat, just describe the task naturally:
"Add a test for the network flow logs parser"
"Fix the critical CVE in our Go dependencies"
"Add telemetry to the new inventory collection path"
"Update the Helm chart for the new config option"
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
- **Onboarding:** Follow the Setup Commands to get a working environment.
- **Consistency:** Code Style ensures AI-generated code matches repo conventions.
- **PR readiness:** PR Instructions help format commits and PRs correctly.

## Tips for Maximum Productivity

1. **Let auto-loading work for you** — Just open the file you're working on. The `.instructions.md` files activate automatically based on file type.
2. **Use natural language for skills** — Don't try to invoke skills by name. Just describe the task: "add a test", "bump dependencies", "review security".
3. **Start reviews with @CodeReviewer** — It knows the review patterns, linter rules, and security requirements.
4. **Use @prd before big features** — A structured PRD helps the AI and your team understand the full scope.
5. **Remember multiple go.mod files** — This repo has 6+ Go modules. CVE fixes must update ALL of them.
6. **Check AGENTS.md for setup** — If the AI struggles with build or test commands, verify the Setup Commands.
7. **Use `test/AGENTS.md` for test guidance** — It has a decision tree for choosing the right test type and framework.

## Customizing These Artifacts

These files are meant to evolve with your project:
- **Add rules** to `.instructions.md` files when you establish new coding conventions.
- **Add skills** when you identify a new recurring workflow (create a `SKILL.md` in `.agents/skills/`).
- **Update `copilot-instructions.md`** when project structure or build commands change.
- **Update `AGENTS.md`** when setup commands, test strategies, or dev environment requirements change.
- **Re-run generation** periodically (e.g., quarterly) to pick up new commit patterns and refresh skills.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| AI doesn't follow coding conventions | Verify `.instructions.md` `applyTo` glob matches the file you're editing |
| Skill not activating | Use the exact trigger phrases listed in the skill table above |
| Agent not available | Ensure the `.agent.md` file is in `.github/agents/` |
| AI gives generic advice | It may not be loading `copilot-instructions.md` — verify the file is at `.github/copilot-instructions.md` |
| Build/test commands fail | Update the Setup Commands section in `AGENTS.md` to match your current environment |
| Multiple go.mod not updated | Use the `#dependency-update` or `#fix-critical-vulnerabilities` skill which lists all module locations |
