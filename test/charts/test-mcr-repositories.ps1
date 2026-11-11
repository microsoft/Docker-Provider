$ErrorActionPreference = 'Stop'
$repository = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$source = Join-Path $repository 'charts\azuremonitor-containerinsights'
$chart = Join-Path ([IO.Path]::GetTempPath()) ("ama-logs-registry-tests-" + [Guid]::NewGuid().ToString('N'))

New-Item -ItemType Directory -Path $chart | Out-Null
try {
    Copy-Item -LiteralPath "$source\templates" -Destination "$chart\templates" -Recurse
    foreach ($name in @('Chart', 'values')) {
        $content = [IO.File]::ReadAllText("$source\$name-template.yaml")
        $content = $content.Replace('${HELM_SEMVER}', '0.1.0').Replace('${IMAGE_TAG}', 'registry-test').Replace('${IMAGE_TAG_WINDOWS}', 'registry-test-win')
        $content = $content.Replace('<your_cluster_id>', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/registry-tests/providers/Microsoft.ContainerService/managedClusters/registry-tests')
        [IO.File]::WriteAllText("$chart\$name.yaml", $content)
    }

    $cases = @(
        @('', 'mcr.microsoft.com'),
        @('AZUREPUBLICCLOUD', 'mcr.microsoft.com'),
        @('AZUREUSGOVERNMENTCLOUD', 'mcr.microsoft.com'),
        @('AZURECHINACLOUD', 'mcr.azk8s.cn'),
        @('USNat', 'mcr.microsoft.eaglex.ic.gov'),
        @('USSec', 'mcr.microsoft.scloud'),
        @('AzureBleuCloud', 'mcr.sovcloud-azure.fr'),
        @('AzureDelosCloud', 'mcr.sovcloud-azure.de'),
        @('unknown', 'mcr.microsoft.com')
    )
    foreach ($case in $cases) {
        $cloud = $case[0]
        $registry = $case[1]
        $helmArgs = @(
            '--set-string', "global.commonGlobals.CloudEnvironment=$cloud",
            '--set', 'OmsAgent.isRSVPAEnabled=true,OmsAgent.isMultitenancyLogsEnabled=true'
        )
        $lint = & helm lint $chart @helmArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "helm lint failed for '$cloud': $lint"
        }
        $rendered = & helm template ama-logs $chart @helmArgs
        if ($LASTEXITCODE -ne 0) {
            throw "helm template failed for '$cloud'"
        }
        $images = @([regex]::Matches(($rendered -join "`n"), '(?m)^\s+image:\s*"?([^"\r\n]+)"?\s*$') |
            ForEach-Object { $_.Groups[1].Value.Trim() })
        $expected = @{
            "$registry/azuremonitor/containerinsights/ciprod:registry-test" = 4
            "$registry/azuremonitor/containerinsights/ciprod:registry-test-win" = 1
            "$registry/oss/v2/kubernetes/autoscaler/addon-resizer:v1.8.23-4" = 1
        }
        foreach ($image in $expected.Keys) {
            $count = @($images | Where-Object { $_ -ceq $image }).Count
            if ($count -ne $expected[$image]) {
                throw "Cloud '$cloud': expected $($expected[$image]) reference(s) to '$image', got $count. Images: $images"
            }
        }
        Write-Output "PASS '$cloud': helm lint and six component image references -> $registry"
    }
} finally {
    Remove-Item -LiteralPath $chart -Recurse -Force
}
