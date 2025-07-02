# CI Release Automation Output

## Step 1: Docker-Provider Build Trigger

Build triggered successfully with the following details:
- Build ID: 101202
- Build Number: 20250625.3
- Definition: ContainerInsights-MultiArch-MergedBranches
- Branch: ci_prod
- Status: Queued
- Build URL: [Build 101202](https://github-private.visualstudio.com/546fe6cc-3ea0-4218-9233-c28bfc2f36ca/_build/results?buildId=101202)

The build has been queued with TELEMETRY_TAG set to 3.1.28. Please monitor the build progress using the URL above.

## Step 5: AKS RP Changes for CI CD Clusters

Successfully updated the image version for CI CD clusters in AKS RP repo:
- Linux toggle file (`omsagent-image-tag-linux.yaml`): Updated from 3.1.27 to 3.1.28
- Windows toggle file (`omsagent-image-tag-windows.yaml`): Updated from win-3.1.27 to win-3.1.28

The changes were made only to the first matcher block which controls the CI CD clusters configuration.

## Step 6: Trigger Test Automation pipeline

Build triggered successfully: https://github-private.visualstudio.com/microsoft/_build/results?buildId=101417&view=results

## ## Step 7: AKS RP Changes for Cosmic Clusters

Successfully updated the image version for Cosmic clusters in AKS RP repo:

- Linux toggle file (`omsagent-image-tag-linux.yaml`): Updated from 3.1.27 to 3.1.28
- Windows toggle file (`omsagent-image-tag-windows.yaml`): Updated from win-3.1.27 to win-3.1.28

The changes were made only to the second matcher block which controls the Cosmic clusters configuration. Changes have been committed and pushed to branch: containerinsights/cosmic-release-3.1.28
