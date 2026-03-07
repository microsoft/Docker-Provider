# Agentify README

This document explains how to invoke the `agentify.prompt.md` file to generate a complete set of AI coding agent artifacts for this repository.

## What is `agentify.prompt.md`?

[agentify.prompt.md](agentify.prompt.md) is a master prompt that instructs an AI coding assistant to analyze this repository and auto-generate agent artifacts — files like `copilot-instructions.md`, `AGENTS.md`, `Prompt.md`, skill definitions, custom agent definitions, and MCP server configurations — that make this repo "agent-ready" for tools like GitHub Copilot, Google Jules, Gemini CLI, and others.

## Generated Artifacts

| Output File | Standard | Location |
|---|---|---|
| `copilot-instructions.md` | GitHub official | `.github/copilot-instructions.md` (GitHub) or root (other SCMs) |
| `AGENTS.md` | Open standard (AAIF / Linux Foundation) | Root (+ nested per subproject/test dir) |
| `.instructions.md` files | GitHub official | `.github/instructions/` (GitHub only) |
| `Prompt.md` | Workspace convention | Root |
| `SKILL.md` files | Azure extension pattern | `.github/skills/<name>/SKILL.md` or `.agents/skills/<name>/SKILL.md` |
| `CodeReviewer.agent.md` | Custom | `.github/agents/` (GitHub) or root (other SCMs) |
| `SecurityReviewer.agent.md` | Custom | `.github/agents/` (GitHub) or root (other SCMs) |
| `ThreatModelAnalyst.agent.md` | Custom | `.github/agents/` (GitHub) or root (other SCMs) |
| `DocumentWriter.agent.md` | Custom | `.github/agents/` (GitHub) or root (other SCMs) |
| `IncidentInvestigator.agent.md` | Custom (conditional) | `.github/agents/` — only if ICM/monitoring MCP servers detected |
| `ServiceTelemetry.agent.md` | Custom (conditional) | `.github/agents/` — only if App Insights/telemetry MCP servers detected |
| `prd.agent.md` | Custom | `.github/agents/` — always generated |
| `.vscode/mcp.json` | VS Code MCP | `.vscode/mcp.json` |
| `ServiceContext/` files | Custom (conditional) | `.github/instructions/ServiceContext/` |
| `coding-agent-instructions.md` | Custom | Root — user guide for all generated artifacts |

## Prerequisites

- A full (non-shallow) git clone of this repository with at least 12 months of commit history.
  - If you have a shallow clone, run `git fetch --unshallow` first.
- One of the supported AI coding assistants:
  - **GitHub Copilot** (VS Code, VS Code Insiders, or JetBrains with Copilot Chat)
  - **GitHub Copilot Coding Agent** (via GitHub.com agent mode)
  - **Google Jules**
  - **Gemini CLI**
  - Any AI assistant that supports prompt file ingestion
- (Optional) `gh` CLI — for PR review analysis on GitHub repos.
- (Optional) `az` CLI — for PR review analysis on Azure DevOps repos.

## How to Invoke

### Option 1: VS Code — GitHub Copilot Chat (Agent Mode)

1. Open the repository in VS Code.
2. Open GitHub Copilot Chat (click the Copilot icon in the sidebar or press `Ctrl+Shift+I`).
3. Switch to **Agent mode** (click the mode selector at the top of the chat panel and choose "Agent").
4. Attach the prompt file by typing `#` and selecting `agentify.prompt.md`, or drag-and-drop the file into the chat input.
5. Send the message — the agent will execute all phases (0 through 5) autonomously:
   - **Phase 0** — Validates the environment (clone depth, CLI tools, write access).
   - **Phase 1** — Detects the SCM provider (GitHub, Azure DevOps, GitLab, etc.).
   - **Phase 1.5** — Detects existing MCP server configuration and agent infrastructure.
   - **Phase 2** — Scans repository structure, languages, frameworks, dependencies, and conventions.
   - **Phase 3** — Analyzes git commit history (last 12 months) to identify skill candidates.
   - **Phase 4** — Creates a `copilot/agentify` branch and generates all output files.
   - **Phase 5** — Commits changes, pushes the branch, and creates a pull request.

### Option 2: GitHub Copilot CLI

1. Install the GitHub Copilot CLI extension (if not already installed):
   ```bash
   gh extension install github/gh-copilot
   ```
2. Authenticate with GitHub Copilot:
   ```bash
   gh auth login
   ```
3. From the repository root, run:
   ```bash
   copilot --yolo -p agentify.prompt.md
   ```
4. The CLI will execute the full phased pipeline autonomously and generate all agent artifacts.

### Option 3: GitHub Copilot Coding Agent (github.com)

1. Navigate to the repository on GitHub.com.
2. Open Copilot in the repository (click the Copilot icon).
3. Start a new coding agent session.
4. Paste the contents of `agentify.prompt.md` as the prompt, or reference the file:
   ```
   Follow the instructions in agentify.prompt.md to generate all agent artifacts for this repository.
   ```
5. The coding agent will execute the full pipeline and open a pull request with the generated files.

### Option 4: Google Jules

1. Open a Jules session pointed at this repository.
2. Provide the prompt file content or reference it:
   ```
   Follow the instructions in agentify.prompt.md to analyze this repository and generate all agent artifacts.
   ```
3. Jules will execute the phases and generate the artifacts.

### Option 5: Gemini CLI

1. From the repository root, run:
   ```bash
   gemini -f agentify.prompt.md
   ```
2. Gemini CLI will read the prompt and execute the full analysis and generation pipeline.

### Option 6: Any Other AI Assistant

1. Copy the full contents of `agentify.prompt.md`.
2. Paste it into your AI assistant's chat or prompt input.
3. The assistant will follow the phased execution plan to generate all artifacts.

## Tips for Large Repositories

- **Context window limits:** If the AI assistant has a limited context window, it may execute Phases 0–3 first (analysis), save findings to a session memory file, then execute Phases 4–5 (generation) in a follow-up pass.
- **Two-pass execution:** For maximum reliability, ask the assistant to do a two-pass approach: Pass 1 runs analysis (Phases 0–3) and produces a structured summary; Pass 2 consumes that summary and generates files (Phases 4–5).
- **Incremental output:** If generating all files at once is infeasible, ask the assistant to generate core files first (`copilot-instructions.md`, `AGENTS.md`, `Prompt.md`), then agent files, then skills, then conditional files.

## What Happens After Invocation

1. A new branch named `copilot/agentify` is created (or `copilot/agentify-<timestamp>` if the branch already exists).
2. All generated files are committed to this branch.
3. The branch is pushed to origin.
4. A pull request is created targeting the default branch.
5. An output summary is provided listing all generated files, detected configuration, and any warnings.

Review the pull request to verify the generated artifacts before merging.
