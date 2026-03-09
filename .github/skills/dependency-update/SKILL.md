# Dependency Update Skill

## Name
dependency-update

## Description
Update Go modules, Ruby gems, system packages, or base image versions in the Docker-Provider repository.

## Triggers
- "update dependencies", "bump versions", "upgrade go modules", "update gems", "update base image"

## DO NOT USE FOR
- CVE/vulnerability fixes — use `fix-critical-vulnerabilities` skill instead
- Fluent Bit or Telegraf version upgrades (these are major component changes, not dependency bumps)

## Workflow

### 1. Identify What to Update
- **Go modules:** `source/plugins/go/src/go.mod`, `source/plugins/go/input/go.mod`, `test/ginkgo-e2e/*/go.mod`
- **Ruby gems:** Check gems used in `source/plugins/ruby/` (fluentd, ipaddress, etc.)
- **System packages:** `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
- **Base images:** Mariner/Azure Linux version in Dockerfile ARG
- **.NET SDK:** `build/windows/installer/certificategenerator/CertificateGenerator.csproj`

### 2. Update Dependencies
```bash
# Go modules
cd source/plugins/go/src && go get -u ./... && go mod tidy
cd source/plugins/go/input && go get -u ./... && go mod tidy

# Verify build
cd build/linux && make
```

### 3. Test
```bash
cd source/plugins/go/src && go test ./...
./test/unit-tests/run_go_tests.sh
./test/unit-tests/run_ruby_tests.sh
```

### 4. Security Scan
Build the Docker image and run Trivy to ensure no new vulnerabilities are introduced.

### 5. Commit
Use descriptive message: `Update <dependency> to <version> (#PR)`

## Supporting Commits (12 months)
- Fluent bit 4.0.14 (#1601)
- Upgrade Fluent Bit to 4.0.9 (#1535)
- Upgrade Telegraf 1.34.3 (#1434)
- update dotnet8 (#1565)
- mdsd version upgrade 1.35.7 (#1492)
- Upgraded fluent-bit for windows with latest (#1479)
- Mariner 3 upgrade (#1439)
