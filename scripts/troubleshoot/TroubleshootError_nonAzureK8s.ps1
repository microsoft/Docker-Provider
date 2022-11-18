#
# ClassifyError.ps1
#
<#
    .DESCRIPTION
    This troubleshooting script detects and fixes the issues related to onboarding of Azure Monitor for containers to k8s outside of the Azure
    Below are the list of scenarios this script validates and fix the issues related
      1. Configured Azure Log Analytics workspace valid and exists
      2. Azure Log Analytics configured with the Container Insights solution. If not, configures
      3. ama-logs replicaset pod are running
      4. ama-logs daemonset pod are running
      5. Azure Log AnalyticsWorkspaceGuid and key configured on the agent matching with configured log analytics workspace
      6. Advises the user to check the version of the ama-logs running on the cluster, and update it to the latest version if it isn't the latest version already
      7. Provide the warn message to validate  Kubelet's cAdvisor configured with either secure port:10250 or unsecure port: 10255

    .PARAMETER azureLogAnalyticsWorkspaceResourceId
        Id of the Azure Log Analytics Workspace
    .PARAMETER kubeConfig
        kubeconfig of the k8 cluster
    .PARAMETER kubeConfig
        k8 cluster context in the Kubeconfig

     Pre-requisites:
      -  Contributor role permission on the Subscription of the Azure Arc Cluster
      -  kubectl https://kubernetes.io/docs/tasks/tools/install-kubectl/
      -  Kubeconfig of the K8s cluster
      -  Name of the cluster context in the Kubeconfig

#>

param(
    [Parameter(mandatory = $true)]
    [string]$azureLogAnalyticsWorkspaceResourceId,
    [Parameter(mandatory = $true)]
    [string]$kubeConfig,
    [Parameter(mandatory = $true)]
    [string]$clusterContextInKubeconfig
)

$ErrorActionPreference = "Stop";
$OptInLink = "https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-hybrid-setup"
Start-Transcript -path .\TroubleshootDumpForNonAzureK8s.txt -Force
$contactUSMessage = "Please contact us by emailing askcoin@microsoft.com for help"

