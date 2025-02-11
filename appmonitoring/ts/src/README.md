# MutatingWebhook


# Making a change to the image
1. Prepare a change in a branch made off of _ai_prod_ branch. All work is confined within _appmonitoring/ts/src_.
2. Make sure the branch builds locally with _build.cmd_.
3. Build and push the image to a test ACR by running _dockerBuild.cmd v0_ where _v0_ is the image tag.
4. Test the change by referencing the _v0_ version of the image in AKS RP's yaml and either
   - creating a standalone environment with it, or
   - manually applying it to a cluster
5. Run [end-to-end validation pipeline](https://github-private.visualstudio.com/microsoft/_build?definitionId=543&_a=summary) on the branch to smoke test it end-to-end. This won't guarantee that end-to-end will work post-merge, but this validation is too heavy for a PR gate.
6. Merge a PR into the _ai_prod_ branch.
7. Run [end-to-end validation pipeline](https://github-private.visualstudio.com/microsoft/_build?definitionId=543&_a=summary) on _ai_prod_ to ensure end-to-end passes.
7. Tag the _ai_prod_ branch's head (_semver_ tag, e.g. _appmonitoring-1.0.0-beta.1_).
   - checkout _ai_prod_
   - _git tag -a appmonitoring-1.0.0-beta.1 -m "appmonitoring-1.0.0-beta.1 release tag"_
   - _git push origin appmonitoring-1.0.0-beta.1_
8. Prepare a GitHub release based on the newly create tag (e.g. [Public Preview beta.2](https://github.com/microsoft/Docker-Provider/releases/tag/appmonitoring-1.0.0-beta.2)).
9. Build _ai_prod_ via the [ContainerInsights-MultiArch-MergedBranches-AppMonitoring](https://github-private.visualstudio.com/microsoft/_build?definitionId=539) build pipeline. Make sure the tag already exists at the time when this is run. Do not use old builds that ran before tagging was done.
10. Build _ai_prod_ via the [validation pipeline](https://github-private.visualstudio.com/microsoft/_build?definitionId=543&_a=summary) build pipeline. Make sure the tag already exists at the time when this is run. Do not use old builds that ran before tagging was done.
11. Push the image to MCR by releasing the build via the [application-insights-prod-release](https://github-private.visualstudio.com/microsoft/_release?definitionId=73&view=mine&_a=releases) release. Pick the build from step 9. The image is now publicly available.
12. Merge a PR into the AKS RP repo that updates the version of the image used.
13. Follow daily and weekly rollouts of AKS RP and watch change propagation on the dashboard.