$ErrorActionPreference = 'Stop'
$framework = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\test_framework.ps1') -Raw -Encoding UTF8
. ([scriptblock]::Create($framework))

$tokens = $null
$errors = $null
$path = Join-Path $PSScriptRoot '..\..\..\kubernetes\windows\main.ps1'
$ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw "Cannot parse main.ps1: $errors" }
$function = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Set-CloudSpecificApplicationInsightsConfig'
}, $true)
if ($null -eq $function) { throw 'Cannot locate Set-CloudSpecificApplicationInsightsConfig' }
. ([scriptblock]::Create($function.Extent.Text))

& {
    function Set-ProcessAndMachineEnvVariables($name, $value) {
        $script:settings[$name] = $value
    }

    foreach ($case in @(
        @{ Cloud = 'azuredeloscloud'; Key = 'f2a4e81f-3974-d7b0-a1bb-4f360bb27e7c'; Endpoint = 'https://deloscloudgermanycentral-0.in.applicationinsights.sovcloud-api.de/v2/track' },
        @{ Cloud = 'azurebleucloud'; Key = '560bc2b7-2cf8-b7d4-b8a2-c3caba857133'; Endpoint = 'https://bleufrancecentral-0.in.applicationinsights.sovcloud-api.fr/v2/track' }
    )) {
        $script:settings = @{}
        Set-CloudSpecificApplicationInsightsConfig $case.Cloud
        $key = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($script:settings['APPLICATIONINSIGHTS_AUTH']))
        Assert-Equals $case.Key $key "$($case.Cloud) key" | Out-Null
        Assert-Equals $case.Endpoint $script:settings['APPLICATIONINSIGHTS_ENDPOINT'] "$($case.Cloud) endpoint" | Out-Null
    }
}

if (Print-TestSummary) { exit 0 }
exit 1
