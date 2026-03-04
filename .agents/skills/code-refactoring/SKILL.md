# Code Refactoring

## Description
Refactor existing code to improve structure, rename resources, or simplify logic without changing behavior.

USE FOR: refactor, restructure, rename, extract method, move file, simplify, clean up, optimize mapping logic
DO NOT USE FOR: adding features, changing behavior, fixing bugs

## Instructions

### When to Apply
When restructuring code, renaming resources/streams, simplifying complex logic, or updating mapping implementations without changing external behavior.

### Step-by-Step Procedure
1. Identify all files affected by the refactoring.
2. Make changes incrementally, verifying tests pass after each step.
3. Update all references — import paths, configuration references, onboarding templates.
4. For stream/resource renames, update:
   - Source code in `source/plugins/`
   - Onboarding parameter files in `scripts/onboarding/`
   - Helm chart templates in `charts/`
   - Test configurations
5. Run all unit test suites to verify behavior is preserved.
6. Build Docker image to verify compilation.

### Files Typically Involved
- `source/plugins/go/src/*.go` — Go plugin refactoring
- `source/plugins/ruby/*.rb` — Ruby plugin refactoring
- `scripts/onboarding/aks/*/` — Onboarding parameter updates
- `charts/azuremonitor-containers/templates/` — Helm template updates

### Validation
- All unit tests pass without modification (behavior preserved)
- `./test/unit-tests/run_go_tests.sh`
- `./test/unit-tests/run_ruby_tests.sh`
- `./test/unit-tests/test_main.sh`
- Docker image builds successfully

## Examples from This Repo
- `676ccd66b` — Longw/networkflow rename (#1553)
- `abf84756d` — Longw/networkflow stream rename (#1570)
- `084d142d5` — update mapping logic from extensions to aggregate (#1585)

## References
- `source/plugins/` — Plugin source code
- `scripts/onboarding/` — Onboarding templates
