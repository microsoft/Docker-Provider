# This script is only for AKS cluster testing. It reads the template files (Chart-template.yaml and values-template.yaml),
# replaces placeholders with actual values, and then writes the modified content back to new files (Chart.yaml and values.yaml).
# The placeholders replaced include HELM_SEMVER, IMAGE_TAG, IMAGE_TAG_WINDOWS, and INCLUDE_DEPENDENT_CHARTS.
#
# NOTE: this renders the chart for a plain `helm install`, which BYPASSES the cluster-extension platform.
# The platform-injected identity / token adapter (Azure.Identity.AADMsiTokenAdapter*Yaml) will NOT be present,
# so use this to validate templating and that pods come up - not the managed-extension identity path.

# Define variables
$ImageTag = "3.4.0"
$ImageTagWindows = "win-3.4.0"
$ChartVersion = "0.0.0-localtest"
$AKSResourceId = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<cluster>"

# Read files
$chartTemplatePath = ".\Chart-template.yaml"
$valuesTemplatePath = ".\values-template.yaml"

$chartTemplateContent = Get-Content -Path $chartTemplatePath -Raw
$valuesTemplateContent = Get-Content -Path $valuesTemplatePath -Raw

# Create copies of the files
$chartOutputPath = ".\Chart.yaml"
$valuesOutputPath = ".\values.yaml"
$chartTemplateContent | Out-File -FilePath $chartOutputPath
$valuesTemplateContent | Out-File -FilePath $valuesOutputPath

# Replace placeholders in Chart-template.yaml
$chartTemplateContent = $chartTemplateContent -replace '\$\{HELM_SEMVER\}', $ChartVersion
$chartTemplateContent = $chartTemplateContent -replace '\$\{IMAGE_TAG\}', $ImageTag

# Replace placeholders in values-template.yaml
$valuesTemplateContent = $valuesTemplateContent -replace '\$\{IMAGE_TAG\}', $ImageTag
$valuesTemplateContent = $valuesTemplateContent -replace '\$\{IMAGE_TAG_WINDOWS\}', $ImageTagWindows
$valuesTemplateContent = $valuesTemplateContent -replace '\$\{INCLUDE_DEPENDENT_CHARTS\}', 'false'
$valuesTemplateContent = $valuesTemplateContent -replace '\$\{HELM_SEMVER\}', $ChartVersion

# Write the modified content back to the files
$chartTemplateContent | Out-File -FilePath $chartOutputPath
$valuesTemplateContent | Out-File -FilePath $valuesOutputPath

Write-Host "Files have been processed and saved as Chart.yaml and values.yaml"

# To install onto the AKS cluster in your current kube context, run:
#   helm upgrade --install ama-logs-ext-test . --namespace kube-system --create-namespace --set global.commonGlobals.Customer.AzureResourceID=$AKSResourceId
