# Code Refactoring

## Description
Guide for refactoring existing code while preserving behavior.

USE FOR: refactor, restructure, rename, extract method, simplify, clean up
DO NOT USE FOR: adding features, changing behavior, fixing bugs

## Instructions

### When to Apply
When improving code structure, readability, or maintainability without changing functionality.

### Step-by-Step Procedure
1. **Identify scope**: Determine which files and modules are affected.
2. **Run existing tests** before making changes to establish a baseline.
3. **Make changes incrementally**: rename, extract, or restructure one concern at a time.
4. **Update imports/references**: If renaming files or moving code, update all `require_relative` (Ruby), import paths (Go), or source commands (Shell).
5. **Run all affected test suites** after each change.
6. **Verify Docker image builds** to catch any broken references.

### Files Typically Involved
- Depends on refactoring scope — could touch any source files
- Corresponding test files must be updated to match

### Validation
- All unit test suites pass (unchanged behavior)
- Docker image builds successfully
- No new test failures

## Examples from This Repo
- `f58b7f0` — Longw/networkflow strean rename (#1570)
- `e26dab1` — Longw/networkflow rename (#1553)
- `e8c6f0d` — update mapping logic from extensions to aggregate (#1585)

## References
- `source/plugins/ruby/constants.rb` — Shared constants
- `source/plugins/go/src/extension/` — Extension module patterns