Write-Host("LogAnalyticsWorkspaceResourceId: : '" + $azureLogAnalyticsWorkspaceResourceId + "' ")
if (($azureLogAnalyticsWorkspaceResourceId.ToLower().Contains("microsoft.operationalinsights/workspaces") -ne $true) -or ($azureLogAnalyticsWorkspaceResourceId.Split("/").Length -ne 9)) {
    Write-Host("Provided Azure Log Analytics resource id should be in this format /subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.OperationalInsights/workspaces/<workspaceName>") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

if ([string]::IsNullOrEmpty($kubeConfig)) {
    Write-Host("kubeConfig should not be NULL or empty") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

if ((Test-Path $kubeConfig -PathType Leaf) -ne $true) {
    Write-Host("provided kubeConfig path : '" + $kubeConfig + "' doesnt exist or you dont have read access") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

if ([string]::IsNullOrEmpty($clusterContextInKubeconfig)) {
    Write-Host("provide  clusterContext should be valid context in the provided kubeconfig") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

# checks the all required Powershell modules exist and if not exists, request the user permission to install
$azAccountModule = Get-Module -ListAvailable -Name Az.Accounts
$azResourcesModule = Get-Module -ListAvailable -Name Az.Resources
$azOperationalInsights = Get-Module -ListAvailable -Name Az.OperationalInsights

if (($null -eq $azAccountModule) -or ($null -eq $azResourcesModule) -or ($null -eq $azOperationalInsights)) {

    $isWindowsMachine = $true
    if ($PSVersionTable -and $PSVersionTable.PSEdition -contains "core") {
        if ($PSVersionTable.Platform -notcontains "win") {
            $isWindowsMachine = $false
        }
    }

    if ($isWindowsMachine) {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

        if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host("Running script as an admin...")
            Write-Host("")
        }
        else {
            Write-Host("Please re-launch the script with elevated administrator") -ForegroundColor Red
            Stop-Transcript
            exit 1
        }
    }

    $message = "This script will try to install the latest versions of the following Modules : `
			    Az.Resources, Az.Accounts  and Az.OperationalInsights using the command`
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
                    Stop-Transcript
                    exit 1
                }
            }

            if ($null -eq $azAccountModule) {
                try {
                    Write-Host("Installing Az.Accounts...")
                    Install-Module Az.Accounts -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules forAz.Accounts in a new powershell window: eg. 'Install-Module Az.Accounts -Repository PSGallery -Force'") -ForegroundColor Red
                    Stop-Transcript
                    exit 1
                }
            }

            if ($null -eq $azOperationalInsights) {
                try {

                    Write-Host("Installing Az.OperationalInsights...")
                    Install-Module Az.OperationalInsights -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules for Az.OperationalInsights in a new powershell window: eg. 'Install-Module Az.OperationalInsights -Repository PSGallery -Force'") -ForegroundColor Red
                    Stop-Transcript
                    exit 1
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
                    exit 1
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
                    exit 1
                }
            }

            if ($null -eq $azOperationalInsights) {
                try {
                    Import-Module Az.OperationalInsights -ErrorAction Stop
                }
                catch {
                    Write-Host("Could not import Az.OperationalInsights... Please reinstall this Module") -ForegroundColor Red
                    Stop-Transcript
                    exit 1
                }
            }

        }
        2 {
            Write-Host("")
            Stop-Transcript
            exit 1
        }
    }
}

$workspaceSubscriptionId = $azureLogAnalyticsWorkspaceResourceId.split("/")[2]
$workspaceResourceGroupName = $azureLogAnalyticsWorkspaceResourceId.split("/")[4]
$workspaceName = $azureLogAnalyticsWorkspaceResourceId.split("/")[8]
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
        Connect-AzAccount -subscriptionid $workspaceSubscriptionId
    }
    catch {
        Write-Host("")
        Write-Host("Could not select subscription with ID : " + $workspaceSubscriptionId + ". Please make sure the SubscriptionId you entered is correct and you have access to the cluster" ) -ForegroundColor Red
        Write-Host("")
        Stop-Transcript
        exit 1
    }
}
else {
    if ($account.Subscription.Id -eq $workspaceSubscriptionId) {
        Write-Host("Subscription: $workspaceSubscriptionId is already selected. Account details: ")
        $account
    }
    else {
        try {
            Write-Host("Current Subscription:")
            $account
            Write-Host("Changing to subscription: $workspaceSubscriptionId")
            Set-AzContext -SubscriptionId $workspaceSubscriptionId
        }
        catch {
            Write-Host("")
            Write-Host("Could not select subscription with ID : " + $workspaceSubscriptionId + ". Please make sure the ID you entered is correct and you have access to the cluster" ) -ForegroundColor Red
            Write-Host("")
            Stop-Transcript
            exit 1
        }
    }
}

# validate configured log analytics workspace exists and got access permissions
Write-Host("Checking specified Azure Log Analytics Workspace exists and got access...")
$workspaceResource = Get-AzResource -ResourceId $azureLogAnalyticsWorkspaceResourceId -ErrorAction SilentlyContinue
if ($null -eq $workspaceResource) {
    Write-Host("specified Azure Log Analytics resource id: " + $azureLogAnalyticsWorkspaceResourceId + ". either you dont have access or doesnt exist") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

#
#    Check WS exits and access
#
try {
    Write-Host("Checking workspace name's details...")
    $WorkspaceInformation = Get-AzOperationalInsightsWorkspace -ResourceGroupName $workspaceResourceGroupName -Name $workspaceName -ErrorAction Stop
    Write-Host("Successfully fetched workspace name...") -ForegroundColor Green
    Write-Host("")
}
catch {
    Write-Host("")
    Write-Host("Could not fetch details for the workspace : '" + $workspaceName + "'. Please make sure that it hasn't been deleted and you have access to it.") -ForegroundColor Red
    Write-Host("Please try to opt out of monitoring and opt-in using the following links:") -ForegroundColor Red
    Write-Host("Opt-in - " + $OptInLink) -ForegroundColor Red
    Write-Host("")
    Stop-Transcript
    exit 1
}

$WorkspaceLocation = $WorkspaceInformation.Location
if ($null -eq $WorkspaceLocation) {
    Write-Host("")
    Write-Host("Cannot fetch workspace location. Please try again...") -ForegroundColor Red
    Write-Host("")
    Stop-Transcript
    exit 1
}

$WorkspacePricingTier = $WorkspaceInformation.sku
Write-Host("Pricing tier of the configured LogAnalytics workspace: '" + $WorkspacePricingTier + "' ") -ForegroundColor Green

try {
    $WorkspaceIPDetails = Get-AzOperationalInsightsIntelligencePacks -ResourceGroupName $workspaceResourceGroupName -WorkspaceName $workspaceName -ErrorAction Stop -WarningAction silentlyContinue
    Write-Host("Successfully fetched workspace IP details...") -ForegroundColor Green
    Write-Host("")
}
catch {
    Write-Host("")
    Write-Host("Failed to get the list of solutions onboarded to the workspace. Please make sure that it hasn't been deleted and you have access to it.") -ForegroundColor Red
    Write-Host("")
    Stop-Transcript
    exit 1
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
    exit 1
}

$isSolutionOnboarded = $WorkspaceIPDetails.Enabled[$ContainerInsightsIndex]
if ($isSolutionOnboarded) {
    if ($WorkspacePricingTier -eq "Free") {
        Write-Host("Pricing tier of the configured LogAnalytics workspace is Free so you may need to upgrade to pricing tier to non-Free") -ForegroundColor Red
        Stop-Transcript
        exit 1
    }
}
else {
    #
    # Check contributor access to WS
    #
    $message = "Detected that this workspace- '" + $workspaceName + "' in subscription '" + $workspaceSubscriptionId + "' IS NOT ONBOARDED with container health solution.";
    Write-Host($message)

    $question = "Do you want to onboard container health to the workspace?"

    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 0)

    if ($decision -eq 0) {
        Write-Host("Deploying template to onboard container health : Please wait...")
        $DeploymentName = "ContainerInsightsSolutionOnboarding-" + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')
        $Parameters = @{ }
        $Parameters.Add("workspaceResourceId", $WorkspaceInformation.ResourceId)
        $Parameters.Add("workspaceRegion", $WorkspaceInformation.Location)
        $Parameters
        try {
            New-AzResourceGroupDeployment -Name $DeploymentName `
                -ResourceGroupName $defaultWorkspaceResourceGroup `
                -TemplateUri  https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/templates/azuremonitor-containerSolution.json `
                -TemplateParameterObject $Parameters -ErrorAction Stop`

            Write-Host("")
            Write-Host("Successfully added Container Insights Solution") -ForegroundColor Green
            Write-Host("")
        }
        catch {
            Write-Host ("Template deployment failed with an error: '" + $Error[0] + "' ") -ForegroundColor Red
            Write-Host($contactUSMessage) -ForegroundColor Red
            Stop-Transcript
            exit 1
        }
    }
    else {
        Write-Host("The container health solution isn't onboarded to your cluster. This required for the monitoring to work.") -ForegroundColor Red
        Stop-Transcript
        exit 1
    }
}

Write-Host("set KUBECONFIG environment variable for the current session.Default context in the config will be used")
$Env:KUBECONFIG = $kubeConfig
Write-Host $Env:KUBECONFIG

Write-Host("get current context in the provided kubeconfig")
$currentContext = kubectl config current-context

Write-Host("set the provided context as default context")
kubectl config use-context $clusterContextInKubeconfig

Write-Host("Check whether the ama-logs replicaset pod running correctly ...")
try {
    $rsPod = kubectl get deployments ama-logs-rs -n kube-system -o json | ConvertFrom-Json
    if ($null -eq $rsPod) {
        Write-Host( "ama-logs replicaset pod not scheduled or failed to scheduled." + $contactUSMessage) -ForegroundColor Red
        Stop-Transcript
        exit 1
    }
    $rsPodStatus = $rsPod.status
    if ((($rsPodStatus.availableReplicas -eq 1) -and
            ($rsPodStatus.readyReplicas -eq 1 ) -and
            ($rsPodStatus.replicas -eq 1 )) -eq $false
    ) {
        Write-Host( "ama-logs replicaset pod not scheduled or failed to scheduled.") -ForegroundColor Red
        Write-Host($rsPodStatus)
        Write-Host($contactUSMessage)
        Stop-Transcript
        exit 1
    }

    Write-Host( "ama-logs replicaset pod running OK.") -ForegroundColor Green
}
catch {
    Write-Host ("Failed to get ama-logs replicatset pod info using kubectl get rs  : '" + $Error[0] + "' ") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

Write-Host("Checking whether the ama-logs daemonset pod running correctly ...")
try {
    $ds = kubectl get ds -n kube-system -o json --field-selector metadata.name=ama-logs | ConvertFrom-Json
    if ($ds.Items.Length -ne 1) {
        Write-Host( "ama-logs replicaset pod not scheduled or failed to schedule." + $contactUSMessage) -ForegroundColor Red
        Stop-Transcript
        exit 1
    }

    $dsStatus = $ds.Items[0].status

    if (
        (($dsStatus.currentNumberScheduled -eq $dsStatus.desiredNumberScheduled) -and
            ($dsStatus.numberAvailable -eq $dsStatus.currentNumberScheduled) -and
            ($dsStatus.numberAvailable -eq $dsStatus.numberReady)) -eq $false) {

        Write-Host( "ama-logs daemonset pod not scheduled or failed to schedule.") -ForegroundColor Red
        Write-Host($rsPodStatus)
        Write-Host($contactUSMessage)
        Stop-Transcript
        exit 1
    }

    Write-Host( "ama-logs daemonset pod running OK.") -ForegroundColor Green
}
catch {
    Write-Host ("Failed to execute the script  : '" + $Error[0] + "' ") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

Write-Host("Retrieving WorkspaceGUID and WorkspacePrimaryKey of the workspace : " + $WorkspaceInformation.Name)
try {

    $WorkspaceSharedKeys = Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $WorkspaceInformation.ResourceGroupName -Name $WorkspaceInformation.Name -ErrorAction Stop -WarningAction SilentlyContinue
    $workspaceGUID = $WorkspaceInformation.CustomerId
    $workspacePrimarySharedKey = $WorkspaceSharedKeys.PrimarySharedKey
}
catch {
    Write-Host ("Failed to workspace details. Please validate whether you have Log Analytics Contributor role on the workspace error: '" + $Error[0] + "' ") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

Write-Host("Checking whether the WorkspaceGuid and key matching with configured log analytics workspace ...")
try {
    $amaLogsSecret = kubectl get secrets ama-logs-secret -n kube-system -o json | ConvertFrom-Json
    $workspaceGuidConfiguredOnAgent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($amaLogsSecret.data.WSID))
    $workspaceKeyConfiguredOnAgent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($amaLogsSecret.data.KEY))
    if ((($workspaceGuidConfiguredOnAgent -eq $workspaceGUID) -and ($workspaceKeyConfiguredOnAgent -eq $workspacePrimarySharedKey)) -eq $false) {
        Write-Host ("Error - Log Analytics Workspace Guid and key configured on the agent not matching with details of the Workspace. Please verify and fix with the correct workspace Guid and Key") -ForegroundColor Red
        Stop-Transcript
        exit 1
    }

    Write-Host("Workspace Guid and Key on the agent matching with the Workspace") -ForegroundColor Green
}
catch {
    Write-Host ("Failed to execute the script  : '" + $Error[0] + "' ") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

Write-Host("Checking agent version...")
try {
    Write-Host("kubeConfig: " + $kubeConfig)

    $amaLogsInfo = kubectl get pods -n kube-system -o json -l  rsName=ama-logs-rs | ConvertFrom-Json
    $amaLogsImage = $amaLogsInfo.items.spec.containers.image.split(":")[1]

    Write-Host('The version of the ama-logs running on your cluster is ' + $amaLogsImage)
    Write-Host('You can encounter problems with your cluster if your ama-logs isnt on the latest version. Please go to https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-manage-agent and validate that you have the latest ama-logs version running.') -ForegroundColor Yellow
}
catch {
    Write-Host ("Failed to execute the script  : '" + $Error[0] + "' ") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

Write-Host("resetting cluster context back, what it was before")
kubectl config use-context $currentContext

Write-Host("Performance charts (CPU or Memory) blank indicates that cAdvisor on the Kubelet not configured either on secure port: 10250 or unsecure port:10255") -ForegroundColor Yellow
Write-Host("Please refer the cluster creation tool how to configure cAdvisor on the Kubelet to secure port:10250 or unsecure port: 10255") -ForegroundColor Yellow
Write-Host("On all the nodes cAdvisor on the Kubelet MUST be configured either secure port:10250 or unsecure port:10255 to get the perfomance metrics") -ForegroundColor Yellow

Write-Host("If you still have problem getting Azure Monitor for containers working for your K8s cluster. Please reach out us on askcoin@microsoft.com") -ForegroundColor Yellow

Write-Host("")
Stop-Transcript