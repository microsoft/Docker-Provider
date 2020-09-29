<#
    .DESCRIPTION
    	Upgrades the Kubernetes cluster that has been onboarded to monitoring to a version of the agent
	that generates health monitor signals
	1. Installs necessary powershell modules
	2. Onboards Container Insights solution to the supplied LA workspace if not already onboarded
	3. Updates the cluster metadata to link the LA workspace ID to the cluster
    .PARAMETER aksResourceId
        Name of the cluster configured on the OMSAgent
    .PARAMETER loganalyticsWorkspaceResourceId
        Azure ResourceId of the log analytics workspace Id
    .PARAMETER aksResourceLocation
        Resource location of the AKS cluster resource
#>
param(
    [Parameter(mandatory = $true)]
    [string]$aksResourceId,
    [Parameter(mandatory = $true)]
    [string]$aksResourceLocation,
    [Parameter(mandatory = $true)]
    [string]$logAnalyticsWorkspaceResourceId
)


$OptOutLink = "https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-optout"

# checks the required Powershell modules exist and if not exists, request the user permission to install
$azAccountModule = Get-Module -ListAvailable -Name Az.Accounts
$azResourcesModule = Get-Module -ListAvailable -Name Az.Resources
$azOperationalInsights = Get-Module -ListAvailable -Name Az.OperationalInsights
$azAks = Get-Module -ListAvailable -Name Az.Aks

