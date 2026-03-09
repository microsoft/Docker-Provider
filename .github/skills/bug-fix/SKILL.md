# Bug Fix Skill

## Name
bug-fix

## Description
Diagnose and fix bugs in the Docker-Provider monitoring agent with proper test coverage and validation.

## Triggers
- "fix bug", "resolve issue", "debug", "fix error", "troubleshoot"

## Workflow

### 1. Reproduce & Understand
- Identify the affected component: Go plugin, Ruby plugin, Shell script, PowerShell, or Helm chart
- Check recent commits in the affected area for context
- Review related test files for existing coverage

### 2. Locate Root Cause
- **Go plugins:** Check error handling in `source/plugins/go/src/`, especially `oms.go`, `ingestion_token_utils.go`, `network_flow_logs.go`
- **Ruby plugins:** Check `source/plugins/ruby/` — KubernetesApiClient, ApplicationInsightsUtility
- **Startup scripts:** Check `kubernetes/linux/setup.sh`, `kubernetes/windows/setup.ps1`
- **Build issues:** Check `build/linux/Makefile`, `build/windows/Makefile.ps1`

### 3. Fix
- Apply minimal, targeted fix
- Ensure error handling covers the new case
- Add telemetry for the error condition if not already present

### 4. Test
- Add or update unit test that covers the bug scenario
- Run relevant test suite:
  ```bash
  # Go
  cd source/plugins/go/src && go test -v -run TestName ./...
  # Ruby
  ./test/unit-tests/run_ruby_tests.sh
  # Bash
  ./test/unit-tests/test_main.sh
  # PowerShell
  ./test/unit-tests/test_main.ps1
  ```

### 5. Validate
- Build: `cd build/linux && make`
- Verify no regressions in existing tests

## Supporting Commits (12 months)
- bug fix (#1593)
- fix bug (#1577)
- fix: bleu cloud name is azurebleucloud (#1598)
- Cosmic replicaset Kubernetes API client large scale issue (#1590)
- fix amaca liveness probe issue in high scale mode (#1530)
- Fix AMCS endpoint (#1501)
- fix endpoint name for bleu (#1496)
- Fix FIC Auth support issues (#1547)
- fix fluentd startup failure in legacy cluster (#1467)
- Cert mount fix for AGC (#1518)
- Fix arc prod pipeline timeout issue (#1564)
- Fix geneva resource optimization (#1447)
- Fix testkube mongodb issue (#1584)
