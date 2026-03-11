# Skill: Code Refactoring

## Overview
Perform behavior-preserving structural improvements across the Docker-Provider codebase. Refactoring must not change external behavior — tests must pass before and after.

## Scope
- **Go**: `source/plugins/go/src/`, `source/plugins/go/input/`
- **Ruby**: `source/plugins/ruby/`
- **Shell**: `kubernetes/linux/`, `scripts/`
- **Build**: `build/linux/`, Dockerfiles

## Workflow

### 1. Establish Baseline
Run the full test suite before making any changes:
```bash
cd build/linux && make
./test/unit-tests/run_go_tests.sh
ruby test/unit-tests/test_driver.rb
./test/unit-tests/test_main.sh
```
Record results. All tests must pass before refactoring begins.

### 2. Plan the Refactoring
- Identify the code smell or structural issue (duplication, long functions, unclear naming, tight coupling).
- Define the target state.
- Ensure the change is purely structural — no new features, no bug fixes mixed in.

### 3. Apply Changes

#### Go
- Update imports when moving or renaming packages.
- Run `go mod tidy` if import paths change.
- Use `gofmt` or `goimports` to maintain formatting.
- If renaming exported symbols, search all `go.mod` dependents for usage.

#### Ruby
- Follow existing naming conventions (`snake_case` for methods/variables).
- Update `require` / `require_relative` paths if files move.
- Check Fluent-Bit config files for class name references.

#### Shell
- Preserve `set -e` / `set -o pipefail` semantics.
- Quote all variable expansions.
- Test on both bash and sh if the script uses `#!/bin/sh`.

### 4. Verify
Run the identical test suite from step 1. Results must match:
```bash
cd build/linux && make
./test/unit-tests/run_go_tests.sh
ruby test/unit-tests/test_driver.rb
./test/unit-tests/test_main.sh
```

### 5. Commit
Keep refactoring commits separate from functional changes. Use a clear message:
```
Refactor container log parser into separate module (#1234)
```

## Multi-Language Considerations
This repo spans Go, Ruby, Shell, and Python. A refactoring in one language may require updates in another:
- Go plugin output format changes → Ruby filter expectations.
- Shell environment variable renames → Go/Ruby code that reads `ENV`.
- Config file restructuring → all consumers of that config.

Search across languages when renaming or restructuring shared interfaces:
```bash
grep -r "OLD_NAME" source/ kubernetes/ test/
```

## Pitfalls
- Never combine refactoring with behavior changes in the same commit.
- Shell scripts are sensitive to whitespace and quoting changes.
- Fluent-Bit plugin class names are referenced in config files — rename both together.
- Import path changes in Go require updating all downstream `go.mod` files.
