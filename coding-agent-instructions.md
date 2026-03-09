# Coding Agent Instructions — Docker-Provider

This guide explains the AI coding assistant artifacts generated for the Docker-Provider (Azure Monitor for Containers) repository. These files help AI assistants (GitHub Copilot, etc.) understand and contribute to this codebase effectively.

## Artifact Overview

| File | Location | Purpose |
|------|----------|---------|
| `copilot-instructions.md` | `.github/copilot-instructions.md` | Root instructions — repo summary, architecture, skill routing |
| `AGENTS.md` | Root | Setup commands, build/test instructions, code style, AI workflow |
| `Prompt.md` | Root | Tech stack, architecture, conventions, entry points |
| `go-plugins.instructions.md` | `.github/instructions/` | Go plugin development guidelines (auto-loaded for `*.go`) |
| `ruby-plugins.instructions.md` | `.github/instructions/` | Ruby plugin guidelines (auto-loaded for `*.rb`) |
| `build-container.instructions.md` | `.github/instructions/` | Build, Docker, Helm guidelines |
| `testing.instructions.md` | `.github/instructions/` | Test framework guide (auto-loaded for `test/**`) |
| `test/AGENTS.md` | `test/` | Nested test-specific instructions |
| `CodeReviewer.agent.md` | `.github/agents/` | Code review agent with STRIDE security checklist |
| `SecurityReviewer.agent.md` | `.github/agents/` | Deep security analysis agent |
| `ThreatModelAnalyst.agent.md` | `.github/agents/` | STRIDE threat model generator |
| `DocumentWriter.agent.md` | `.github/agents/` | Documentation maintenance agent |
| `prd.agent.md` | `.github/agents/` | Product requirements document generator |
| `.vscode/mcp.json` | `.vscode/` | MCP server configuration |

## Agents

### @CodeReviewer
Reviews code for quality, security, performance, and telemetry compliance. Includes:
- Language-specific checklists (Go, Ruby, Shell, PowerShell, Helm)
- STRIDE security checklist populated with repo-specific patterns
- Telemetry coverage verification
- Backward compatibility checks

### @SecurityReviewer
Deep security analysis with:
- Authentication pattern review (IMDS, MSI, FIC, Geneva)
- Container security (Dockerfiles, security contexts, RBAC)
- Supply chain analysis (dependencies, Trivy, CodeQL)
- Credential leak detection patterns
- Weak security pattern catalog per language

### @ThreatModelAnalyst
Generates comprehensive STRIDE threat models with:
- Mermaid architecture diagrams with trust boundaries
- Component-level STRIDE analysis
- DREAD-aligned severity ratings
- Output to `threat-model/YYYY-MM-DD/` directory

### @DocumentWriter
Maintains documentation following repo conventions:
- Release notes format
- Architecture documentation
- Onboarding guides

### @prd (PRD Agent)
Generates structured product requirements documents for new features.

## Skills

| Skill | Trigger Phrases | Commits (12mo) |
|-------|----------------|----------------|
| `dependency-update` | "update dependencies", "bump versions" | 7 |
| `bug-fix` | "fix bug", "resolve issue", "debug" | 13 |
| `ci-cd-pipeline` | "update pipeline", "fix CI" | 14 |
| `infrastructure` | "update helm", "modify deployment" | 13 |
| `security-review` | "security check", "STRIDE analysis" | Always generated |
| `fix-critical-vulnerabilities` | "fix CVE", "patch vulnerability" | 7 |
| `telemetry-authoring` | "add telemetry", "add metrics" | Always generated |
| `test-authoring` | "write tests", "add test coverage" | 9 |
| `release-management` | "prepare release", "release notes" | 8 |

## Prompt Engineering Best Practices

### Structuring Effective Prompts
1. **Be specific about scope:** Reference exact file paths (e.g., "modify `source/plugins/go/src/oms.go`") rather than vague descriptions.
2. **Provide context:** Mention the target platform (Linux/Windows), cluster type (AKS/Arc/ARO), and data flow (logs/metrics/inventory).
3. **One task per prompt:** Break complex changes into focused steps — one plugin, one test, one config file.
4. **Include acceptance criteria:** Specify what success looks like (e.g., "tests pass", "Trivy scan clean", "backward compatible").

