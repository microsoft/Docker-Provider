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
6. Update following pipeline variables under ReleaseCandiate with version of chart and image tag
    - CIHELMCHARTVERSION <VersionValue> # For example, 2.7.4
    - CIImageTagSuffix <ImageTag> # ciprod08072020 or ciprod08072020-1 etc.
7. Merge ci_dev and ci_prod branch which will trigger automatic deployment of latest bits to CIPROD cluster with CIPROD`<MM><DD><YYYY>` image to test and scale cluters, AKS, AKS-Engine
   > Note: production image automatically pushed to CIPROD Public cloud ACR which will inturn replicated to Public cloud MCR.
8. Validate all the scenarios against clusters in build subscription and scale clusters


# 2. Perf and scale testing

Deploy latest omsagent yaml with release candidate agent image in to supported k8s versions and validate all the critical scenarios. In perticular, throughly validate the updates going as part of this release and also make sure no regressions. If  this passes, deploy onto scale cluster and  validate perf and scale aspects. Scale cluster in AME cloud and co-ordinate with agent team who has access to this cluster to deploy  the release candiate onto this cluster.

# 3. Production Image to MCR CN for Azure China Cloud

Image automatically synched to MCR CN from Public cloud MCR.

# 4. Release of the agent

## AKS

- Refer to internal docs for the release process and instructions.

## ARO v3

This needs to be co-ordinated with Red hat  and ARO-RP team for the release and Red hat team will pick up the changes for the release.

## AKS-Engine

Make PR against [AKS-Engine](https://github.com/Azure/aks-engine). Refer PR https://github.com/Azure/aks-engine/pull/2318

## ARO v4, Azure Arc K8s and OpenShift v4 clusters

Make sure azuremonitor-containers chart yamls updates with all changes going with the release and also make sure to bump the chart version, imagetag and docker provider version etc. Similar to agent container image, build pipeline automatically push the chart to container insights prod acr for canary and prod repos accordingly.
Both the agent and helm chart will be replicated to `mcr.microsoft.com`.

The way, customers will be onboard the monitoring to these clusters using onboarding scripts under `onboarding\managed` directory so please bump chart version for prod release. Once we move to Arc K8s Monitoring extension Public preview, these will be taken care so at that point of time no manual changes like this required.

## Microsoft Charts Repo release for On-prem K8s

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