if (($null -eq $azAccountModule) -or ($null -eq $azResourcesModule) -or ($null -eq $azOperationalInsights)) {

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host("Running script as an admin...")
        Write-Host("")
    }
    else {
        Write-Host("Please re-launch the script with elevated administrator") -ForegroundColor Red
        Stop-Transcript
        exit
    }

    $message = "This script will try to install the latest versions of the following Modules : `
			    Az.Resources, Az.Accounts, Az.Aks and Az.OperationalInsights using the command`
			    `'Install-Module {Insert Module Name} -Repository PSGallery -Force -AllowClobber -ErrorAction Stop -WarningAction Stop'
			    `If you do not have the latest version of these Modules, this troubleshooting script may not run."
    $question = "Do you want to Install the modules and run the script or just run the script?"

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes, Install and run'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Continue without installing the Module'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Quit'))

    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 0)

    switch ($decision) {
        0 {

            if ($null -eq $azResourcesModule) {
                try {
                    Write-Host("Installing Az.Resources...")
                    Install-Module Az.Resources -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules forAz.Accounts in a new powershell window: eg. 'Install-Module Az.Accounts -Repository PSGallery -Force'") -ForegroundColor Red
                    exit
                }
            }

            if ($null -eq $azAccountModule) {
                try {
                    Write-Host("Installing Az.Accounts...")
                    Install-Module Az.Accounts -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules forAz.Accounts in a new powershell window: eg. 'Install-Module Az.Accounts -Repository PSGallery -Force'") -ForegroundColor Red
                    exit
                }
            }

            if ($null -eq $azOperationalInsights) {
                try {

                    Write-Host("Installing AzureRM.OperationalInsights...")
                    Install-Module Az.OperationalInsights -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules for AzureRM.OperationalInsights in a new powershell window: eg. 'Install-Module AzureRM.OperationalInsights -Repository PSGallery -Force'") -ForegroundColor Red
                    exit
                }
            }
            if ($null -eq $azAks) {
                try {

                    Write-Host("Installing Az.Aks...")
                    Install-Module Az.Aks -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules for AzureRM.OperationalInsights in a new powershell window: eg. 'Install-Module AzureRM.OperationalInsights -Repository PSGallery -Force'") -ForegroundColor Red
                    exit
                }
            }


        }
        1 {

            if ($null -eq $azResourcesModule) {
                try {
                    Import-Module Az.Resources -ErrorAction Stop
                }
                catch {
                    Write-Host("Could not import Az.Resources...") -ForegroundColor Red
                    Write-Host("Close other powershell logins and try installing the latest modules for Az.Resources in a new powershell window: eg. 'Install-Module Az.Resources -Repository PSGallery -Force'") -ForegroundColor Red
                    Stop-Transcript
                    exit
                }
            }
            if ($null -eq $azAccountModule) {
                try {
                    Import-Module Az.Accounts -ErrorAction Stop
                }
                catch {
                    Write-Host("Could not import Az.Accounts...") -ForegroundColor Red
                    Write-Host("Close other powershell logins and try installing the latest modules for Az.Accounts in a new powershell window: eg. 'Install-Module Az.Accounts -Repository PSGallery -Force'") -ForegroundColor Red
                    Stop-Transcript
                    exit
                }
            }

            if ($null -eq $azAccountModule) {
                try {
                    Import-Module Az.OperationalInsights
                }
                catch {
                    Write-Host("Could not import Az.OperationalInsights... Please reinstall this Module") -ForegroundColor Red
                    Stop-Transcript
                    exit
                }
            }

        }
        2 {
            Write-Host("")
            Stop-Transcript
            exit
        }
    }
}

if ([string]::IsNullOrEmpty($logAnalyticsWorkspaceResourceId)) {
    Write-Host("logAnalyticsWorkspaceResourceId should not be NULL or empty") -ForegroundColor Red
    exit
}

if (($logAnalyticsWorkspaceResourceId -match "/providers/Microsoft.OperationalInsights/workspaces") -eq $false) {
    Write-Host("logAnalyticsWorkspaceResourceId should be valid Azure Resource Id format") -ForegroundColor Red
    exit
}

$workspaceResourceDetails = $logAnalyticsWorkspaceResourceId.Split("/")

if ($workspaceResourceDetails.Length -ne 9) {
    Write-Host("logAnalyticsWorkspaceResourceId should be valid Azure Resource Id format") -ForegroundColor Red
    exit
}

$workspaceSubscriptionId = $workspaceResourceDetails[2]
$workspaceSubscriptionId = $workspaceSubscriptionId.Trim()
$workspaceResourceGroupName = $workspaceResourceDetails[4]
$workspaceResourceGroupName = $workspaceResourceGroupName.Trim()
$workspaceName = $workspaceResourceDetails[8]
$workspaceResourceGroupName = $workspaceResourceGroupName.Trim()

$aksResourceDetails = $aksResourceId.Split("/")
$clusterResourceGroupName = $aksResourceDetails[4].Trim()
$clusterSubscriptionId = $aksResourceDetails[2].Trim()
$clusterName = $aksResourceDetails[8].Trim()

Write-Host("LogAnalytics Workspace SubscriptionId : '" + $workspaceSubscriptionId + "' ") -ForegroundColor Green

try {
    Write-Host("")
    Write-Host("Trying to get the current Az login context...")
    $account = Get-AzContext -ErrorAction Stop
    Write-Host("Successfully fetched current AzContext context...") -ForegroundColor Green
    Write-Host("")
}
catch {
    Write-Host("")
    Write-Host("Could not fetch AzContext..." ) -ForegroundColor Red
    Write-Host("")
}


if ($null -eq $account.Account) {
    try {
        Write-Host("Please login...")
        Connect-AzAccount -subscriptionid $clusterSubscriptionId
    }
    catch {
        Write-Host("")
        Write-Host("Could not select subscription with ID : " + $clusterSubscriptionId + ". Please make sure the ID you entered is correct and you have access to the cluster" ) -ForegroundColor Red
        Write-Host("")
        Stop-Transcript
        exit
    }
}

Write-Host("Checking if cluster is onboarded to Container Monitoring")
if ($account.Subscription.Id -eq $clusterSubscriptionId) {
    Write-Host("Subscription: $clusterSubscriptionId is already selected. Account details: ")
    $account
}
else {
    try {
        Write-Host("Current Subscription:")
        $account
        Write-Host("Changing to workspace subscription: $clusterSubscriptionId")
        Set-AzContext -SubscriptionId $clusterSubscriptionId

    }
    catch {
        Write-Host("")
        Write-Host("Could not select subscription with ID : " + $workspaceSubscriptionId + ". Please make sure the ID you entered is correct and you have access to the cluster" ) -ForegroundColor Red
        Write-Host("")
        Stop-Transcript
        exit
    }
}

try {
    $resources = Get-AzResource -ResourceGroupName $clusterResourceGroupName -Name $clusterName -ResourceType "Microsoft.ContainerService/managedClusters" -ExpandProperties -ErrorAction Stop -WarningAction Stop
    $clusterResource = $resources[0]

    $props = ($clusterResource.Properties | ConvertTo-Json).toLower() | ConvertFrom-Json

    if ($true -eq $props.addonprofiles.omsagent.enabled -and $null -ne $props.addonprofiles.omsagent.config) {
        Write-Host("Your cluster is already onboarded to Azure monitor for containers. Please refer to the following documentation to opt-out and re-run this script again:") -ForegroundColor Red;
        Write-Host("")
        Write-Host($OptOutLink) -ForegroundColor Red
        Write-Host("")
        throw
    }

    Write-Host("Setting context to the current cluster")
    Import-AzAksCredential -Id $aksResourceId -Force
    $omsagentCount = kubectl get pods -n kube-system | Select-String omsagent
    if ($null -eq $omsagentCount) {
        Write-Host ("OmsAgent is not running. Proceeding to do custom onboarding for Health Agent")
    }
    else {
        Write-Host ("Cluster is not enabled for Monitoring. But detected omsagent pods. Please wait for 30 min to ensure that omsagent containers are completely stopped and re-run this script") -ForegroundColor Red
        Stop-Transcript
        exit
    }
}
catch {
    Write-Host("Error when checking if cluster is already onboarded")
    exit
}


if ($account.Subscription.Id -eq $workspaceSubscriptionId) {
    Write-Host("Subscription: $workspaceSubscriptionId is already selected. Account details: ")
    $account
}
else {
    try {
        Write-Host("Current Subscription:")
        $account
        Write-Host("Changing to workspace subscription: $workspaceSubscriptionId")
        Set-AzContext -SubscriptionId $workspaceSubscriptionId
    }
    catch {
        Write-Host("")
        Write-Host("Could not select subscription with ID : " + $workspaceSubscriptionId + ". Please make sure the ID you entered is correct and you have access to the cluster" ) -ForegroundColor Red
        Write-Host("")
        Stop-Transcript
        exit
    }
}

$WorkspaceInformation = Get-AzOperationalInsightsWorkspace -ResourceGroupName $workspaceResourceGroupName -Name $workspaceName -ErrorAction Stop
$key = (Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $workspaceResourceGroupName -Name $workspaceName).PrimarySharedKey
$wsid = $WorkspaceInformation.CustomerId
$base64EncodedKey = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($key))
$base64EncodedWsId = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($wsid))
Write-Host("Successfully verified specified logAnalyticsWorkspaceResourceId valid and exists...") -ForegroundColor Green
$WorkspaceLocation = $WorkspaceInformation.Location

if ($null -eq $WorkspaceLocation) {
    Write-Host("")
    Write-Host("Cannot fetch workspace location. Please try again...") -ForegroundColor Red
    Write-Host("")
    Stop-Transcript
    exit
}

try {
    $WorkspaceIPDetails = Get-AzOperationalInsightsIntelligencePacks -ResourceGroupName $workspaceResourceGroupName -WorkspaceName $workspaceName -ErrorAction Stop
    Write-Host("Successfully fetched workspace IP details...") -ForegroundColor Green
    Write-Host("")
}
catch {
    Write-Host("")
    Write-Host("Failed to get the list of solutions onboarded to the workspace. Please make sure that it hasn't been deleted and you have access to it.") -ForegroundColor Red
    Write-Host("")
    Stop-Transcript
    exit
}

try {
    $ContainerInsightsIndex = $WorkspaceIPDetails.Name.IndexOf("ContainerInsights");
    Write-Host("Successfully located ContainerInsights solution") -ForegroundColor Green
    Write-Host("")
}
catch {
    Write-Host("Failed to get ContainerInsights solution details from the workspace") -ForegroundColor Red
    Write-Host("")
    Stop-Transcript
    exit
}

$isSolutionOnboarded = $WorkspaceIPDetails.Enabled[$ContainerInsightsIndex]

if ($false -eq $isSolutionOnboarded) {

    $DeploymentName = "ContainerInsightsSolutionOnboarding-" + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')
    $Parameters = @{ }
    $Parameters.Add("workspaceResourceId", $logAnalyticsWorkspaceResourceID)
    $Parameters.Add("workspaceRegion", $WorkspaceLocation)
    $Parameters

    try {
        New-AzResourceGroupDeployment -Name $DeploymentName `
            -ResourceGroupName $workspaceResourceGroupName `
            -TemplateUri  https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/templates/azuremonitor-containerSolution.json `
            -TemplateParameterObject $Parameters -ErrorAction Stop`


        Write-Host("Successfully added Container Insights Solution") -ForegroundColor Green

    }
    catch {
        Write-Host ("Template deployment failed with an error: '" + $Error[0] + "' ") -ForegroundColor Red
        Write-Host("Please contact us by emailing askcoin@microsoft.com for help") -ForegroundColor Red
    }

}

Write-Host("Successfully added Container Insights Solution to workspace " + $workspaceName)  -ForegroundColor Green

try {
    $Parameters = @{ }
    $Parameters.Add("aksResourceId", $aksResourceId)
    $Parameters.Add("aksResourceLocation", $aksResourceLocation)
    $Parameters.Add("workspaceResourceId", $logAnalyticsWorkspaceResourceId)
    $DeploymentName = "ClusterHealthOnboarding-" + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')
    $Parameters

    Write-Host " Onboarding cluster to provided LA workspace "

    if ($account.Subscription.Id -eq $clusterSubscriptionId) {
        Write-Host("Subscription: $clusterSubscriptionId is already selected. Account details: ")
        $account
    }
    else {
        try {
            Write-Host("Current Subscription:")
            $account
            Write-Host("Changing to subscription: $clusterSubscriptionId")
            Set-AzContext -SubscriptionId $clusterSubscriptionId
        }
        catch {
            Write-Host("")
            Write-Host("Could not select subscription with ID : " + $workspaceSubscriptionId + ". Please make sure the ID you entered is correct and you have access to the cluster" ) -ForegroundColor Red
            Write-Host("")
            Stop-Transcript
            exit
        }
    }

    Write-Host("Enabling Custom Monitoring using template deployment")
    New-AzResourceGroupDeployment -Name  $DeploymentName `
        -ResourceGroupName $clusterResourceGroupName `
        -TemplateUri  https://raw.githubusercontent.com/Microsoft/OMS-docker/dilipr/onboardHealth/health/customOnboarding.json `
        -TemplateParameterObject $Parameters -ErrorAction Stop`

    Write-Host("")

    Write-Host("Successfully custom onboarded cluster to Monitoring") -ForegroundColor Green

    Write-Host("")
}
catch {
    Write-Host ("Template deployment failed with an error: '" + $Error[0] + "' ") -ForegroundColor Red
    exit
    #Write-Host("Please contact us by emailing askcoin@microsoft.com for help") -ForegroundColor Red
}

$desktopPath = "~"
if (-not (test-path $desktopPath/deployments) ) {
    Write-Host "$($desktopPath)/deployments doesn't exist, creating it"
    mkdir $desktopPath/deployments | out-null
}
else {
    Write-Host "$($desktopPath)/deployments exists, no need to create it"
}
try {

    $aksResourceDetails = $aksResourceId.Split("/")
    if ($aksResourceDetails.Length -ne 9) {
        Write-Host("aksResourceDetails should be valid Azure Resource Id format") -ForegroundColor Red
        exit
    }
    $clusterName = $aksResourceDetails[8].Trim()
    $clusterResourceGroupName = $aksResourceDetails[4].Trim()
    Import-AzAksCredential -Id $aksResourceId -Force
    Invoke-WebRequest https://raw.githubusercontent.com/microsoft/OMS-docker/dilipr/mergeHealthToCiFeature/health/omsagent-template.yaml -OutFile $desktopPath/omsagent-template.yaml

    (Get-Content -Path $desktopPath/omsagent-template.yaml -Raw) -replace 'VALUE_AKS_RESOURCE_ID', $aksResourceId -replace 'VALUE_AKS_REGION', $aksResourceLocation -replace 'VALUE_WSID', $base64EncodedWsId -replace 'VALUE_KEY', $base64EncodedKey -replace 'VALUE_ACS_RESOURCE_NAME', $acsResourceName | Set-Content $desktopPath/deployments/omsagent-$clusterName.yaml
    kubectl apply -f $desktopPath/deployments/omsagent-$clusterName.yaml
    Write-Host "Successfully onboarded to health model omsagent" -ForegroundColor Green
}
catch {
    Write-Host ("Agent deployment failed with an error: '" + $Error[0] + "' ") -ForegroundColor Red
}
