# Infrastructure

## Purpose
Manages the container image definitions, Helm charts, Kubernetes manifests, and deployment infrastructure for the Container Insights agent. Covers Dockerfiles for Linux and Windows multi-arch builds, Helm chart templates and values, Kubernetes DaemonSet/Deployment specs, and supporting deployment scripts.

USE FOR: "update Dockerfile", "Helm chart change", "chart version bump", "add environment variable", "update container image", "Kubernetes manifest", "DaemonSet change", "add volume mount", "update resource limits", "multi-arch build", "base image update", "chart template"
DO NOT USE FOR: Application plugin code changes (use bug-fix or feature-development), CI pipeline YAML changes (use ci-cd-pipeline), Go/Ruby dependency updates (use dependency-update)

## When to Use
- Updating base images in Dockerfiles (e.g., CBL-Mariner, Windows Server Core)
- Modifying Helm chart templates, values, or Chart.yaml version
- Adding or changing environment variables, ConfigMap mounts, or volume definitions
- Updating Kubernetes resource requests/limits for agent pods
- Adding new container ports, probes, or security contexts
- Modifying the multi-arch build process for Linux or Windows images
- Updating deployment scripts in `kubernetes/` or `deployment/`
- Changing the agent installation or startup process within the container

## Inputs
- Description of the infrastructure change
- Target artifact: Dockerfile, Helm chart, Kubernetes manifest, or deployment script
- Whether the change affects Linux, Windows, or both platforms
- Any new image tags, registry references, or chart versions

## Outputs
- Updated Dockerfiles, Helm charts, Kubernetes manifests, or deployment scripts
- Updated `Chart.yaml` with bumped version if Helm chart content changed
- Passing container image build
- Valid Helm template rendering
- Updated `ReleaseNotes.md` if the change affects a shipped component version

## Steps
1. Identify the target infrastructure file(s):
   - **Dockerfiles:**
     - `kubernetes/linux/Dockerfile.multiarch` — Linux multi-arch agent image (AMD64, ARM64)
     - `kubernetes/windows/Dockerfile` — Windows agent image
     - `kubernetes/windows/Dockerfile-dev-image` — Windows dev/test image
   - **Helm charts:**
     - `charts/azuremonitor-containers/` — Public Azure Monitor chart
     - `charts/azuremonitor-containers-geneva/` — Geneva (internal Microsoft) chart
     - `charts/azuremonitor-containerinsights-for-prod-clusters/` — Production clusters chart
   - **Kubernetes manifests and scripts:**
     - `kubernetes/linux/` — Linux-specific K8s resources and scripts
     - `kubernetes/windows/` — Windows-specific K8s resources and PowerShell scripts
     - `deployment/` — Deployment templates and ARM/Bicep resources
2. Make the infrastructure change:
   - For Dockerfiles: follow multi-stage build patterns; pin base image versions; maintain layer cache efficiency
   - For Helm charts: update templates in `templates/`, values in `values.yaml`, and metadata in `Chart.yaml`
   - For Kubernetes manifests: follow existing resource naming and labeling conventions
3. If modifying Helm charts:
   - Bump the chart version in `Chart.yaml` (patch for fixes, minor for new features)
   - Ensure default values in `values.yaml` maintain backward compatibility
   - Update all chart variants if the change applies broadly (public, geneva, prod-clusters)
4. Build and verify container images:
   - Linux: `docker build -f kubernetes/linux/Dockerfile.multiarch .`
   - Windows: `docker build -f kubernetes/windows/Dockerfile .`
5. Validate Helm charts:
   - `helm lint charts/azuremonitor-containers/`
   - `helm template charts/azuremonitor-containers/` — verify rendered manifests
6. Run Trivy scan on built images to check for new vulnerabilities
7. Update `ReleaseNotes.md` if component versions change (base images, MDSD, Telegraf, Fluent-bit)

## Validation
- Docker images build successfully for all target platforms
- `helm lint` passes for all modified charts
- `helm template` produces valid Kubernetes manifests with no rendering errors
- Trivy scan shows no new HIGH/CRITICAL vulnerabilities (or findings are documented in `.trivyignore`)
- Existing Helm values continue to work (backward compatibility)
- Agent pods start successfully with the new image (liveness/readiness probes pass)
- PR CI checks pass: pr-checker.yml (includes image build and Trivy scan)

## Risks and Guardrails
- **Base image CVEs**: Always check Trivy results when updating base images; new base versions can introduce vulnerabilities
- **Multi-arch consistency**: Changes to `Dockerfile.multiarch` must work on both AMD64 and ARM64 architectures
- **Helm backward compatibility**: Chart changes must not break `helm upgrade` for existing deployments; new values need defaults
- **Chart version discipline**: Always bump `Chart.yaml` version when chart content changes; follow semver
- **Resource limits**: Changing CPU/memory limits affects cluster capacity planning; validate with load testing
- **Windows parity**: If a Linux Dockerfile change adds a new component, evaluate whether the Windows Dockerfile needs the equivalent
- **Build layer ordering**: Keep frequently-changing layers (source code copy, build steps) at the end of Dockerfiles to maximize cache hits
- **MARINER.md**: Base image changes for CBL-Mariner should be reflected in `MARINER.md` documentation
- **Multiple chart variants**: Changes often need to be applied to all three chart directories; missing one causes drift

## Examples from This Repo
- Dockerfile.multiarch uses multi-stage builds with separate builder and runtime stages for Go plugins
- Helm charts define DaemonSets for the agent with configurable resource limits, tolerations, and node selectors
- Chart.yaml versions follow semver; patch bumps for bug fixes, minor bumps for new features
- Base image updates in Dockerfiles are paired with ReleaseNotes.md updates listing the new component versions
- Infrastructure changes represent the largest commit category (51 commits in 12 months) due to frequent image and chart updates
