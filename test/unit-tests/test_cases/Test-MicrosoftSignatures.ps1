$ErrorActionPreference = 'Stop'
$framework = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\test_framework.ps1') -Raw -Encoding UTF8
. ([scriptblock]::Create($framework))

$setupPath = Join-Path $PSScriptRoot '..\..\..\kubernetes\windows\setup.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($setupPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw 'Cannot parse Windows setup.ps1.' }
$signatureFunction = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Test-MicrosoftCodeSignature'
}, $true)
$agentTry = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.TryStatementAst] -and
        $node.Body.Extent.Text.Contains('Invoke-WebRequest -Uri $windowsazuremonitoragent')
}, $true)
if ($null -eq $signatureFunction -or $null -eq $agentTry) { throw 'Cannot locate production signature verification.' }
$statements = @($agentTry.Body.Statements | Select-Object -First 4)
if (-not $statements[-1].Extent.Text.StartsWith('Move-Item')) { throw 'Unexpected agent installation statement order.' }

# Exercise the real download-to-move path, excluding version-file writes and unrelated installers.
& {
    . ([scriptblock]::Create($signatureFunction.Extent.Text))
    $installAgent = [scriptblock]::Create(($statements | ForEach-Object { $_.Extent.Text }) -join "`n")
    $windowsazuremonitoragent = 'https://example.invalid/agent.zip'

    function Record-Operation($Name, $Action) {
        $script:operations += $Name
        Assert-Equals 'Stop' ([string]$Action) "$Name must fail on errors" | Out-Null
        if ($script:failureAt -eq $Name) { throw "Simulated $Name failure" }
    }
    function Invoke-WebRequest($Uri, $OutFile, $ErrorAction) {
        Record-Operation 'download' $ErrorAction
    }
    function Expand-Archive($Path, $Destination, $ErrorAction) {
        Record-Operation 'extract' $ErrorAction
    }
    function Move-Item($Path, $Destination, $ErrorAction) {
        Record-Operation 'move' $ErrorAction
    }
    function Get-AuthenticodeSignature {
        [CmdletBinding()]
        param([string]$LiteralPath)
        Record-Operation 'signature' $PSBoundParameters.ErrorAction
        [pscustomobject]@{
            Status = $script:signatureStatus
            SignerCertificate = [pscustomobject]@{ Subject = $script:publisher }
        }
    }

    $cases = @(
        @{ Name = 'valid signatures'; Status = 'Valid'; FailureAt = ''; WrongPublisher = $false; Error = ''; Operations = 'download,extract,signature,signature,signature,signature,move' },
        @{ Name = 'unsigned binary'; Status = 'NotSigned'; FailureAt = ''; WrongPublisher = $false; Error = 'signature'; Operations = 'download,extract,signature' },
        @{ Name = 'modified binary'; Status = 'HashMismatch'; FailureAt = ''; WrongPublisher = $false; Error = 'signature'; Operations = 'download,extract,signature' },
        @{ Name = 'untrusted binary'; Status = 'NotTrusted'; FailureAt = ''; WrongPublisher = $false; Error = 'signature'; Operations = 'download,extract,signature' },
        @{ Name = 'wrong publisher'; Status = 'Valid'; FailureAt = ''; WrongPublisher = $true; Error = 'signature'; Operations = 'download,extract,signature' },
        @{ Name = 'download failure'; Status = 'Valid'; FailureAt = 'download'; WrongPublisher = $false; Error = 'Simulated download failure'; Operations = 'download' },
        @{ Name = 'extract failure'; Status = 'Valid'; FailureAt = 'extract'; WrongPublisher = $false; Error = 'Simulated extract failure'; Operations = 'download,extract' },
        @{ Name = 'move failure'; Status = 'Valid'; FailureAt = 'move'; WrongPublisher = $false; Error = 'Simulated move failure'; Operations = 'download,extract,signature,signature,signature,signature,move' }
    )
    foreach ($case in $cases) {
        $script:operations = @()
        $script:signatureStatus = $case.Status
        $script:failureAt = $case.FailureAt
        $script:publisher = if ($case.WrongPublisher) { 'CN=Microsoft Corporation, O=Other Corporation, C=US' } else { 'CN=Microsoft Corporation, O=Microsoft Corporation, C=US' }
        $message = ''
        try { & $installAgent } catch { $message = $_.Exception.Message }
        $expected = $case.Error
        if ($expected -eq 'signature') {
            $expected = 'A valid Microsoft code signature is required: \installation\windowsazuremonitoragent\Monitoring\Agent\MonAgentLauncher.exe'
        }
        Assert-Equals $expected $message "$($case.Name): expected failure" | Out-Null
        Assert-Equals $case.Operations ($script:operations -join ',') "$($case.Name): no operations after failure" | Out-Null
    }
}

if (Print-TestSummary) { exit 0 }
exit 1
