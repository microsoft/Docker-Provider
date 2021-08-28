# Release Instructions

# 1. Production agent image and automatic deployment to CIPROD cluster

Here are the high-level instructions to get the CIPROD`<MM><DD><YYYY>` image for the production release
1. create feature branch from ci_dev and make the following updates
      > Note: This required since Azure Dev Ops pipeline doesnt support --build-arg yet to automate this.
   - Ensure IMAGE_TAG updated with release candiate image tag in the DockerFile under kubernetes/linux and kubernetes/windows directory
   - Update the version file under build directory with build version and date
   - Update omsagent.yaml for the image tag and dockerProviderVersion, and any other changes
   - Update the chart version and image tags in values.yaml under charts/azuremonitor-containers
   - Release notes
2. Make PR to ci_dev branch and once the PR approved, merge the changes to ci_dev
3. Latest bits of ci_dev automatically deployed to CIDEV cluster in build subscription so just validated E2E to make sure everthing works
4. If everything validated in DEV, make merge PR from ci_dev and ci_prod and merge once this reviewed by dev team
5. Once the PR to ci_prod approved, please go-ahead and merge, and wait for ci_prod build successfully completed
6. Once the merged PR build successfully completed, update the value of AGENT_IMAGE_TAG_SUFFIX pipeline  variable by editing the Release [ci-prod-release](https://github-private.visualstudio.com/microsoft/_release?_a=releases&view=mine&definitionId=38)
   > Note - value format of AGENT_IMAGE_TAG_SUFFIX pipeline should be in  `<MM><DD><YYYY>` for our releases
7. Create a release by selecting the targetted build version  of the _docker-provider_Official-ci_prod release
8. Validate all the scenarios against clusters in build subscription and scale clusters

# 2. Perf and scale testing

Deploy latest omsagent yaml with release candidate agent image in to supported k8s versions and validate all the critical scenarios. In perticular, throughly validate the updates going as part of this release and also make sure no regressions. If  this passes, deploy onto scale cluster and  validate perf and scale aspects. Scale cluster in AME cloud and co-ordinate with agent team who has access to this cluster to deploy  the release candiate onto this cluster.

# 3. Production Image to MCR CN for Azure China Cloud

Image automatically synched to MCR CN from Public cloud MCR.

# 4. Release of the agent

## AKS

- Refer to internal docs for the release process and instructions.

## AKS-Engine

Make PR against [AKS-Engine](https://github.com/Azure/aks-engine). Refer PR https://github.com/Azure/aks-engine/pull/2318

## Arc for Kubernetes

Ev2 pipeline used to deploy the chart of the Arc K8s Container Insights Extension as per Safe Deployment Process.
Here is the high level process
```
 1. Specify chart version of the release candidate and trigger [container-insights-arc-k8s-extension-ci_prod-release](https://github-private.visualstudio.com/microsoft/_release?_a=releases&view=all)
 2. Get the approval from one of team member for the release
 3. Once the approved, release should be triggered automatically
 4. use `cimon-arck8s-eastus2euap` for validating latest release in canary region
 5. TBD - Notify vendor team for the validation on all Arc K8s supported platforms
```

## Microsoft Charts Repo release for On-prem K8s
> Note: This chart repo being used in the ARO v4 onboarding script as well.

Since HELM charts repo being deprecated, Microsoft charts repo being used for HELM chart release of on-prem K8s clusters.
To make chart release PR, fork [Microsoft-charts-repo]([https://github.com/microsoft/charts/tree/gh-pages) and make the PR against `gh-pages` branch of the upstream repo.

Refer PR - https://github.com/microsoft/charts/pull/23 for example.
Once the PR merged, latest version of HELM chart should be available in couple of mins in https://microsoft.github.io/charts/repo and https://artifacthub.io/.

Instructions to create PR
```
# 1. create helm package for the release candidate
   git clone git@github.com:microsoft/Docker-Provider.git
   git checkout ci_prod
   cd ~/Docker-Provider/charts/azuremonitor-containers # this path based on where you have cloned the repo
   helm package .

# 2. clone your fork repo and checkout gh_pages branch # gh_pages branch used as release branch
   cd ~
   git clone <your-forked-repo-of-microsoft-charts-repo>
   cd  ~/charts # assumed the root dir of the clone is charts
   git checkout gh_pages

# 3. copy release candidate helm package
   cd ~/charts/repo/azuremonitor-containers
   # update chart version value with the version of chart being released
   cp ~/Docker-Provider/charts/azuremonitor-containers/azuremonitor-containers-<chart-version>.tgz  .
   cd ~/charts/repo
   # update repo index file
   helm repo index  .

# 4. Review the changes and make PR. Please note, you may need to revert unrelated changes automatically added by `helm repo index .` command

```

# 4. Monitor agent roll-out status

In Container Insights Agent (AKS) telemetry dashboard, update the agent roll status by  region chart with released agent image and track rollout status. If you see any issues with agent rollout, reach out AKS on-call team for the help on investigation and understanding whats going on.