### Anti-Patterns
- ❌ "Fix the agent" — too vague, no scope
- ❌ "Update everything" — no clear deliverable
- ❌ Changing multiple unrelated systems in one prompt
- ✅ "Add error telemetry to the IMDS token refresh failure path in `ingestion_token_utils.go`"
- ✅ "Write a Go unit test for `PostNetworkFlowRecords()` in `network_flow_logs.go` testing the empty records case"

## Choosing the Right Copilot Tool

| Task | Tool | Why |
|------|------|-----|
| Understand code flow | Copilot Chat (Ask) | Synthesizes information from multiple files |
| Find function usages | grep/ripgrep | Fast, precise text search |
| Generate boilerplate | Copilot inline | Context-aware code completion |
| Write/modify tests | Copilot Chat (Edit) | Can see both source and test context |
| Debug CI failures | Read CI logs + Copilot Chat | Needs external log context |
| Security review | @SecurityReviewer agent | Specialized STRIDE analysis |
| Code review | @CodeReviewer agent | Comprehensive quality checklist |

## Context Management
- **Open relevant files** before prompting — Copilot uses open files as context
- **Close unrelated files** to reduce noise in suggestions
- **Start fresh sessions** for unrelated tasks to avoid context pollution
- **Reference `.github/instructions/` files** — they auto-load based on file type

## Recommended Workflow

### explore → plan → code → commit
1. **Explore:** Open relevant source files, read tests, understand the current behavior
2. **Plan:** Identify all files that need changes, estimate scope
3. **Code:** Make changes following code style in `AGENTS.md`
4. **Test:** Run appropriate test suite (Go/Ruby/Bash/PowerShell)
5. **Build:** Verify compilation with `cd build/linux && make`
6. **Commit:** Descriptive message with PR reference

### Use-Case Table
| Scenario | Explore | Plan | Code | Test |
|----------|---------|------|------|------|
| Bug fix | Read error logs, find related code | Identify root cause file | Apply minimal fix | Add regression test |
| New feature | Understand existing plugin pattern | List files to create/modify | Implement following patterns | Add unit + integration tests |
| CVE fix | Check Trivy output, find vulnerable dep | Determine update strategy | Update dependency version | Build + scan |
| Config change | Read Helm chart, understand values | Check all chart variants | Update values + templates | Helm lint + template |

## Validating AI-Generated Code
1. **Understand:** Read the generated code — don't blindly accept
2. **Build:** Run `cd build/linux && make` (or Windows equivalent)
3. **Test:** Run the appropriate test suite for the changed language
4. **Lint:** Check CodeQL and DevSkim findings on the PR
5. **Security:** Run Trivy scan on built container image
6. **Pattern match:** Compare against existing code in the same directory for style consistency

## Test-Driven Development with AI
1. Write the test first (using `test-authoring` skill patterns)
2. Run it — verify it fails
3. Ask the agent to implement the code to make the test pass
4. Run the test — verify it passes
5. Ask for refactoring if needed

## Codebase Onboarding with AI
Example questions to ask Copilot Chat:
- "How does the Fluent Bit output plugin route data to ODS vs MDSD?"
- "What Kubernetes resources does the Ruby KubernetesApiClient query?"
- "How does IMDS token refresh work in `ingestion_token_utils.go`?"
- "What's the difference between the three Helm charts in `charts/`?"
- "How does the agent startup sequence work in `kubernetes/linux/setup.sh`?"

## Security When Using AI Assistants
- **Never paste secrets** into prompts — use environment variable names instead
- **Review security-sensitive code** manually — auth, crypto, TLS configuration
- **Run security scans** (CodeQL, DevSkim, Trivy) on all AI-generated code
- **Check for credential leaks** in generated code before committing
- **Verify RBAC scope** if AI suggests Kubernetes resource access changes

## Measuring AI-Assisted Productivity
Track these metrics to evaluate effectiveness:
- **PR cycle time:** Time from first commit to merge
- **Test coverage delta:** Coverage change per PR
- **CVE fix turnaround:** Time from Trivy alert to fix merged
- **CI pass rate:** First-run CI success percentage
- **Review iterations:** Number of review rounds before approval
