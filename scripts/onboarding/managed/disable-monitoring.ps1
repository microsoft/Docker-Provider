<#
    .DESCRIPTION

     Disables Azure Monitor for containers to monitoring enabled Azure Managed K8s cluster such as Azure Arc enabled Kubernetes, ARO v4 and AKS etc.
       1. Deletes the existing Azure Monitor for containers helm release
       2. Deletes logAnalyticsWorkspaceResourceId tag on the provided Managed cluster

    .PARAMETER clusterResourceId
        Id of the Azure Managed Cluster such as Azure Arc enabled Kubernetes, ARO v4 etc.
    .PARAMETER servicePrincipalClientId
        client Id of the service principal which will be used for the azure login
    .PARAMETER servicePrincipalClientSecret
        client secret of the service principal which will be used for the azure login
    .PARAMETER tenantId
        tenantId of the service principal which will be used for the azure login
    .PARAMETER kubeContext (optional)
        kube-context of the k8 cluster to install Azure Monitor for containers HELM chart

    Pre-requisites:
      -  Azure Managed cluster Resource Id
      -  Contributor role permission on the Subscription of the Azure Arc enabled Kubernetes Cluster
      -  Helm v3.0.0 or higher  https://github.com/helm/helm/releases
      -  kube-context of the K8s cluster
 Note: 1. Please make sure you have all the pre-requisistes before running this script.
# download script
# curl -o disable-monitoring.ps1 -L https://aka.ms/disable-monitoring-powershell-script
#>
param(
    [Parameter(mandatory = $true)]
    [string]$clusterResourceId,
    [string]$servicePrincipalClientId,
    [Parameter(mandatory = $false)]
    [string]$servicePrincipalClientSecret,
    [Parameter(mandatory = $false)]
    [string]$tenantId,
    [Parameter(mandatory = $false)]
    [string]$kubeContext
)

$helmChartReleaseName = "azmon-containers-release-1"
$helmChartName = "azuremonitor-containers"

# flags to indicate the cluster types
$isArcK8sCluster = $false
$isAksCluster =  $false
$isAroV4Cluster = $false
$isUsingServicePrincipal = $false

# checks the required Powershell modules exist and if not exists, request the user permission to install
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
            exit
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

                    Write-Host("Installing Az.OperationalInsights...")
                    Install-Module Az.OperationalInsights -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
                }
                catch {
                    Write-Host("Close other powershell logins and try installing the latest modules for Az.OperationalInsights in a new powershell window: eg. 'Install-Module Az.OperationalInsights -Repository PSGallery -Force'") -ForegroundColor Red
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

            if ($null -eq $azOperationalInsights) {
                try {
                    Import-Module Az.OperationalInsights -ErrorAction Stop
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

if ([string]::IsNullOrEmpty($clusterResourceId)) {
    Write-Host("Specified Azure ClusterResourceId should not be NULL or empty") -ForegroundColor Red
    exit
}

if ([string]::IsNullOrEmpty($kubeContext)) {
    Write-Host("Since kubeContext parameter not passed in so using current kube config context") -ForegroundColor Yellow
}

$clusterResourceId = $clusterResourceId.Trim()
if ($clusterResourceId.EndsWith("/")) {
    Write-Host("Trimming redundant / in tail end of cluster resource id")
    $clusterResourceId = $clusterResourceId.TrimEnd("/")
}

if ($clusterResourceId.StartsWith("/") -eq $false) {
    Write-Host("Prepending / to cluster resource id since this doesnt exist")
    $clusterResourceId = "/" + $clusterResourceId
}

if ($clusterResourceId.Split("/").Length -ne 9){
     Write-Host("Provided Cluster Resource Id is not in expected format") -ForegroundColor Red
    exit
}

if (($clusterResourceId.ToLower().Contains("microsoft.kubernetes/connectedclusters") -ne $true) -and
    ($clusterResourceId.ToLower().Contains("microsoft.redhatopenshift/openshiftclusters") -ne $true) -and
    ($clusterResourceId.ToLower().Contains("microsoft.containerservice/managedclusters") -ne $true)
  ) {
    Write-Host("Provided cluster ResourceId is not supported cluster type: $clusterResourceId") -ForegroundColor Red
    exit
}

if ($clusterResourceId.ToLower().Contains("microsoft.kubernetes/connectedclusters") -eq $true) {
   $isArcK8sCluster = $true
} elseif ($clusterResourceId.ToLower().Contains("microsoft.containerservice/managedclusters") -eq $true) {
   $isAksCluster =  $true
} elseif ($clusterResourceId.ToLower().Contains("microsoft.redhatopenshift/openshiftclusters") -eq $true) {
   $isAroV4Cluster = $true
}

if(([string]::IsNullOrEmpty($servicePrincipalClientId) -eq $false) -and
   ([string]::IsNullOrEmpty($servicePrincipalClientSecret) -eq $false) -and
   ([string]::IsNullOrEmpty($tenantId) -eq $false)) {
    Write-Host("Using service principal creds for the azure login since provided.")
    $isUsingServicePrincipal = $true
 }

$resourceParts = $clusterResourceId.Split("/")
$clusterSubscriptionId = $resourceParts[2]

Write-Host("Cluster SubscriptionId : '" + $clusterSubscriptionId + "' ") -ForegroundColor Green

if ($isUsingServicePrincipal) {
    $spSecret = ConvertTo-SecureString -String $servicePrincipalClientSecret -AsPlainText -Force
    $spCreds = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $servicePrincipalClientId,$spSecret
    Connect-AzAccount -ServicePrincipal -Credential $spCreds -Tenant $tenantId -Subscription $clusterSubscriptionId
}

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

        if ($isUsingServicePrincipal) {
            $spSecret = ConvertTo-SecureString -String $servicePrincipalClientSecret -AsPlainText -Force
            $spCreds = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $servicePrincipalClientId,$spSecret
            Connect-AzAccount -ServicePrincipal -Credential $spCreds -Tenant $tenantId -Subscription $clusterSubscriptionId
        } else {
           Write-Host("Please login...")
          Connect-AzAccount -subscriptionid $clusterSubscriptionId
        }
    }
    catch {
        Write-Host("")
        Write-Host("Could not select subscription with ID : " + $clusterSubscriptionId + ". Please make sure the ID you entered is correct and you have access to the cluster" ) -ForegroundColor Red
        Write-Host("")
        Stop-Transcript
        exit
    }
}
else {
    if ($account.Subscription.Id -eq $clusterSubscriptionId) {
        Write-Host("Subscription: $SubscriptionId is already selected. Account details: ")
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
            Write-Host("Could not select subscription with ID : " + $clusterSubscriptionId + ". Please make sure the ID you entered is correct and you have access to the cluster" ) -ForegroundColor Red
            Write-Host("")
            Stop-Transcript
            exit
        }
    }
}

