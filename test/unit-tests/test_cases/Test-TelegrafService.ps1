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
        $node.Name -eq 'Install-TelegrafService'
}, $true)
if ($null -eq $function) { throw 'Cannot locate Install-TelegrafService' }
. ([scriptblock]::Create($function.Extent.Text))

& {
    function Test-Path($LiteralPath, $PathType) {
        Assert-Equals 'C:\opt\amalogswindows\scripts\ruby\telegraf-windows-service.rb' $LiteralPath 'packaged host path' | Out-Null
        Assert-Equals 'Leaf' $PathType 'host must be a file' | Out-Null
        return $script:hostPresent
    }

    function Get-Command($Name, $ErrorAction) {
        Assert-Equals 'ruby.exe' $Name 'existing runtime' | Out-Null
        Assert-Equals 'Stop' $ErrorAction 'missing runtime is fatal' | Out-Null
        [pscustomobject]@{ Source = 'C:\Program Files\Ruby31\ruby.exe' }
    }

    function New-Service($Name, $BinaryPathName, $DisplayName, $StartupType, $ErrorAction) {
        $script:installed = [pscustomobject]@{
            Name = $Name; BinaryPath = $BinaryPathName; DisplayName = $DisplayName
        }
        Assert-Equals 'Automatic' $StartupType 'preserve service startup mode' | Out-Null
        Assert-Equals 'Stop' $ErrorAction 'registration errors are fatal' | Out-Null
    }

    $script:hostPresent = $true
    foreach ($case in @(
        @{ Name = 'telegraf'; Role = 'prometheus'; DisplayName = 'Telegraf Data Collector Service' },
        @{ Name = 'telegraf-ama-logs-process-metrics'; Role = 'process-metrics'; DisplayName = 'Telegraf AMA Logs Process Metrics' }
    )) {
        $script:installed = $null
        Install-TelegrafService -ServiceName $case.Name
        Assert-Equals $case.Name $script:installed.Name 'preserve service name' | Out-Null
        Assert-Equals $case.DisplayName $script:installed.DisplayName 'distinct display names' | Out-Null
        $expected = '"C:\Program Files\Ruby31\ruby.exe" "C:\opt\amalogswindows\scripts\ruby\telegraf-windows-service.rb" ' + $case.Role
        Assert-Equals $expected $script:installed.BinaryPath 'quoted host path; no config path in wrapper command line' | Out-Null
    }

    $script:hostPresent = $false
    $script:installed = $null
    $message = ''
    try { Install-TelegrafService -ServiceName telegraf } catch { $message = $_.Exception.Message }
    Assert-Equals 'Telegraf Windows service host not found: C:\opt\amalogswindows\scripts\ruby\telegraf-windows-service.rb' $message 'missing host must not fall back to broken native detection' | Out-Null
    Assert-Equals 'True' ($null -eq $script:installed).ToString() 'no service registered after missing host' | Out-Null
}

if (Print-TestSummary) { exit 0 }
exit 1
