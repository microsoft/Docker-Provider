#
# ClassifyError.ps1
#
<#
    .DESCRIPTION
		Classifies the error type that a user is facing with their AKS or ARO cluster related to Azure Monitor for containers onboarding

    .PARAMETER ClusterResourceId
        Resource Id of the AKS (Azure Kubernetes Service) or ARO (Azure Redhat Openshift)
        Example :
        AKS cluster ResourceId should be in this format : /subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.ContainerService/managedClusters/<clusterName>
        ARO Cluster ResourceId should be in this format : /subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.ContainerService/openShiftManagedClusters/<clusterName>
#>

param(
    [Parameter(mandatory = $true)]
    [string]$ClusterResourceId
)

$ErrorActionPreference = "Stop"
Start-Transcript -path .\TroubleshootDump.txt -Force
$AksOptOutLink = "https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-optout"
$AksOptInLink = "https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-onboard"
$AroOptOutLink = "https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-optout-openshift"
$AroOptInLink = "https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-azure-redhat-setup"
$contactUSMessage = "Please contact us by emailing askcoin@microsoft.com if you need any help"

$MonitoringMetricsRoleDefinitionName = "Monitoring Metrics Publisher"

Write-Host("ClusterResourceId: '" + $ClusterResourceId + "' ")

if (($null -eq $ClusterResourceId) -or ($ClusterResourceId.Split("/").Length -ne 9) -or (($ClusterResourceId.ToLower().Contains("microsoft.containerservice/managedclusters") -ne $true) -and ($ClusterResourceId.ToLower().Contains("microsoft.containerservice/openshiftmanagedclusters") -ne $true))
) {
    Write-Host("Provided Cluster resource id should be fully qualified resource id of AKS or ARO cluster") -ForegroundColor Red
    Write-Host("Resource Id Format for AKS cluster is : /subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.ContainerService/managedClusters/<clusterName>") -ForegroundColor Red
    Write-Host("Resource Id Format for ARO cluster is : /subscriptions/<subId>/resourceGroups/<rgName>/providers/Microsoft.ContainerService/openShiftManagedClusters/<clusterName>") -ForegroundColor Red
    Stop-Transcript
    exit 1
}

$UseAADAuth = $false
$ClusterRegion = ""
$isClusterAndWorkspaceInDifferentSubs = $false
$ClusterType = "AKS"
if ($ClusterResourceId.ToLower().Contains("microsoft.containerservice/openshiftmanagedclusters") -eq $true) {
    $ClusterType = "ARO";
}

# checks the all required Powershell modules exist and if not exists, request the user permission to install
$azAccountModule = Get-Module -ListAvailable -Name Az.Accounts
$azResourcesModule = Get-Module -ListAvailable -Name Az.Resources
$azOperationalInsights = Get-Module -ListAvailable -Name Az.OperationalInsights
$azAksModule = Get-Module -ListAvailable -Name Az.Aks
$azARGModule = Get-Module -ListAvailable -Name Az.ResourceGraph
$azMonitorModule = Get-Module -ListAvailable -Name Az.Monitor

