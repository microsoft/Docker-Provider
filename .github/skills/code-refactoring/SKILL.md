# Code Refactoring

## Purpose
Restructures and improves existing Container Insights agent code without changing external behavior. Targets code clarity, maintainability, performance, and reduction of technical debt in Go plugins, Ruby plugins, shell scripts, and build infrastructure.

USE FOR: "refactor", "clean up code", "reduce duplication", "extract method", "simplify", "improve readability", "consolidate", "rename", "restructure", "tech debt"
DO NOT USE FOR: Fixing bugs that change behavior (use bug-fix), adding new functionality (use feature-development), dependency updates (use dependency-update)

## When to Use
- Duplicated logic exists across multiple plugins that should be consolidated
- A function or method has grown too complex (high cyclomatic complexity)
- Variable or function names are misleading or inconsistent
- Dead code or unused imports need removal
- Constants are hardcoded in multiple places instead of using `constants.rb` or Go constants
- Error handling patterns are inconsistent across similar plugins
- Go code needs to be restructured to follow idiomatic patterns

## Inputs
- Source file(s) or module to refactor
- Specific code smell or improvement goal
- Confirmation that existing tests provide adequate coverage for the refactored code (add tests first if not)

## Outputs
- Refactored source code with improved structure
- All existing tests continue to pass (behavior is preserved)
- No changes to external interfaces, APIs, or output formats

## Steps
1. Identify the scope of the refactoring:
   - Go plugins: `source/plugins/go/src/`, `source/plugins/go/input/`
   - Ruby plugins: `source/plugins/ruby/`
   - Shared constants: `source/plugins/ruby/constants.rb`
   - Build scripts: `build/linux/`, `scripts/`
   - Kubernetes scripts: `kubernetes/linux/`, `kubernetes/windows/`
2. Verify existing test coverage for the code being refactored:
   - Run `test/unit-tests/run_go_tests.sh` for Go code
   - Run `test/unit-tests/run_ruby_tests.sh` for Ruby code
   - If coverage is insufficient, add tests BEFORE refactoring (use test-authoring skill)
3. Perform the refactoring in small, reviewable increments:
   - Extract shared logic into helper functions or utility modules
   - Replace magic numbers/strings with named constants
   - Simplify complex conditionals
   - Remove dead code and unused imports
   - Standardize error handling patterns
   - Improve variable and function naming
4. After each incremental change, run the relevant test suite to verify behavior is preserved
5. Build the agent to verify compilation:
   - `make` in `source/plugins/go/src/Makefile`
   - `make` in `build/linux/Makefile`
6. Run all test suites for a final validation pass

## Validation
- All existing tests pass without modification (behavior is preserved)
- `bash test/unit-tests/run_go_tests.sh` passes
- `bash test/unit-tests/run_ruby_tests.sh` passes
- `bash test/unit-tests/test_main.sh` passes
- Code compiles successfully (`go build ./...`, `make`)
- No new warnings from CodeQL (`codeql-analysis.yml`) or DevSkim (`devskim.yml`)
- PR CI checks pass: pr-checker.yml, run_unit_tests.yml
- Refactored code is easier to understand (smaller functions, clearer names, less duplication)

## Risks and Guardrails
- **Test coverage prerequisite**: Never refactor code without adequate test coverage; add tests first if needed
- **Behavioral preservation**: Refactoring must not change output formats, log levels, metric names, or API call patterns
- **Small PRs**: Break large refactors into small, incremental PRs that are easy to review and revert
- **Ruby dynamic dispatch**: Ruby plugins use metaprogramming and dynamic method calls; ensure renames don't break runtime dispatch
- **Go interface compliance**: Refactored Go code must still satisfy Fluent Bit plugin interfaces
- **Cross-file impact**: Renaming constants in `constants.rb` affects all Ruby plugins that import it; grep for all usages
- **Configuration compatibility**: Refactoring ConfigMap parsing must preserve all existing configuration key names

## Examples from This Repo
- Consolidating duplicated Kubernetes API call patterns from individual `in_kube_*.rb` plugins into `KubernetesApiClient.rb`
- Extracting common error handling and retry logic into shared Go utility packages
- Moving hardcoded strings into `source/plugins/ruby/constants.rb`
- Simplifying conditional logic in configuration parsing scripts under `scripts/`
- Refactoring commits are less frequent (6 commits in 12 months) and typically paired with test improvements
