param(
    [Parameter(Mandatory = $false)]
    [string]$LinuxImage,
    [Parameter(Mandatory = $false)]
    [string]$WindowsImage,
    [Parameter(Mandatory = $false)]
    [string]$LinuxTag,
    [Parameter(Mandatory = $false)]
    [string]$WindowsTag,
    [Parameter(Mandatory = $false)]
    [string]$LinuxRepo = "mcr.microsoft.com/azuremonitor/containerinsights/cidev",
    [Parameter(Mandatory = $false)]
    [string]$WindowsRepo = "mcr.microsoft.com/azuremonitor/containerinsights/cidev",
    [string]$Namespace = "demo-ama",
    [string]$ChartPath
)

$ErrorActionPreference = "Stop"

# Determine repo root and default chart path
$scriptDir = Split-Path -Parent $PSCommandPath
$scriptsDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $scriptsDir
if ([string]::IsNullOrWhiteSpace($ChartPath)) {
    $ChartPath = Join-Path $repoRoot "charts/azuremonitor-containers"
} elseif (-not [System.IO.Path]::IsPathRooted($ChartPath)) {
    $ChartPath = Join-Path $repoRoot $ChartPath
}

try {
    $resolvedChartPath = (Resolve-Path -Path $ChartPath -ErrorAction Stop).ProviderPath
} catch {
    throw "Unable to locate chart path '$ChartPath'. Provide -ChartPath explicitly (absolute path or relative to repo root)."
}

function Assert-Tool {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool '$Name' not found on PATH."
    }
}

Assert-Tool -Name "kubectl"
Assert-Tool -Name "helm"

function Resolve-Image {
    param(
        [string]$Image,
        [string]$Repo,
        [string]$Tag,
        [string]$Label
    )

    if (-not [string]::IsNullOrWhiteSpace($Image)) {
        $parts = $Image -split ":", 2
        if ($parts.Count -ne 2) {
            throw "$Label image '$Image' must include a tag (e.g. repo:tag)."
        }
        return @{
            Repo = $parts[0]
            Tag  = $parts[1]
        }
    }

    if ([string]::IsNullOrWhiteSpace($Repo)) {
        throw "$Label repository is required when image is not provided."
    }
    if ([string]::IsNullOrWhiteSpace($Tag)) {
        throw "$Label tag is required when image is not provided."
    }

    return @{
        Repo = $Repo
        Tag  = $Tag
    }
}

$linuxImageInfo = Resolve-Image -Image $LinuxImage -Repo $LinuxRepo -Tag $LinuxTag -Label "Linux"
$windowsImageInfo = Resolve-Image -Image $WindowsImage -Repo $WindowsRepo -Tag $WindowsTag -Label "Windows"

Write-Host "Using namespace: $Namespace"
Write-Host "Linux repo/tag: $($linuxImageInfo.Repo) : $($linuxImageInfo.Tag)"
Write-Host "Windows repo/tag: $($windowsImageInfo.Repo) : $($windowsImageInfo.Tag)"
Write-Host "Chart path: $resolvedChartPath"

Write-Host "Ensuring namespace exists..."
try {
    kubectl get namespace $Namespace 1>$null 2>$null
    Write-Host "Namespace '$Namespace' already exists."
} catch {
    Write-Host "Namespace '$Namespace' not found. Creating..."
    kubectl create namespace $Namespace | Out-Null
}

$helmArgs = @(
    "upgrade", "--install", "ama-logs", $resolvedChartPath,
    "--namespace", $Namespace,
    "--create-namespace",
    "--set", "amalogs.image.repo=$($linuxImageInfo.Repo)",
    "--set", "amalogs.image.tag=$($linuxImageInfo.Tag)",
    "--set", "amalogs.image.tagWindows=$($windowsImageInfo.Tag)",
    "--set", "amalogs.ISTEST=true"
)

Write-Host "Running Helm upgrade..."
helm @helmArgs
if ($LASTEXITCODE -ne 0) {
    throw "Helm upgrade failed. Resolve the error above and retry."
}

Write-Host "Waiting for Linux daemonset rollout..."
kubectl -n $Namespace rollout status ds/ama-logs --timeout=5m

Write-Host "Waiting for Windows daemonset rollout..."
kubectl -n $Namespace rollout status ds/ama-logs-windows --timeout=5m

Write-Host "Current pods:"
kubectl -n $Namespace get pods -o wide

Write-Host "Tail logs from Linux daemonset (last 200 lines)..."
$logOutput = & kubectl -n $Namespace logs ds/ama-logs --all-containers --tail=200 2>&1
if ($LASTEXITCODE -eq 0) {
    $logOutput
} else {
    Write-Host "No logs available or daemonset missing (see errors above)."
}

Write-Host ""
Write-Host "Dry run completed. Cleanup commands:"
Write-Host "  helm uninstall ama-logs -n $Namespace"
Write-Host "  kubectl delete namespace $Namespace --ignore-not-found"
