# Build and Test Commands

## Build Structure

- `build/version` — Version metadata (major/minor/patch/build number/date/status).
- `build/linux/Makefile` — Linux build (Make).
- `build/windows/Makefile.ps1` — Windows build (PowerShell).
- `build/common/installer/` — Shared installer config and scripts (conf/, scripts/).
- `build/linux/installer/` — Linux-specific installer (InstallBuilder, datafiles, bundle scripts).
- `build/windows/installer/` — Windows-specific installer (certificate generator, liveness probe, conf, scripts).

## Linux Build

Run from `build/linux/`:

```bash
# Build all (default target: kit + fluent-bit plugins)
make

# Build for arm64
make arch=arm64

# Clean intermediate/target artifacts
make clean
```

**Default target (`all`)** builds:
1. **Fluent Bit input plugins** — `containerinventory.so`, `perf.so` (Go, under `source/plugins/go/input/`)
2. **Fluent Bit output plugin** — `out_oms.so` (Go, under `source/plugins/go/src/`)
3. **Installer kit** — installs cmetrics, then runs InstallBuilder to produce RPM, DPKG, tar, and shell bundle packages.

Output lands in `kubernetes/linux/<BUILD_CONFIGURATION>/`.

## Windows Build

Run from `build/windows/`:

```powershell
.\Makefile.ps1
```

**Steps performed:**
1. Builds .NET certificate generator (`net6.0`, `win10-x64`) and zips output.
2. Builds Go Fluent Bit plugins (`out_oms.so`, `containerinventory.so`, `perf.so`).
3. Compiles liveness probe C++ (`livenessprobe.exe` via g++).
4. Copies installer files, conf, scripts, and Ruby plugin sources.

Output lands in `kubernetes/windows/amalogswindows/`.

Supports CDPx build environments (auto-detected via `IsCDPXBuildMachine` env var) and cross-compilation from Unix.

## Testing

Full details in [test/README.md](../../test/README.md).

### Test Suites

| Directory | Purpose |
|---|---|
| `test/unit-tests/` | Go (`run_go_tests.sh`) and Ruby (`run_ruby_tests.sh`) unit tests |
| `test/ginkgo-e2e/` | Ginkgo-based e2e tests (container status, liveness probe, query logs) |
| `test/testkube/` | TestKube runner configs for CI/CD cluster execution |
| `test/e2e/` | Azure ARC conformance tests |
| `test/scenario/` | Scenario YAML configs (log generators, multiline) |
| `test/containerlog-scale-tests/` | Log scale testing YAMLs and deploy/cleanup scripts |
| `test/prometheus-scraping/` | Prometheus scraping reference apps |

### Ginkgo E2E Tests

Tests use the [Ginkgo](https://onsi.github.io/ginkgo/) BDD framework with [Gomega](https://onsi.github.io/gomega/) assertions.

**Test categories:**
- **Container Status** — Validates daemonset pods scheduled on all nodes, containers running, expected processes active (fluent-bit, fluentd, mdsd, telegraf on Linux; fluent-bit, MonAgent* on Windows), no errors in logs.
- **Liveness Probe** — Verifies containers restart when critical processes (fluent-bit, fluentd, mdsd) stop.
- **Query Logs** — Confirms data flows to Log Analytics (Perf, InsightsMetrics, ContainerLog/V2, ContainerInventory, KubeNodeInventory, KubePodInventory, etc.).

**Running locally:**

```bash
# Install Ginkgo
go install github.com/onsi/ginkgo/v2/ginkgo@latest

# Run all tests (from test/ginkgo-e2e/)
cd test/ginkgo-e2e
ginkgo -p -r --keep-going

# Run a specific package
ginkgo -p -r --keep-going ./livenessprobe

# Filter by label
ginkgo --label-filter='!(arc-extension,windows)' -p -r --keep-going
```

No TestKube installation needed for local runs — just connect to a cluster.

### TestKube (CI/CD)

[TestKube](https://docs.testkube.io/) runs Ginkgo tests inside the cluster as K8s jobs.

**Setup:**

```bash
# Install CLI (Linux/WSL)
wget -qO - https://repo.testkube.io/key.pub | sudo apt-key add -
echo "deb https://repo.testkube.io/linux linux main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update && sudo apt-get install -y testkube

# Install helm chart
cd test/testkube
helm repo add kubeshop https://kubeshop.github.io/helm-charts && helm repo update
helm upgrade --install --create-namespace testkube kubeshop/testkube -n testkube -f ./helm-testkube-values.yaml

# Apply test CRs and permissions
kubectl apply -f testkube-test-crs.yaml
kubectl apply -f api-server-permissions.yaml

# Run tests
kubectl testkube run testsuite <suite-name> --job-template ./custom-job-template.yaml --verbose

# Watch/get results
kubectl testkube watch testsuiteexecution $execution_id
kubectl testkube get testsuiteexecution $execution_id
```

**Adding new tests:** Write Ginkgo specs in `test/ginkgo-e2e/`, add suites to `testkube-test-crs.yaml`, and add any API server permissions to `api-server-permissions.yaml`.