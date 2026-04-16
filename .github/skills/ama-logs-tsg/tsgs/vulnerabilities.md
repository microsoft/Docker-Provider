# Vulnerabilities / CVEs

## Symptom
CVE reported against a container image used by Container Insights agent.

## Diagnostic Steps

### 1. Identify the affected image
Check which ama-logs image version is running:
- Run `tsg_triage` → "Agent Version"
- Or check via `kubectl get pods -n kube-system -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | grep ama-logs`

### 2. Check if a patch is available
- Check the [Docker-Provider release notes](https://github.com/microsoft/Docker-Provider/blob/ci_prod/ReleaseNotes.md) for the latest version
- Container Insights images are auto-upgraded if the cluster has auto-upgrade enabled

### 3. Upgrade path
If the cluster doesn't auto-upgrade:
- Update the addon to the latest version via `az aks enable-addons` or Helm
- The image tag is managed by the AKS addon; manual image overrides are not supported

## Escalation
- **Auto-upgrade issues**: Azure Kubernetes Service / RP
- **CVE remediation timeline**: Container Insights / AzureManagedPrometheusAgent
