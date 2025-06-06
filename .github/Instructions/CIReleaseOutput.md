# CI Release Automation Output

## Step 1: Trigger Docker-Provider Build
- Started at: 2025-06-06 16:07:04 PDT
- Build Definition: 444
- Branch: ci_prod
- Variables:
  - TELEMETRY_TAG: preview-3.1.28
- Build Details:
  - Build ID: 100127
  - Build Number: 20250606.10
  - Status: Running (Started at 2025-06-06 23:07:53 GMT+00:00)
  - Duration: 50 seconds
  - URL: https://github-private.visualstudio.com/546fe6cc-3ea0-4218-9233-c28bfc2f36ca/_build/results?buildId=100127

## Step 2: Verify Docker-Provider Build
- Status: Skipped as per user request

## Step 3: Trigger MCR Publish Build
- Started at: 2025-06-06 16:09:28 PDT
- Build Definition: 1032
- Branch: ci_prod
- Variables:
  - VAR_AGENT_IMAGE_TAG_SUFFIX: preview-3.1.28
- Build Details:
  - Build ID: 100128
  - Build Number: 20250606.3
  - Status: Running (Started at 2025-06-06 23:09:57 GMT+00:00)
  - URL: https://github-private.visualstudio.com/546fe6cc-3ea0-4218-9233-c28bfc2f36ca/_build/results?buildId=100128

## Step 4: Verify MCR Publish Build Completion
- Status: Skipped as per user request

## Step 5: Update AKS RP for CI CD clusters
- Modified Files:
  - toggles/global/sigs/containerinsights/omsagent-image-tag-linux.yaml: Updated first matcher block to version preview-3.1.28
  - toggles/global/sigs/containerinsights/omsagent-image-tag-windows.yaml: Updated first matcher block to version win-preview-3.1.28
  - Branch pushed to origin: update-omsagent-preview-3.1.28
  - Draft PR created: #12625807 (https://msazure.visualstudio.com/CloudNativeCompute/_git/aks-rp/pullrequest/12625807)

## Step 6: Trigger Test Automation Pipeline
- Started at: 2025-06-06 16:13:44 PDT
- Build Definition: 950 (container-insights-test-automation)
- Branch: ci_prod
- Build Details:
  - Build ID: 100130
  - Build Number: 20250606.2
  - Status: Running (Started at 2025-06-06 23:13:44 GMT+00:00)
  - URL: https://github-private.visualstudio.com/546fe6cc-3ea0-4218-9233-c28bfc2f36ca/_build/results?buildId=100130
