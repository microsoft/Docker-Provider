# Azure Monitor / OTLP bug bash — Azure CLI

Install the CLI build, then mix and match the flags below on your own cluster.

## 1. Install

The flags are not in a released CLI yet. Install the branch build into a throwaway venv:

```bash
python3 -m venv ~/aks-bugbash
source ~/aks-bugbash/bin/activate
pip install --upgrade pip
pip install "git+https://github.com/suyadav1/azure-cli.git@suyadav1/ci-otlp-ga#subdirectory=src/azure-cli"
```

PowerShell: `py -3 -m venv $HOME\aks-bugbash`, `$HOME\aks-bugbash\Scripts\Activate.ps1`, then the
same two `pip` lines.

> **⚠️ `aks-preview` shadows this build.** Extensions live in `~/.azure/cliextensions` and are
> shared by every `az` on the machine, **including one inside a venv** — so `aks-preview` will
> override `az aks` and you'll silently test the wrong code. Isolate it (keeps your `az login`):
>
> ```bash
> export AZURE_EXTENSION_DIR=~/.azure-bugbash-ext && mkdir -p "$AZURE_EXTENSION_DIR"
> ```

Check you're on the right build:

```bash
az extension list -o tsv    # must not list aks-preview
az aks update --help | grep -- --enable-opentelemetry-logs-traces
```

`deactivate` gets your normal `az` back.

## 2. Flags

Scope: **C** = `aks create`, **U** = `aks update`.

### Azure Monitor Logs (Container Insights)

| Flag | Scope | Notes |
| --- | :-: | --- |
| `--enable-azure-monitor-logs` | C, U | Onboard with managed identity auth. |
| `--disable-azure-monitor-logs` | U | |
| `--workspace-resource-id` | C, U | Existing Log Analytics workspace; one is created if omitted. |
| `--ampls-resource-id` | C, U | Private link scope. |
| `--data-collection-settings` | C, U | JSON file of DCR settings. |

### Container Insights settings (need Azure Monitor logs)

| Flag | Scope | Notes |
| --- | :-: | --- |
| `--enable-syslog` | C, U | Off with `--enable-syslog false`. |
| `--syslog-port` | C, U | Default `28330`. |
| `--enable-high-log-scale-mode` | C, U | Off with `--enable-high-log-scale-mode false`. |
| `--enable-prometheus-metrics-scraping` | C, U | Agent-side scraping — *not* Managed Prometheus. |
| `--disable-prometheus-metrics-scraping` | C, U | |
| `--enable-container-network-logs` | C, U | Needs `--enable-acns`; auto-enables high log scale. |
| `--disable-container-network-logs` | U | |

### OpenTelemetry receivers

| Flag | Scope | Notes |
| --- | :-: | --- |
| `--enable-opentelemetry-logs-traces` | C, U | Needs Azure Monitor **logs**. Host ports 28331/28332. |
| `--disable-opentelemetry-logs-traces` | C, U | |
| `--opentelemetry-logs-traces-port-http` | C, U | Optional — platform default 28331. |
| `--opentelemetry-logs-traces-port-grpc` | C, U | Optional — platform default 28332. |
| `--enable-opentelemetry-metrics` | C, U | Needs Azure Monitor **metrics**. Host ports 28333/28334. |
| `--disable-opentelemetry-metrics` | C, U | |
| `--opentelemetry-metrics-port-http` | C, U | Optional — platform default 28333. |
| `--opentelemetry-metrics-port-grpc` | C, U | Optional — platform default 28334. |

### Azure Monitor Metrics (Managed Prometheus)

| Flag | Scope | Notes |
| --- | :-: | --- |
| `--enable-azure-monitor-metrics` | C, U | |
| `--disable-azure-monitor-metrics` | U | |
| `--azure-monitor-workspace-resource-id` | C, U | |
| `--grafana-resource-id` | C, U | |
| `--ksm-metric-labels-allow-list` | C, U | kube-state-metrics labels. |
| `--ksm-metric-annotations-allow-list` | C, U | kube-state-metrics annotations. |
| `--enable-control-plane-metrics` | C, U | |
| `--disable-control-plane-metrics` | U | |
| `--enable-windows-recording-rules` | C, U | Enable-only. |

## 3. Rules worth testing

- OTLP **logs/traces** needs `--enable-azure-monitor-logs`; OTLP **metrics** needs
  `--enable-azure-monitor-metrics`. Easy to get backwards.
- `--enable-prometheus-metrics-scraping` needs Azure Monitor **logs**.
- All four OTLP ports must be distinct and within `1–65535`.
- A port flag can't be combined with the matching disable flag — and this fails *before* anything
  is torn down, so the cluster should be untouched afterwards.
- `--enable-syslog` and `--enable-high-log-scale-mode` take `true`/`false`; there is no
  `--disable-syslog` / `--disable-high-log-scale-mode`.
- Any `--enable-x` together with its `--disable-x` should be a clean error, not a traceback.

## 4. Examples

```bash
# Container Insights + OTLP logs/traces
az aks update -g <rg> -n <cluster> \
  --enable-azure-monitor-logs --enable-opentelemetry-logs-traces

# Managed Prometheus + OTLP metrics
az aks update -g <rg> -n <cluster> \
  --enable-azure-monitor-metrics --enable-opentelemetry-metrics

# Syslog on a custom port, plus high log scale
az aks update -g <rg> -n <cluster> \
  --enable-azure-monitor-logs --enable-syslog --syslog-port 28340 \
  --enable-high-log-scale-mode

# Turn syslog back off
az aks update -g <rg> -n <cluster> --enable-syslog false

# Tear down
az aks update -g <rg> -n <cluster> --disable-azure-monitor-logs
```

Inspect what landed:

```bash
az aks show -g <rg> -n <cluster> --query azureMonitorProfile -o json
```

## 5. Prove telemetry actually flows

The config landing is only half of it. Deploy the generator workloads in
[`README.md`](./README.md) to push real logs, traces and metrics through the receivers over both
HTTP and gRPC, with the KQL and PromQL to check what arrives.

## Filing a bug

Include the command, `az version`, `az extension list -o tsv` (proves `aks-preview` wasn't
shadowing), the output, and `azureMonitorProfile` from the cluster.
