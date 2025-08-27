# MutatingWebhook


# Making a change to the image
1. Prepare a change in a branch made off of _ai_prod_ branch. All work is confined within _appmonitoring/ts/src_.
2. Make sure the branch builds locally with _build.cmd_.
3. Build and push the image to a test ACR by running _dockerBuild.cmd v0_ where _v0_ is the image tag.
4. Test the change by referencing the _v0_ version of the image in AKS RP's yaml and either
   - creating a standalone environment with it, or
   - manually applying it to a cluster
5. Make sure SDKs that the image references are up to date.
   - for each supported SDK check the current version [here](https://github.com/microsoft/Docker-Provider/blob/ai_prod/appmonitoring/ts/src/Mutations.ts#L12).
   - check if there's a newer image:
     - [NodeJs](https://mcr.microsoft.com/v2/applicationinsights/opentelemetry-auto-instrumentation/nodejs/tags/list)
     - [Java](https://mcr.microsoft.com/v2/applicationinsights/auto-instrumentation/java/tags/list).
     - [Python](https://mcr.microsoft.com/v2/applicationinsights/auto-instrumentation/python/tags/list).
     - [.NET](https://mcr.microsoft.com/v2/applicationinsights/opentelemetry-auto-instrumentation/dotnet/tags/list).
   - check Statsbeat to find the latest version that is over 2% threshold for adoption.
     - get permission [here](https://coreidentity.microsoft.com/manage/Entitlement/entitlement/statsbeatpar-5qr1).
     - run the query and find the highest version that is newer than the current one and is over 2% adoption: [CORP](https://ms.portal.azure.com#@72f988bf-86f1-41af-91ab-2d7cd011db47/blade/Microsoft_OperationsManagementSuite_Workspace/Logs.ReactView/resourceId/%2Fsubscriptions%2F69b79536-2ddd-441e-a80e-88259ff90e28%2Fresourcegroups%2Fstatsbeat%2Fproviders%2Fmicrosoft.operationalinsights%2Fworkspaces%2Fla-statsbeat/source/LogsBlade.AnalyticsShareLinkToQuery/q/H4sIAAAAAAAAA3WSS2%252BDMBCE7%252F0VFlIVqDAhgEKsKpVy6qWteqh6rTZmkzgPjGyTNFV%252FfE0e4CjNEc83y87Y%252FT5ZA9UGjJ4iGAJlQXaoDdYURHe8k2qlK%252BCo79ZoCLeYKMDgJyotZEnGxEujPEq8x0v9Bcp5DXNsgCVswep12Rjagb4XJ5gCwwFFViDNIB5RlmRTOoABG8YxY2nKvCCaVNUrGiW4Dl33CEbDPJ8OacGTjGYJcApxijRPZinDNGF5Chfuu1%252ByW6BC8iE2%252BIwlKrtnQZ4IzKWfZIugBd5gYxcfk97EGOCLnhXw26BtaN3FMlLbseXcf1eyQmUE6ugsB51j2xb1n%252BGkOryqbqCqciixwv0Njjeag8Ihww34KDq01DdIqbt%252BuhbG1zduKV1vNqDED5KCy7o0%252FmElMt23zvDci6WlKlA14hH%252BOmQrUPMWOnxZslJyidxQhUfP1bTQnXGxiA3EwfiDOI5i8tAIYuY7cPcvN9PplQek3zhcPgiJd%252B8Ff%252BWWCVJGAwAA).
   - if newer SDK versions are available - update them via a separate PR into _ai_prod_ before merging the main PR.
7. Run [end-to-end validation pipeline](https://github-private.visualstudio.com/microsoft/_build?definitionId=543&_a=summary) on the branch to smoke test it end-to-end. This won't guarantee that end-to-end will work post-merge, but this validation is too heavy for a PR gate.
8. Merge the PR into the _ai_prod_ branch.
9. Only if there's been a change to the Helm chart:
   - follow the instruction to update the Helm chart in validation pipeline [here](https://github.com/microsoft/Docker-Provider/blob/ai_prod/appmonitoring/validation-helm/Readme.md).
   - manually test helm install, helm upgrade, and helm rollback (rollback may happen if a release is rolled back). All must work.
11. Wait for the [end-to-end validation pipeline](https://github-private.visualstudio.com/microsoft/_build?definitionId=543&_a=summary) on _ai_prod_ to finish (with a partial success) to ensure end-to-end passes. 
12. Decide on the release tag in the semver format with the prefix `appmonitoring-` **This prefix is crucial as builds/releases won't pass otherwise** (_semver_ tag, e.g. _appmonitoring-1.0.0-beta.1_).
13. Prepare a GitHub release off of _ai_prod_ branch based on the newly create tag - you can use the release creation UX on GitHub to create a new tag (e.g. [Public Preview beta.2](https://github.com/microsoft/Docker-Provider/releases/tag/appmonitoring-1.0.0-beta.2)).
14. Build _ai_prod_ via the [validation pipeline](https://github-private.visualstudio.com/microsoft/_build?definitionId=543&_a=summary) build pipeline. Make sure the tag already exists at the time when this is run. 
15. Push the image to MCR by releasing the build via the [application-insights-prod-release](https://github-private.visualstudio.com/microsoft/_release?definitionId=73&view=mine&_a=releases) release. Pick the build from step 14. The image is now publicly available. Verify its been released by going to [this](https://mcr.microsoft.com/v2/azuremonitor/applicationinsights/aiprod/tags/list) link in MCR, you may have to wait up to 30 mins sometimes, but you should see the new tag in the list, this will be without the 'appmonitoring-' part so if your release tag was `appmonitoring-1.0.1` then the new released tag will be `1.0.1`
16. Complete the R2D process prior to continuing. Sample R2D request is [here](https://www.safefly.azure.com/safe-fly-request/r2d/295ce6c7-8933-49bf-8af2-3635cc7705e4?submittedBy=r2d).
17. Merge a PR into the AKS RP repo that updates the version of the image used. You need to update the image versions, as per your release tag that you did just now, [here](https://dev.azure.com/msazure/CloudNativeCompute/_git/aks-rp?path=/ccp/charts/addon-charts/app-monitoring-addon/Chart.yaml) and [here](https://dev.azure.com/msazure/CloudNativeCompute/_git/aks-rp?path=/ccp/control-plane-core/charts/kube-control-plane/templates/_images.tpl) in AKS RP repo. Note: you must regenerate Helm chart snapshots by running `make render-addon-chart-snapshots` from a WSL terminal in VSCode (from the repo root). See _ccp\charts\tests\addon-charts\README.md_ for details.
18. Follow daily and official rollouts of AKS RP and watch change propagation on the dashboard. After the AKS RP PR is merged, the first daily release should put the released bits in the Canary region. You can use our test clusters in that region to verify things look good (all clusters should be updated within 24h of the daily release getting to their region) [here](https://ms.portal.azure.com/#@microsoft.onmicrosoft.com/resource/subscriptions/5a3b3ba4-3a42-42ae-b2cb-f882345803bc/resourceGroups/aks-appmonitoring-canary-test/overview). _aks-appmonitoring-canary-test_ is configured via CR to send telemetry to this [AI Component](https://ms.portal.azure.com/#@microsoft.onmicrosoft.com/resource/subscriptions/5a3b3ba4-3a42-42ae-b2cb-f882345803bc/resourceGroups/aks-appmonitoring-canary-test/providers/microsoft.insights/components/aks-appmonitoring-canary-test/overview). Feel free to re deploy test apps there to validate functioning etc.
