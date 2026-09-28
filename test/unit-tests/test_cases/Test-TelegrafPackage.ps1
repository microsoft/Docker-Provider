$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 otherwise reads the UTF-8 framework using the ANSI code page.
$framework = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\test_framework.ps1') -Raw -Encoding UTF8
. ([scriptblock]::Create($framework))

$setupPath = Join-Path $PSScriptRoot '..\..\..\kubernetes\windows\setup.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) {
    throw "Cannot parse Windows setup.ps1: $parseErrors"
}

# Execute only the real Telegraf install body, never the other installers or their cleanup.
$assignment = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left.Extent.Text -eq '$telegrafUri'
}, $true)
if ($null -eq $assignment -or $assignment.Parent.Parent -isnot [System.Management.Automation.Language.TryStatementAst]) {
    throw 'Cannot locate the Telegraf install try block'
}
$body = $assignment.Parent.Extent.Text
$installTelegraf = [scriptblock]::Create($body.Substring(1, $body.Length - 2))

# Keep command mocks scoped to this invocation, including when the main runner calls this file.
& {
    function Record-Operation($Name, $Action) {
        $script:operations += $Name
        Assert-Equals 'Stop' $Action "$Name must fail on errors" | Out-Null
        if ($script:failureAt -eq $Name) {
            throw "Simulated $Name failure"
        }
    }

    function Invoke-WebRequest($Uri, $OutFile, $ErrorAction) {
        Record-Operation 'download' $ErrorAction
        Assert-Equals 'https://dl.influxdata.com/telegraf/releases/telegraf-1.40.1_windows_amd64.zip' $Uri 'official versioned ZIP' | Out-Null
        Assert-Equals '\installation\telegraf.zip' $OutFile 'download destination' | Out-Null
    }

    function Get-FileHash($Path, $Algorithm, $ErrorAction) {
        Record-Operation 'hash' $ErrorAction
        Assert-Equals '\installation\telegraf.zip' $Path 'hash the downloaded ZIP' | Out-Null
        Assert-Equals 'SHA256' $Algorithm 'hash algorithm' | Out-Null
        [pscustomobject]@{ Hash = $script:archiveHash }
    }

    function Expand-Archive($Path, $Destination, $ErrorAction) {
        Record-Operation 'extract' $ErrorAction
        Assert-Equals '\installation\telegraf.zip' $Path 'extract the verified ZIP' | Out-Null
        Assert-Equals '\installation\telegraf' $Destination 'extraction directory' | Out-Null
    }

    function Move-Item($Path, $Destination, $ErrorAction) {
        Record-Operation 'move' $ErrorAction
        Assert-Equals '\installation\telegraf\telegraf-1.40.1\*' $Path 'versioned archive layout' | Out-Null
        Assert-Equals '\opt\telegraf\' $Destination 'existing runtime and signing path' | Out-Null
    }

    $cases = @(
        @{ Name = 'valid package'; FailureAt = ''; Error = ''; Operations = 'download,hash,extract,move' },
        @{ Name = 'hash mismatch'; FailureAt = ''; Error = 'SHA256 mismatch for Telegraf Windows package'; Operations = 'download,hash' },
        @{ Name = 'download failure'; FailureAt = 'download'; Error = 'Simulated download failure'; Operations = 'download' },
        @{ Name = 'hash failure'; FailureAt = 'hash'; Error = 'Simulated hash failure'; Operations = 'download,hash' },
        @{ Name = 'extraction failure'; FailureAt = 'extract'; Error = 'Simulated extract failure'; Operations = 'download,hash,extract' },
        @{ Name = 'move failure'; FailureAt = 'move'; Error = 'Simulated move failure'; Operations = 'download,hash,extract,move' }
    )
    foreach ($case in $cases) {
        $script:operations = @()
        $script:failureAt = $case.FailureAt
        $script:archiveHash = 'CABE07907628AFC17CE8C58A1C27B3A55A838B1FB9418B2C05E9342E6E8AF8D9'
        if ($case.Name -eq 'hash mismatch') {
            $script:archiveHash = '0' * 64
        }
        $errorMessage = ''
        try {
            & $installTelegraf
        }
        catch {
            $errorMessage = $_.Exception.Message
        }
        Assert-Equals $case.Error $errorMessage "$($case.Name): expected failure behavior" | Out-Null
        Assert-Equals $case.Operations ($script:operations -join ',') "$($case.Name): no operations after failure" | Out-Null
    }
}

if (Print-TestSummary) {
    exit 0
}
exit 1