if (($null -eq $azAksModule) -or ($null -eq $azARGModule) -or ($null -eq $azAccountModule) -or ($null -eq $azResourcesModule) -or ($null -eq $azOperationalInsights) -or ($null -eq $azMonitorModule)) {

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
    Az.Ak,Az.ResourceGraph, Az.Resources, Az.Accounts, Az.OperationalInsights  and Az.Monitor using the command`
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
            if ($null -eq $azARGModule) {
                try {
                    Write-Host("Installing Az.ResourceGraph...")
                    Install-Module Az.ResourceGraph -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules for Az.ResourceGraph in a new powershell window: eg. 'Install-Module Az.ResourceGraph -Force'") -ForegroundColor Red
                    Stop-Transcript
                    exit 1
                }
            }
            if ($null -eq $azAksModule) {
                try {
                    Write-Host("Installing Az.Aks...")
                    Install-Module Az.Aks -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules for Az.Aks in a new powershell window: eg. 'Install-Module Az.Aks -Force'") -ForegroundColor Red
                    Stop-Transcript
                    exit 1
                }
            }

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

            if ($null -eq $azMonitorModule) {
                try {

                    Write-Host("Installing Az.Monitor...")
                    Install-Module Az.Monitor -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules for Az.OperationalInsights in a new powershell window: eg. 'Install-Module Az.Monitor -Repository PSGallery -Force'") -ForegroundColor Red
                    Stop-Transcript
                    exit 1
                }
            }
        }
        1 {
            if ($null -eq $azARGModule) {
                try {
                    Import-Module Az.ResourceGraph -ErrorAction Stop
                }
                catch {
                    Write-Host("Could not Import Az.ResourceGraph...") -ForegroundColor Red
                    Write-Host("Close other powershell logins and try installing the latest modules for Az.ResourceGraph in a new powershell window: eg. 'Install-Module Az.ResourceGraph -Force'") -ForegroundColor Red
                    Stop-Transcript
                    exit 1
                }
            }

            if ($null -eq $azAksModule) {
                try {
                    Import-Module Az.Aks -ErrorAction Stop
                }
                catch {
                    Write-Host("Could not Import Az.Aks...") -ForegroundColor Red
                    Write-Host("Close other powershell logins and try installing the latest modules for Az.Aks in a new powershell window: eg. 'Install-Module Az.Aks -Force'") -ForegroundColor Red
                    Stop-Transcript
                    exit 1
                }
            }

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

           if ($null -eq $azMonitorModule) {
                try {
                    Import-Module Az.Monitor -ErrorAction Stop
                }
                catch {
                    Write-Host("Could not import Az.Monitor... Please reinstall this Module") -ForegroundColor Red
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

$MdmCustomMetricAvailabilityLocations = (
    'eastus',
    'southcentralus',
    'westcentralus',
    'westus2',
    'southeastasia',
    'northeurope',
    'westeurope',
    'southafricanorth',
    'centralus',
    'northcentralus',
    'eastus2',
    'koreacentral',
    'eastasia',
    'centralindia',
    'uksouth',
    'canadacentral',
    'francecentral',
    'japaneast',
    'australiaeast',
    'eastus2',
    'westus',
    'australiasoutheast',
    'brazilsouth',
    'germanywestcentral',
    'northcentralus',
    'switzerlandnorth'
);

try {
    Write-Host("")
    Write-Host("Trying to get the current Az login context...")
    $account = Get-AzContext -ErrorAction Stop
    Write-Host("Successfully fetched current Az context...") -ForegroundColor Green
    Write-Host("")
}
catch {
    Write-Host("")
    Write-Host("Could not fetch AzContext..." ) -ForegroundColor Red
    Write-Host("")
}

$ClusterSubscriptionId = $ClusterResourceId.split("/")[2]
$ResourceGroupName = $ClusterResourceId.split("/")[4]
$ClusterName = $ClusterResourceId.split("/")[8]

#
#   Subscription existence and access check
#
if ($null -eq $account.Account) {
    try {
        Write-Host("Please login...")
        if ($isWindowsMachine) {
          Login-AzAccount -subscriptionid $ClusterSubscriptionId
        } else {
            Login-AzAccount -subscriptionid $ClusterSubscriptionId -UseDeviceAuthentication
        }
    }
    catch {
        Write-Host("")
        Write-Host("Could not select subscription with ID : " + $ClusterSubscriptionId + ". Please make sure the SubscriptionId you entered is correct and you have access to the Subscription" ) -ForegroundColor Red
        Write-Host("")
        Stop-Transcript
        exit 1
    }
}
else {
    if ($account.Subscription.Id -eq $ClusterSubscriptionId) {
        Write-Host("Subscription: $ClusterSubscriptionId is already selected. Account details: ")
        $account
    }
    else {
        try {
            Write-Host("Current Subscription:")
            $account
            Write-Host("Changing to subscription: $ClusterSubscriptionId")
            Select-AzSubscription -SubscriptionId $ClusterSubscriptionId
        }
        catch {
            Write-Host("")
            Write-Host("Could not select subscription with ID : " + $ClusterSubscriptionId + ". Please make sure the SubscriptionId you entered is correct and you have access to the Subscription" ) -ForegroundColor Red
            Write-Host("")
            Stop-Transcript
            exit 1
        }
    }
}


#
#   Resource group existance and access check
#
Write-Host("Checking resource group details...")
Get-AzResourceGroup -Name $ResourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent) {
    Write-Host("")
    Write-Host("Could not find RG. Please make sure that the resource group name: '" + $ResourceGroupName + "'is correct and you have access to the Resource Group") -ForegroundColor Red
    Write-Host("")
    Stop-Transcript
    exit 1
}
Write-Host("Successfully checked resource groups details...") -ForegroundColor Green

Write-Host("Checking '" + $ClusterType + "' Cluster details...")
$ResourceDetailsArray = $null
try {
    if ("AKS" -eq $ClusterType) {
        $ResourceDetailsArray = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $ClusterName -ResourceType "Microsoft.ContainerService/managedClusters" -ExpandProperties -ErrorAction Stop -WarningAction Stop
        if ($null -eq $ResourceDetailsArray) {
            Write-Host("")
            Write-Host("Could not fetch cluster details: Please make sure that the '" + $ClusterType + "' Cluster name: '" + $ClusterName + "' is correct and you have access to the cluster") -ForegroundColor Red
            Write-Host("")
            Stop-Transcript
            exit 1
        }
        else {
            Write-Host("Successfully checked '" + $ClusterType + "' Cluster details...") -ForegroundColor Green
            $ClusterRegion = $ResourceDetailsArray.Location
            Write-Host("")
            foreach ($ResourceDetail in $ResourceDetailsArray) {
                if ($ResourceDetail.ResourceType -eq "Microsoft.ContainerService/managedClusters") {
                    $addonProfiles = ($ResourceDetail.Properties.addonProfiles | ConvertTo-Json).toLower() | ConvertFrom-Json

                    if (($nul -eq $addonProfiles)  -or  ($null -eq $addonProfiles.omsagent) -or ($null -eq $addonProfiles.omsagent.config)) {
                        Write-Host("Your cluster isn't onboarded to Azure monitor for containers. Please refer to the following documentation to onboard:") -ForegroundColor Red;
                        $clusterProperies = ($ResourceDetail.Properties  | ConvertTo-Json)
                        Write-Host("Cluster Properties found: " + $clusterProperies) -ForegroundColor Red;
                        Write-Host($AksOptInLink) -ForegroundColor Red;
                        Write-Host("");
                        Stop-Transcript
                        exit 1
                    }

                    $LogAnalyticsWorkspaceResourceID = $addonProfiles.omsagent.config.loganalyticsworkspaceresourceid
                    $isAADAuth = $addonProfiles.omsagent.config.useaadauth
                    if ($true -eq $isAADAuth) {
                       $UseAADAuth = $true
                    }

                    Write-Host("AKS Cluster ResourceId: '" + $ResourceDetail.ResourceId + "', LogAnalyticsWorkspaceResourceId: '" + $LogAnalyticsWorkspaceResourceID + "', UseAADAuth: '" + $UseAADAuth + "'");
                    break
                }
            }
        }
    }
    else {
        $argQuery = "where resourceGroup =~ '" + $ResourceGroupName + "' and name=~ '" + $ClusterName + "' and type =~ 'Microsoft.ContainerService/openshiftmanagedclusters'  | project id, name, aroproperties = parse_json(tolower(properties)), location"
        $ResourceDetail = Search-AzGraph -Subscription $ClusterSubscriptionId -Query $argQuery
        if ($null -eq $ResourceDetail) {
            Write-Host("")
            Write-Host("Could not fetch cluster details: Please make sure that the '" + $ClusterType + "' Cluster name: '" + $ClusterName + "' is correct and you have access to the cluster") -ForegroundColor Red
            Write-Host("")
            Stop-Transcript
            exit 1
        }

        $monitorProfile = $ResourceDetail.aroproperties.monitorprofile
        if (($null -eq $monitorProfile) -or ($monitorProfile.enabled -eq $false)) {
            Write-Host("Your cluster isn't onboarded to Azure monitor for containers. Please refer to the following documentation to onboard:") -ForegroundColor Red;
            Write-Host($AksOptInLink) -ForegroundColor Red;
            Write-Host("");
            Stop-Transcript
            exit 1
        }

        $LogAnalyticsWorkspaceResourceID = $monitorProfile.workspaceresourceid
        Write-Host("ARO Cluster ResourceId: '" + $ResourceDetail.id + "' ")
    }
}
catch {
    Write-Host("")
    Write-Host("Could not fetch cluster details: Please make sure that the '" + $ClusterType + "' Cluster name: '" + $ClusterName + "' is correct and you have access to the cluster") -ForegroundColor Red
    Write-Host("")
    Stop-Transcript
    exit 1
}


if (("AKS" -eq $ClusterType ) -and ($false -eq $UseAADAuth)) {
    Write-Host("Currently checking if the cluster is onboarded to custom metrics for Azure monitor for containers...");
    #Pre requisite - need cluster spn object Id
    try {
        $clusterDetails = Get-AzAksCluster -Id $ClusterResourceId -ErrorVariable clusterFetchError -ErrorAction SilentlyContinue
        Write-Host($clusterDetails | Format-List | Out-String)

        # Check to see if SP exists, if it does use it. Else use MSI
        if ($clusterDetails.ServicePrincipalProfile -ne $null -and $clusterDetails.ServicePrincipalProfile.ClientId -ne $null -and $clusterDetails.ServicePrincipalProfile.ClientId -ne "msi") {
            Write-Host('Attempting to provide permissions to service principal...') -ForegroundColor Green
            $clusterSpnClientID = $clusterDetails.ServicePrincipalProfile.ClientId
            $isServicePrincipal = $true
        }
        elseif ($ResourceDetailsArray -ne $null -and $ResourceDetailsArray[0].properties.addonprofiles.omsagent -ne $null -and $ResourceDetailsArray[0].properties.addonprofiles.omsagent.identity -ne $null) {
            Write-Host('Attempting to provide permissions to MSI...') -ForegroundColor Green
            if ($ResourceDetailsArray[0].properties.addonprofiles.omsagent.identity.objectid -ne "")
            {
                $clusterSpnMsiObjectID = $ResourceDetailsArray[0].properties.addonprofiles.omsagent.identity.objectid
                $isServicePrincipal = $false
            }
        }

        $clusterLocation = $clusterDetails.Location

        if ($MdmCustomMetricAvailabilityLocations -contains $clusterLocation) {
            Write-Host('Cluster is in a location where Custom metrics are available') -ForegroundColor Green
            if ($null -eq $clusterSpnMsiObjectID -and $clusterSpnClientID -eq $null) {
                Write-Host("There is no service principal or msi associated with this cluster.") -ForegroundColor Red
                Write-Host("");
            }
            else {
                # Convert the client ID to the Object ID if SP is present
                if ($isServicePrincipal -eq $true) {
                    $clusterSPN = Get-AzADServicePrincipal -ServicePrincipalName $clusterSpnClientID
                    $clusterSpnMsiObjectID = $clusterSPN.Id
                }
                if ($null -eq $clusterSpnMsiObjectID) {
                    Write-Host("Couldn't convert Client ID to Object ID or msi for ama-logs is not present") -ForegroundColor Red
                    Write-Host("Please contact us by emailing askcoin@microsoft.com for help") -ForegroundColor Red
                    Write-Host("");
                }

                $MonitoringMetricsPublisherCandidates = Get-AzRoleAssignment -RoleDefinitionName $MonitoringMetricsRoleDefinitionName -Scope $ClusterResourceId -ErrorVariable notPresent -ErrorAction SilentlyContinue

                if ($notPresent) {
                    Write-Host("Error in fetching monitoring metrics publisher candidates for " + $ClusterName) -ForegroundColor Red
                    Write-Host($notPresent)
                    Write-Host("")
                }
                else {
                    $TryToOnboardToCustomMetrics = $false
                    if ($MonitoringMetricsPublisherCandidates) {
                        Write-Host($MonitoringMetricsPublisherCandidates | Format-List | Out-String)

                        $metricsPublisherRoleAlreadyExists = $false

                        if ($MonitoringMetricsPublisherCandidates.ObjectId -eq $clusterSpnMsiObjectID) {
                            $metricsPublisherRoleAlreadyExists = $true
                        }
                        if ($metricsPublisherRoleAlreadyExists) {
                            Write-Host("Cluster SPN/ ama-logs MSI has the Monitoring Metrics Publisher Role assigned already") -ForegroundColor Green
                        }
                        else {
                            $TryToOnboardToCustomMetrics = $true
                        }
                    }
                    else {
                        Write-Host("No monitoring metrics publisher candidates present, We need to onboard the cluster service prinicipal/msi with the Monitoring Metrics Publisher role")
                        $TryToOnboardToCustomMetrics = $true
                    }
                    if ($TryToOnboardToCustomMetrics) {
                        $message = "Detected that custom metrics is not enabled for this cluster. You need to be an owner on the cluster resource to do the following operation operation."
                        $question = "Do you want this script to enable it by adding the role 'Monitoring Metrics Publisher' to your clusters SPN/MSI?"

                        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
                        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
                        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

                        $decision = $Host.UI.PromptForChoice($message, $question, $choices, 0)

                        if ($decision -eq 0) {
                            New-AzRoleAssignment -ObjectId $clusterSpnMsiObjectID -Scope $ClusterResourceId -RoleDefinitionName $MonitoringMetricsRoleDefinitionName -ErrorAction SilentlyContinue -ErrorVariable assignmentFailed;
                            if ($assignmentFailed) {
                                Write-Host("Couldn't assign the new role. You need the cluster owner role to do this action. Please contact your cluster administrator to onboard.") -ForegroundColor Red;
                                Write-Host("You can find more information on this here: https://aka.ms/ci-enable-mdm") -ForegroundColor Red;
                                Write-Host("");
                            }
                            else {
                                Write-Host("Successfully onboarded to Azure monitor for containers custom metrics.") -ForegroundColor Green
                                Write-Host("");
                            }
                        }
                    }
                }
            }
        }
        else {
            Write-Host('Cluster is in a location where Custom metrics are not available') -ForegroundColor Red;
            Write-Host("")
        }
    }
    catch {
        Write-Host("Error in fetching Cluster details for " + $ClusterName) -ForegroundColor Red
        Write-Host("Please check that you have access to the cluster: " + $ClusterName) -ForegroundColor Red;
        Write-Host("")
    }
}

if ($null -eq $LogAnalyticsWorkspaceResourceID) {
    Write-Host("")
    Write-Host("Onboarded  log analytics workspace to this cluster either deleted or moved.This requires Opt-out and Opt-in back to Monitoring") -ForegroundColor Red
    Write-Host("Please try to opt out of monitoring and opt-in following the instructions in below links:") -ForegroundColor Red
    if ("ARO" -eq $ClusterType) {
        Write-Host("Opt-out - " + $AroOptOutLink) -ForegroundColor Red
        Write-Host("Opt-in - " + $AroOptInLink) -ForegroundColor Red
    }
    else {
        Write-Host("Opt-out - " + $AksOptOutLink) -ForegroundColor Red
        Write-Host("Opt-in - " + $AksOptInLink) -ForegroundColor Red
    }
    Write-Host("")
    Stop-Transcript
    exit 1
}
else {

    Write-Host("Configured LogAnalyticsWorkspaceResourceId: : '" + $LogAnalyticsWorkspaceResourceID + "' ")
    $workspaceSubscriptionId = $LogAnalyticsWorkspaceResourceID.split("/")[2]
    $workspaceResourceGroupName = $LogAnalyticsWorkspaceResourceID.split("/")[4]
    $workspaceName = $LogAnalyticsWorkspaceResourceID.split("/")[8]

    try {
         $isClusterAndWorkspaceInDifferentSubs = $ClusterSubscriptionId -ne $workspaceSubscriptionId
        if ($isClusterAndWorkspaceInDifferentSubs) {
            Write-Host("Changing to workspace's subscription since cluster and workspace are in different subscriptions")
            Select-AzSubscription -SubscriptionId $workspaceSubscriptionId
        }
    }
    catch {
        Write-Host("")
        Write-Host("Could not change to Workspace subscriptionId : '" + $workspaceSubscriptionId + "'." ) -ForegroundColor Red
        Write-Host("")
        Stop-Transcript
        exit 1
    }


    #
    #   Check WS subscription exists and access
    #
    try {
        Write-Host("Checking workspace subscription details...")
        Get-AzSubscription -SubscriptionId $workspaceSubscriptionId -ErrorAction Stop
    }
    catch {
        Write-Host("")
        Write-Host("The subscription containing the workspace (" + $LogAnalyticsWorkspaceResourceID + ") looks like it was deleted or you do NOT have access to this workspace") -ForegroundColor Red
        Write-Host("Please try to opt out of monitoring and opt-in using the following links:") -ForegroundColor Red
        if ("ARO" -eq $ClusterType) {
            Write-Host("Opt-out - " + $AroOptOutLink) -ForegroundColor Red
            Write-Host("Opt-in - " + $AroOptInLink) -ForegroundColor Red
        }
        else {
            Write-Host("Opt-out - " + $AksOptOutLink) -ForegroundColor Red
            Write-Host("Opt-in - " + $AksOptInLink) -ForegroundColor Red
        }
        Write-Host("")
        Stop-Transcript
        exit 1
    }
    Write-Host("Successfully fetched workspace subcription details...") -ForegroundColor Green
    Write-Host("")

    #
    #   Check WS Resourecegroup exists and access
    #
    Write-Host("Checking workspace's resource group details...")
    Get-AzResourceGroup -Name $workspaceResourceGroupName -ErrorVariable notPresent -ErrorAction SilentlyContinue
    if ($notPresent) {
        Write-Host("")
        Write-Host("Could not find resource group. Please make sure that the resource group name: '" + $ResourceGroupName + "'is correct and you have access to the workspace") -ForegroundColor Red
        Write-Host("Please try to opt out of monitoring and opt-in using the following links:") -ForegroundColor Red

        if ("ARO" -eq $ClusterType) {
            Write-Host("Opt-out - " + $AroOptOutLink) -ForegroundColor Red
            Write-Host("Opt-in - " + $AroOptInLink) -ForegroundColor Red
        }
        else {
            Write-Host("Opt-out - " + $AksOptOutLink) -ForegroundColor Red
            Write-Host("Opt-in - " + $AksOptInLink) -ForegroundColor Red
        }
        Stop-Transcript
        exit 1
    }
    Write-Host("Successfully fetched workspace resource group...") -ForegroundColor Green
    Write-Host("")

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

        if ("ARO" -eq $ClusterType) {
            Write-Host("Opt-out - " + $AroOptOutLink) -ForegroundColor Red
            Write-Host("Opt-in - " + $AroOptInLink) -ForegroundColor Red
        }
        else {
            Write-Host("Opt-out - " + $AksOptOutLink) -ForegroundColor Red
            Write-Host("Opt-in - " + $AksOptInLink) -ForegroundColor Red
        }
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

    if ($true -eq $UseAADAuth) {
        #
        # Check existence of the ContainerInsightsExtension DCR
        #
        try {
            $dcrRuleName = "MSCI-" + $ClusterName + "-" + $ClusterRegion
            $dcrRule = Get-AzDataCollectionRule -ResourceGroupName $workspaceResourceGroupName -RuleName $dcrRuleName -ErrorAction Stop -WarningAction silentlyContinue
            Write-Host("Successfully fetched Data Collection Rule...") -ForegroundColor Green
            $extensionNameInDCR =  $dcrRule.DataSources.Extensions.ExtensionName
            if ($extensionNameInDCR -eq "ContainerInsights") {
                $laDestinations = $dcrRule.Destinations.LogAnalytics
                if (($null -ne $laDestinations) -and ($laDestinations.Length -gt 0) -and ($LogAnalyticsWorkspaceResourceID -eq $laDestinations[0].WorkspaceResourceId)) {
                    Write-Host("Successfully validated Data Collection Rule is valid...") -ForegroundColor Green
                } else {
                    Write-Host("")
                    Write-Host("Data Collection Rule: '" + $dcrRuleName + "' found has Log Analytics(LA) workspace which different from the Log Analytics  workspace  in Monitoring addon.") -ForegroundColor Red
                    $laWorkspaceResIdInDCR = $laDestinations[0].WorkspaceResourceId
                    Write-Host("LA workspace found in Data Collection Rule: '" + $laWorkspaceResIdInDCR + "' but where as LA workspace in Monitoring Addon: '" + $LogAnalyticsWorkspaceResourceID + "'.") -ForegroundColor Red
                    Write-Host("")
                    Stop-Transcript
                    exit 1
                }

            } else {
                Write-Host("")
                Write-Host("Data Collection Rule: '" + $dcrRuleName + "' found is not valid ContainerInsights extension DCR.") -ForegroundColor Red
                Write-Host("")
                Stop-Transcript
                exit 1
            }
        }
        catch {
            Write-Host("")
            Write-Host("Failed to get the data collection Rule: '" + $dcrRuleName + "'. Please make sure that it hasn't been deleted and you have access to it.") -ForegroundColor Red
            Write-Host("If  DataCollectionRule :'" + $dcrRuleName + "' has been deleted accidentally, disable and enable Monitoring addon back to get this fixed.") -ForegroundColor Red
            Write-Host("")
            Stop-Transcript
            exit 1
        }

        #
        # Check existence of the ContainerInsightsExtension DCR-A on the cluster resource
        #
        try {
            $dcrAssociation = Get-AzDataCollectionRuleAssociation -TargetResourceId $ClusterResourceId -AssociationName "ContainerInsightsExtension" -ErrorAction Stop -WarningAction silentlyContinue
            Write-Host("Successfully fetched ContainerInsightsExtension Data Collection Rule Association ...") -ForegroundColor Green
            if ($null -eq $dcrAssociation) {
                Write-Host("")
                Write-Host("ContainerInsightsExtension Data Collection Rule Association doenst exist.") -ForegroundColor Red
                Write-Host("")
                Stop-Transcript
                exit 1
            }
        }
        catch {
            Write-Host("")
            Write-Host("Failed to get the data collection Rule Association. Please make sure that it hasn't been deleted and you have access to it.") -ForegroundColor Red
            Write-Host("If ContainerInsightsExtension DataCollectionRule Association has been deleted accidentally, disable and enable Monitoring addon back to get this fixed.") -ForegroundColor Red
            Write-Host("")
            Stop-Transcript
            exit 1
        }
    }
    else {

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
            $ContainerInsightsIndex = $WorkspaceIPDetails.Name.IndexOf("ContainerInsights")
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
                Write-Host("Pricing tier of the configured LogAnalytics workspace is Free so you may need to upgrade to pricing tier to non-Free") -ForegroundColor Yellow
            }
        }
        else {
            #
            # Check contributor access to WS
            #
            $message = "Detected that there is a workspace associated with this cluster, but workspace - '" + $workspaceName + "' in subscription '" + $workspaceSubscriptionId + "' IS NOT ONBOARDED with container health solution."
            Write-Host($message)
            $question = " Do you want to onboard container health to the workspace?"

            $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
            $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
            $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

            $decision = $Host.UI.PromptForChoice($message, $question, $choices, 0)

            if ($decision -eq 0) {
                Write-Host("Deploying template to onboard container health : Please wait...")

                $DeploymentName = "ContainerInsightsSolutionOnboarding-" + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')
                $Parameters = @{ }
                $Parameters.Add("workspaceResourceId", $LogAnalyticsWorkspaceResourceID)
                $Parameters.Add("workspaceRegion", $WorkspaceLocation)
                $Parameters
                try {
                    New-AzResourceGroupDeployment -Name $DeploymentName `
                        -ResourceGroupName $workspaceResourceGroupName `
                        -TemplateUri  https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/templates/azuremonitor-containerSolution.json `
                        -TemplateParameterObject $Parameters -ErrorAction Stop`

                    Write-Host("")
                    Write-Host("Successfully added Container Insights Solution") -ForegroundColor Green

                    Write-Host("")
                }
                catch {
                    Write-Host ("Template deployment failed with an error: '" + $Error[0] + "' ") -ForegroundColor Red
                    Write-Host("Please contact us by emailing askcoin@microsoft.com for help") -ForegroundColor Red
                }
            }
            else {
                Write-Host("The container health solution isn't onboarded to your cluster. This required for the monitoring to work. Please contact us by emailing askcoin@microsoft.com if you need any help on this") -ForegroundColor Red
            }
        }
    }
}

#
#    Check Workspace Usage
#
try {
    Write-Host("Checking workspace configured for capping on data ingestion limits...")
    $WorkspaceUsage = Get-AzOperationalInsightsWorkspaceUsage -ResourceGroupName $workspaceResourceGroupName -Name $workspaceName -ErrorAction Stop
    if ($WorkspaceUsage.Limit -gt -1) {
        Write-Host("Workspace has daily cap of bytes: ", $WorkspaceUsage.Limit) -ForegroundColor Green
        if ($WorkspaceUsage.CurrentValue -ge $WorkspaceUsage.Limit) {
            Write-Host("Workspace usage has reached or over the configured daily cap. Please increase the daily cap limits or wait for next reset interval") -ForegroundColor Red
            Stop-Transcript
            exit 1
        }
    }
    Write-Host("Workspace doesnt have daily cap configured") -ForegroundColor Green
}
catch {
    Write-Host("Failed to get  usage details of the workspace") -ForegroundColor Red
    Write-Host("")
    Stop-Transcript
    exit 1
}


if ("AKS" -eq $ClusterType ) {
    #
    #    Check Agent pods running as expected
    #
    try {

        if ($isClusterAndWorkspaceInDifferentSubs) {
          Write-Host("Changing to cluster's subscription back")
          Select-AzSubscription -SubscriptionId $ClusterSubscriptionId
        }

        Write-Host("Getting Kubeconfig of the cluster...")
        Import-AzAksCredential -Id $ClusterResourceId -Force -ErrorAction Stop
        Write-Host("Successfully got the Kubeconfig of the cluster.")

        Write-Host("Switch to cluster context to:", $ClusterName )
        kubectl config use-context $ClusterName
        Write-Host("Successfully switched current context of the k8s cluster to:", $ClusterName)

        Write-Host("Check whether the ama-logs replicaset pod running correctly ...")
        $rsPod = kubectl get deployments ama-logs-rs -n kube-system -o json | ConvertFrom-Json
        if ($null -eq $rsPod) {
            Write-Host( "ama-logs replicaset pod not scheduled or failed to scheduled.") -ForegroundColor Red
            Write-Host("Please refer to the following documentation to onboard and validate:") -ForegroundColor Red
            Write-Host($AksOptInLink) -ForegroundColor Red
            Write-Host($contactUSMessage)
            Stop-Transcript
            exit 1
        }

        $rsPodStatus = $rsPod.status
        if ((($rsPodStatus.availableReplicas -eq 1) -and
                ($rsPodStatus.readyReplicas -eq 1 ) -and
                ($rsPodStatus.replicas -eq 1 )) -eq $false
        ) {
            Write-Host( "ama-logs replicaset pod not scheduled or failed to scheduled.") -ForegroundColor Red
            Write-Host("Available ama-logs replicas:", $rsPodStatus.availableReplicas)
            Write-Host("Ready ama-logs replicas:", $rsPodStatus.readyReplicas)
            Write-Host("Total ama-logs replicas:", $rsPodStatus.replicas)
            Write-Host($rsPod) -ForegroundColor Red
            Write-Host("get ama-logs rs pod details ...")
            $amaLogsRsPod = kubectl get pods -n kube-system -l rsName=ama-logs-rs -o json | ConvertFrom-Json
            Write-Host("status of the ama-logs rs pod is :", $amaLogsRsPod.Items[0].status.conditions) -ForegroundColor Red
            Write-Host("successfully got ama-logs rs pod details ...")
            Write-Host("Please refer to the following documentation to onboard and validate:") -ForegroundColor Red
            Write-Host($AksOptInLink) -ForegroundColor Red
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
        if (($null -eq $ds) -or ($null -eq $ds.Items) -or ($ds.Items.Length -ne 1)) {
            Write-Host( "ama-logs replicaset pod not scheduled or failed to schedule." + $contactUSMessage)
            Stop-Transcript
            exit 1
        }

        $dsStatus = $ds.Items[0].status

        if (
            (($dsStatus.currentNumberScheduled -eq $dsStatus.desiredNumberScheduled) -and
                ($dsStatus.numberAvailable -eq $dsStatus.currentNumberScheduled) -and
                ($dsStatus.numberAvailable -eq $dsStatus.numberReady)) -eq $false) {

            Write-Host( "ama-logs daemonset pod not scheduled or failed to schedule.") -ForegroundColor Red
            Write-Host($dsStatus)
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

    if ($isClusterAndWorkspaceInDifferentSubs) {
       Write-Host("Changing to workspace's subscription")
       Select-AzSubscription -SubscriptionId $workspaceSubscriptionId
    }
    Write-Host("Retrieving WorkspaceGUID and WorkspacePrimaryKey of the workspace : " + $WorkspaceInformation.Name)
    try {

        $WorkspaceSharedKeys = Get-AzOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $WorkspaceInformation.ResourceGroupName -Name $WorkspaceInformation.Name -ErrorAction Stop -WarningAction SilentlyContinue
        $workspaceGUID = $WorkspaceInformation.CustomerId
        $workspacePrimarySharedKey = $WorkspaceSharedKeys.PrimarySharedKey
    }
    catch {
        Write-Host ("Failed to get workspace details. Please validate whether you have Log Analytics Contributor role on the workspace error: '" + $Error[0] + "' ") -ForegroundColor Red
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

        $amaLogsInfo = kubectl get pods -n kube-system -o json -l  rsName=ama-logs-rs | ConvertFrom-Json
        for ($index = 0; $index -le $amaLogsInfo.items.spec.containers.Length; $index++)
        {
            $containerName = $amaLogsInfo.items.spec.containers[$index].Name
            if ($containerName -eq "ama-logs") {
                $amaLogsImage = $amaLogsInfo.items.spec.containers[$index].image.split(":")[1]
                break
            }
        }
        Write-Host('The version of the ama-logs running on your cluster is ' + $amaLogsImage)
        Write-Host('You can encounter problems with your cluster if your ama-logs version isnt on the latest version. Please go to https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-manage-agent and validate that you have the latest ama-logs version running.') -ForegroundColor Yellow
    } catch {
        Write-Host ("Failed to execute the script  : '" + $Error[0] + "' ") -ForegroundColor Red
        Stop-Transcript
        exit 1
    }
}

Write-Host("Everything looks good according to this script. Please contact us by emailing askcoin@microsoft.com for help") -ForegroundColor Green
Write-Host("")
Stop-Transcript