# validate specified Azure Managed cluster exists and got access permissions
Write-Host("Checking specified Azure Managed cluster resource exists and got access...")
$clusterResource = Get-AzResource -ResourceId $clusterResourceId
if ($null -eq $clusterResource) {
    Write-Host("specified Azure Managed cluster resource id either you dont have access or doesnt exist") -ForegroundColor Red
    exit
}
$clusterRegion = $clusterResource.Location.ToLower()

if ($isArcK8sCluster -eq $true) {
   # validate identity
   $clusterIdentity = $clusterResource.identity.type.ToString().ToLower()
   if ($clusterIdentity.Contains("systemassigned") -eq $false) {
     Write-Host("Identity of Azure Arc enabled Kubernetes cluster should be systemassigned but it has identity: $clusterIdentity") -ForegroundColor Red
     exit
   }
}

if ($isAksCluster -eq $true) {
    Write-Host ("Disable AKS Monitoring Addon ..")
    # TBD
} else {
    Write-Host("Removing logAnalyticsWorkspaceResourceId tag on the cluster ResourceId")
    $clusterResource.Tags["logAnalyticsWorkspaceResourceId"] = ""
    Set-AzResource -Tag $clusterResource.Tags -ResourceId $clusterResource.ResourceId -Force
}

$helmVersion = helm version
Write-Host "Helm version" : $helmVersion

Write-Host("Deleting helm chart release : $helmChartReleaseName if exists, Azure Monitor for containers HELM chart ...")
try {
    if ([string]::IsNullOrEmpty($kubeContext)) {
        $releases = helm list --filter $helmChartReleaseName
        if ($releases.Count -lt 2) {
            Write-Host("There is no existing release with name : $helmChartReleaseName") -ForegroundColor Yellow
            exit
        }

        for($index =0 ; $index -lt $releases.Count ; $index ++ ) {
            $release = $releases[$index]
            if ($release.contains($helmChartReleaseName) -eq $true) {
            Write-Host("release found $helmChartReleaseName hence deleting it") -ForegroundColor Yellow
            helm del $helmChartReleaseName
            }
        }
    } else {
        Write-Host("using provided kube-context: $kubeContext")
        $releases = helm list --filter $helmChartReleaseName --kube-context $kubeContext
        if ($releases.Count -lt 2) {
            Write-Host("There is no existing release with name : $helmChartReleaseName") -ForegroundColor Yellow
            exit
        }

        for($index =0 ; $index -lt $releases.Count ; $index ++ ) {
            $release = $releases[$index]
            if ($release.contains($helmChartReleaseName) -eq $true) {
            Write-Host("release found $helmChartReleaseName hence deleting it") -ForegroundColor Yellow
            helm del $helmChartReleaseName --kube-context $kubeContext
            }
        }
    }
}
catch {
    Write-Host ("Failed to delete Azure Monitor for containers HELM chart : '" + $Error[0] + "' ") -ForegroundColor Red
    exit
}

Write-Host("Successfully disabled Azure Monitor for containers for cluster: $clusteResourceId") -ForegroundColor Green
