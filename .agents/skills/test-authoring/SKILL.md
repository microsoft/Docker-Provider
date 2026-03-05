# Test Authoring

## Description
Guides adding tests for new or existing code following the repo's multi-language test patterns.

USE FOR: add test, write test, test coverage, add unit test, add integration test, add E2E test
DO NOT USE FOR: fixing flaky tests, refactoring test infrastructure, test-only CI changes

## Instructions

### When to Apply
When adding test coverage for new features, bug fixes, or existing untested code.

### Step-by-Step Procedure
1. Determine the test type and framework:
   - **Go unit tests**: `*_test.go` in `source/plugins/go/src/` using `testify/assert`
   - **Ruby unit tests**: `*_test.rb` in `source/plugins/ruby/` using minitest
   - **Bash unit tests**: test cases in `test/unit-tests/test_cases/*.sh` using custom framework
   - **PowerShell unit tests**: `Test-*.ps1` in `test/unit-tests/test_cases/` using Pester 5.3.3
   - **Ginkgo E2E tests**: `*_test.go` in `test/ginkgo-e2e/<suite>/`
2. Follow the naming convention for the language
3. For Go tests:
   - Set `GOUNITTEST=true` env guard for test isolation
   - Use `assert.Equal`, `assert.NotNil`, etc. from testify
4. For Ruby tests:
   - Set `$in_unit_test = true` (done automatically by test_driver.rb)
   - Use constructor injection to pass test doubles
5. For Bash tests:
   - Add test function in `test/unit-tests/test_cases/`
   - Add function-under-test in `test/unit-tests/test_functions/`
6. For PowerShell tests:
   - Add `Test-<FunctionName>.ps1` in `test/unit-tests/test_cases/`
   - Use Pester `Describe`/`It`/`Should` blocks

### Files Typically Involved
- `source/plugins/go/src/*_test.go`
- `source/plugins/ruby/*_test.rb`
- `test/unit-tests/test_cases/`
- `test/unit-tests/test_functions/`
- `test/ginkgo-e2e/*/`

### Validation
- Run the relevant test suite and verify new tests pass
- Check that existing tests still pass

## Examples from This Repo
- `cfcc53006` — fix: bleu cloud name (added test cases in multiple test suites)
- `66f24269f` — Fix FIC Auth support issues (updated E2E test workflows)
- `f32e2eec4` — Testkube workflow migration

## References
- `test/unit-tests/README.md` — test framework documentation
- `test/unit-tests/test_driver.rb` — Ruby test runner
- `test/unit-tests/test_framework.sh` — Bash test framework
