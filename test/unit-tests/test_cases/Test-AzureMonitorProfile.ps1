param(
    [string]$TargetScript,
    [ValidateSet("managed", "spn", "mixed")]
    [string]$Mode = "managed"
)

if ($TargetScript) {
    function Get-Module {
        param([switch]$ListAvailable, [string]$Name)
        [pscustomobject]@{ Name = $Name }
    }
    function Get-AzContext {
        [pscustomobject]@{
            Account = "mock-account"
            Subscription = [pscustomobject]@{ Id = "test-sub" }
        }
    }
    function New-MockCluster {
        param([string]$Name)
        $clientId = if ($Mode -eq "spn" -or ($Mode -eq "mixed" -and $Name -eq "first")) { "spn-client" } else { "msi" }
        [pscustomobject]@{
            Id = "/subscriptions/test-sub/resourceGroups/test-rg/providers/Microsoft.ContainerService/managedClusters/$Name"
            Name = $Name
            ServicePrincipalProfile = [pscustomobject]@{ ClientId = $clientId }
        }
    }
    function Get-AzAks {
        [CmdletBinding()]
        param([string]$ResourceGroupName, [string]$Name)
        if ($Name) {
            New-MockCluster $Name
        }
        else {
            New-MockCluster "first"
            New-MockCluster "second"
        }
    }
    function Invoke-AzRestMethod {
        [CmdletBinding()]
        param([string]$Path, [string]$Method)
        [pscustomobject]@{ Content = '{"identity":{"principalId":"control-plane-principal"}}' }
    }
    function New-AzRoleAssignment {
        [CmdletBinding()]
        param([string]$ApplicationId, [string]$ObjectId, [string]$Scope, [string]$RoleDefinitionName)
        Write-Host "ROLE_ASSIGNMENT $ApplicationId $ObjectId"
    }
    function Stop-Transcript {}

    $parameters = @{ SubscriptionId = "test-sub" }
    if ($TargetScript -notmatch "_atscale\.ps1$") {
        $parameters.ClusterResourceGroup = "test-rg"
        $parameters.clusterName = "first"
    }
    $global:LASTEXITCODE = 0
    & $TargetScript @parameters
    exit $LASTEXITCODE
}

. (Join-Path $PSScriptRoot "../test_framework.ps1")

$scriptRoot = (Resolve-Path (Join-Path $PSScriptRoot "../../../scripts/onboarding/aks/mdmonboarding")).Path
$pwsh = (Get-Process -Id $PID).Path

function Invoke-MockedOnboarding {
    param([string]$FileName, [string]$TestMode)
    $output = @(& $pwsh -NoLogo -NoProfile -File $PSCommandPath -TargetScript (Join-Path $scriptRoot $FileName) -Mode $TestMode 2>&1)
    [pscustomobject]@{ Code = $LASTEXITCODE; Output = $output }
}

$result = Invoke-MockedOnboarding "mdm_onboarding.ps1" "managed"
Assert-Equals "1" $result.Code "collector identity cannot be inferred from Azure Monitor Profile" | Out-Null
Assert-Equals "0" @($result.Output | Where-Object { "$_" -match "ROLE_ASSIGNMENT" }).Count "never grant the control-plane identity" | Out-Null

$result = Invoke-MockedOnboarding "mdm_onboarding.ps1" "spn"
Assert-Equals "0" $result.Code "preserve legacy service-principal onboarding" | Out-Null
Assert-Equals "1" @($result.Output | Where-Object { "$_" -match "ROLE_ASSIGNMENT spn-client" }).Count "assign the existing service principal" | Out-Null

$result = Invoke-MockedOnboarding "mdm_onboarding_atscale.ps1" "mixed"
Assert-Equals "1" $result.Code "report clusters whose collector identity is unavailable" | Out-Null
Assert-Equals "1" @($result.Output | Where-Object { "$_" -match "ROLE_ASSIGNMENT" }).Count "never reuse a preceding cluster identity" | Out-Null

if (Print-TestSummary) { exit 0 } else { exit 1 }
