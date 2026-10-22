$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 otherwise reads the UTF-8 framework using the ANSI code page.
$framework = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\test_framework.ps1') -Raw -Encoding UTF8
. ([scriptblock]::Create($framework))

# Runs kubernetes/windows/distrust-compromised-cas.ps1 with the local ruby.exe against fixture CA
# bundles and throwaway CurrentUser certificate stores. It never changes LocalMachine stores or the
# CA bundle of the installed Ruby.
if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
    Write-Host 'Skipping: distrust-compromised-cas.ps1 runs only on Windows'
    exit 0
}
$ruby = Get-Command ruby.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $ruby) {
    # GitHub-hosted Windows runners have Ruby on PATH, so CI must not skip this test.
    if ($env:GITHUB_ACTIONS -eq 'true') {
        Write-Host 'ruby.exe was not found on PATH'
        exit 1
    }
    Write-Host 'Skipping: ruby.exe was not found on PATH'
    exit 0
}

$scriptPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\kubernetes\windows\distrust-compromised-cas.ps1')).ProviderPath
$intermediatesFile = Join-Path (Split-Path $scriptPath) 'emudhra-compromised-intermediates.pem'
$powershellExe = (Get-Process -Id $PID).Path

# Roots that anchor the compromised intermediates, as shipped in the CA bundle of Ruby 3.1.1.
$aaaCertificateServicesPem = @'
-----BEGIN CERTIFICATE-----
MIIEMjCCAxqgAwIBAgIBATANBgkqhkiG9w0BAQUFADB7MQswCQYDVQQGEwJHQjEb
MBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHDAdTYWxmb3JkMRow
GAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEhMB8GA1UEAwwYQUFBIENlcnRpZmlj
YXRlIFNlcnZpY2VzMB4XDTA0MDEwMTAwMDAwMFoXDTI4MTIzMTIzNTk1OVowezEL
MAkGA1UEBhMCR0IxGzAZBgNVBAgMEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UE
BwwHU2FsZm9yZDEaMBgGA1UECgwRQ29tb2RvIENBIExpbWl0ZWQxITAfBgNVBAMM
GEFBQSBDZXJ0aWZpY2F0ZSBTZXJ2aWNlczCCASIwDQYJKoZIhvcNAQEBBQADggEP
ADCCAQoCggEBAL5AnfRu4ep2hxxNRUSOvkbIgwadwSr+GB+O5AL686tdUIoWMQua
BtDFcCLNSS1UY8y2bmhGC1Pqy0wkwLxyTurxFa70VJoSCsN6sjNg4tqJVfMiWPPe
3M/vg4aijJRPn2jymJBGhCfHdr/jzDUsi14HZGWCwEiwqJH5YZ92IFCokcdmtet4
YgNW8IoaE+oxox6gmf049vYnMlhvB/VruPsUK6+3qszWY19zjNoFmag4qMsXeDZR
rOme9Hg6jc8P2ULimAyrL58OAd7vn5lJ8S3frHRNG5i1R8XlKdH5kBjHYpy+g8cm
ez6KJcfA3Z3mNWgQIJ2P2N7Sw4ScDV7oL8kCAwEAAaOBwDCBvTAdBgNVHQ4EFgQU
oBEKIz6W8Qfs4q8p74Klf9AwpLQwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQF
MAMBAf8wewYDVR0fBHQwcjA4oDagNIYyaHR0cDovL2NybC5jb21vZG9jYS5jb20v
QUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNqA0oDKGMGh0dHA6Ly9jcmwuY29t
b2RvLm5ldC9BQUFDZXJ0aWZpY2F0ZVNlcnZpY2VzLmNybDANBgkqhkiG9w0BAQUF
AAOCAQEACFb8AvCb6P+k+tZ7xkSAzk/ExfYAWMymtrwUSWgEdujm7l3sAg9g1o1Q
GE8mTgHj5rCl7r+8dFRBv/38ErjHT1r0iWAFf2C3BUrz9vHCv8S5dIa2LX1rzNLz
Rt0vxuBqw8M0Ayx9lt1awg6nCpnBBYurDC/zXDrPbDdVCYfeU0BsWO/8tqtlbgT2
G9w84FoVxp7Z8VlIMCFlA2zs6SFz7JsDoeA3raAVGI/6ugLOpyypEBMs1OUIJqsi
l2D4kF501KKaU73yqWjgom7C12yxow+ev+to51byrvLjKzg6CYG1a4XXvi3tPxq3
smPi9WIsgtRqAEFQ8TmDn5XpNpaYbg==
-----END CERTIFICATE-----
'@
$emSignEccRootCaG3Pem = @'
-----BEGIN CERTIFICATE-----
MIICTjCCAdOgAwIBAgIKPPYHqWhwDtqLhDAKBggqhkjOPQQDAzBrMQswCQYDVQQG
EwJJTjETMBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhyYSBUZWNo
bm9sb2dpZXMgTGltaXRlZDEgMB4GA1UEAxMXZW1TaWduIEVDQyBSb290IENBIC0g
RzMwHhcNMTgwMjE4MTgzMDAwWhcNNDMwMjE4MTgzMDAwWjBrMQswCQYDVQQGEwJJ
TjETMBEGA1UECxMKZW1TaWduIFBLSTElMCMGA1UEChMcZU11ZGhyYSBUZWNobm9s
b2dpZXMgTGltaXRlZDEgMB4GA1UEAxMXZW1TaWduIEVDQyBSb290IENBIC0gRzMw
djAQBgcqhkjOPQIBBgUrgQQAIgNiAAQjpQy4LRL1KPOxst3iAhKAnjlfSU2fySU0
WXTsuwYc58Byr+iuL+FBVIcUqEqy6HyC5ltqtdyzdc6LBtCGI79G1Y4PPwT01xyS
fvalY8L1X44uT6EYGQIrMgqCZH0Wk9GjQjBAMB0GA1UdDgQWBBR8XQKEE9TMipuB
zhccLikenEhjQjAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAKBggq
hkjOPQQDAwNpADBmAjEAvvNhzwIQHWSVB7gYboiFBS+DCBeQyh+KTOgNG3qxrdWB
CUfvO6wIBHxcmbHtRwfSAjEAnbpV/KlK6O3t5nYBQnvI+GDZjVGLVTv7jHvrZQnD
+JbNR6iC8hZVdyR+EhCVBCyj
-----END CERTIFICATE-----
'@

function Get-Sha256([byte[]]$Bytes) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha256.ComputeHash($Bytes)).Replace('-', '')
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-PemDer([string]$Text) {
    foreach ($match in [regex]::Matches($Text, '-----BEGIN CERTIFICATE-----([A-Za-z0-9+/=\s]+?)-----END CERTIFICATE-----')) {
        , [System.Convert]::FromBase64String(($match.Groups[1].Value -replace '\s', ''))
    }
}

function ConvertTo-Pem([byte[]]$Der) {
    $base64 = [System.Convert]::ToBase64String($Der)
    $lines = for ($i = 0; $i -lt $base64.Length; $i += 64) {
        $base64.Substring($i, [System.Math]::Min(64, $base64.Length - $i))
    }
    return "-----BEGIN CERTIFICATE-----`n$($lines -join "`n")`n-----END CERTIFICATE-----"
}

# An entry in the format of Ruby's cert.pem: title, underline, PEM block and blank lines.
function ConvertTo-BundleEntry([string]$Title, [byte[]]$Der, [int]$BlankLines) {
    return "$Title`n$('=' * $Title.Length)`n$(ConvertTo-Pem $Der)`n" + ("`n" * $BlankLines)
}

function New-TestRoot([string]$Name) {
    $key = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve+NamedCurves]::nistP256)
    try {
        $request = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new("CN=$Name", $key, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
        $request.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new($true, $false, 0, $true))
        $request.CertificateExtensions.Add([System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new([System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]'KeyCertSign, CrlSign', $true))
        $certificate = $request.CreateSelfSigned([System.DateTimeOffset]::UtcNow.AddDays(-1), [System.DateTimeOffset]::UtcNow.AddYears(1))
        try {
            return , $certificate.RawData
        }
        finally {
            $certificate.Dispose()
        }
    }
    finally {
        $key.Dispose()
    }
}

$storeNames = New-Object System.Collections.Generic.List[string]

function New-TestStoreName {
    $name = 'distrust-compromised-cas-test-' + [guid]::NewGuid().ToString('N')
    $storeNames.Add($name)
    return $name
}

function Get-StoreKey([string]$Name) {
    return "HKCU:\Software\Microsoft\SystemCertificates\$Name"
}

function Get-StoreThumbprints([string]$Name) {
    if (-not (Test-Path -LiteralPath (Get-StoreKey $Name))) {
        return ''
    }
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($Name, [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]'ReadOnly, OpenExistingOnly')
    try {
        return (@($store.Certificates | ForEach-Object { $_.Thumbprint }) | Sort-Object) -join ','
    }
    finally {
        $store.Close()
    }
}

function Remove-TestStore([string]$Name) {
    if (-not (Test-Path -LiteralPath (Get-StoreKey $Name))) {
        return
    }
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($Name, [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]'ReadWrite, OpenExistingOnly')
    try {
        foreach ($certificate in @($store.Certificates)) {
            $store.Remove($certificate)
        }
    }
    finally {
        $store.Close()
    }
    Remove-Item -LiteralPath (Get-StoreKey $Name) -Recurse -Force
}

# Runs the script in a child process, as the image build does, with only the given OpenSSL
# variables set. Returns the exit code and output.
function Invoke-DistrustScript([hashtable]$Environment, [string[]]$Arguments) {
    $saved = @{}
    foreach ($name in 'SSL_CERT_FILE', 'SSL_CERT_DIR', 'SSL_CERT_URI') {
        $saved[$name] = [System.Environment]::GetEnvironmentVariable($name)
        [System.Environment]::SetEnvironmentVariable($name, $Environment[$name])
    }
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $powershellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $scriptPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally {
        foreach ($name in $saved.Keys) {
            [System.Environment]::SetEnvironmentVariable($name, $saved[$name])
        }
    }
    $lines = @($output | ForEach-Object { "$_" })
    foreach ($line in $lines) {
        Write-Host "    $line"
    }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = $lines -join "`n" }
}

$aaaDer = @(Get-PemDer $aaaCertificateServicesPem)[0]
$emSignDer = @(Get-PemDer $emSignEccRootCaG3Pem)[0]
Assert-Equals 'D7A7A0FB5D7E2731D771E9484EBCDEF71D5F0C3E0A2948782BC83EE0EA699EF4' (Get-Sha256 $aaaDer) 'fixture: AAA Certificate Services root' | Out-Null
Assert-Equals '86A1ECBA089C4A8D3BBE2734C612BA341D813E043CF9E8A862CD5C57A36BBE6B' (Get-Sha256 $emSignDer) 'fixture: emSign ECC Root CA - G3 root' | Out-Null

$intermediates = @(Get-PemDer ([System.IO.File]::ReadAllText($intermediatesFile)))
Assert-Equals '16' "$($intermediates.Count)" 'fixture: compromised intermediates' | Out-Null
$expectedThumbprints = (@($intermediates | ForEach-Object {
    [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($_).Thumbprint
}) | Sort-Object) -join ','

$rootA = New-TestRoot 'Docker-Provider unit test root A'
$rootB = New-TestRoot 'Docker-Provider unit test root B'
$rootC = New-TestRoot 'Docker-Provider unit test root C'
$header = "##`n## Test CA bundle in the format of Ruby's cert.pem`n##`n`n"
$entryA = ConvertTo-BundleEntry 'Docker-Provider unit test root A' $rootA 2
$entryB = ConvertTo-BundleEntry 'Docker-Provider unit test root B' $rootB 2
$entryC = ConvertTo-BundleEntry 'Docker-Provider unit test root C' $rootC 1
$fixture = $header + $entryA + (ConvertTo-BundleEntry 'AAA Certificate Services' $aaaDer 2) + $entryB +
    (ConvertTo-BundleEntry 'emSign ECC Root CA - G3' $emSignDer 2) + $entryC
$expected = $header + $entryA + $entryB + $entryC
$ascii = [System.Text.Encoding]::ASCII
$fixtureSha256 = Get-Sha256 ($ascii.GetBytes($fixture))
$expectedSha256 = Get-Sha256 ($ascii.GetBytes($expected))

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('distrust-compromised-cas-test-' + [guid]::NewGuid().ToString('N'))
$emptyDir = Join-Path $workDir 'empty'
$bundle = Join-Path $workDir 'cert.pem'
try {
    [void][System.IO.Directory]::CreateDirectory($emptyDir)
    # Keep OpenSSL from loading CA certificates from anywhere but the fixture bundles.
    $isolation = @{ SSL_CERT_DIR = $emptyDir; SSL_CERT_URI = $emptyDir }

    # Image build: Ruby loads the CA bundle that the script updates.
    [System.IO.File]::WriteAllText($bundle, $fixture, $ascii)
    $store = New-TestStoreName
    $arguments = @('-StoreLocation', 'CurrentUser', '-StoreName', $store, '-RubyExe', $ruby.Path)
    $result = Invoke-DistrustScript ($isolation + @{ SSL_CERT_FILE = $bundle }) $arguments
    Assert-Equals '0' "$($result.ExitCode)" 'distrust: exit code' | Out-Null
    Assert-Equals $expectedSha256 (Get-Sha256 ([System.IO.File]::ReadAllBytes($bundle))) 'distrust: only the two anchors are removed from the CA bundle, byte for byte' | Out-Null
    Assert-Equals $expectedThumbprints (Get-StoreThumbprints $store) 'distrust: the 16 intermediates are in the store' | Out-Null
    Assert-Equals 'True' "$($result.Output -match 'Checked 18 compromised and 3 CA bundle certificates with .+: 0 failures')" 'distrust: Ruby trust check' | Out-Null

    # Rerun: nothing changes.
    $result = Invoke-DistrustScript ($isolation + @{ SSL_CERT_FILE = $bundle }) $arguments
    Assert-Equals '0' "$($result.ExitCode)" 'rerun: exit code' | Out-Null
    Assert-Equals $expectedSha256 (Get-Sha256 ([System.IO.File]::ReadAllBytes($bundle))) 'rerun: CA bundle unchanged' | Out-Null
    Assert-Equals $expectedThumbprints (Get-StoreThumbprints $store) 'rerun: store unchanged' | Out-Null

    # An intermediates file with a certificate that is not pinned fails before anything changes.
    $tampered = Join-Path $workDir 'tampered.pem'
    $intermediatesText = [System.IO.File]::ReadAllText($intermediatesFile)
    $firstPem = [regex]::Match($intermediatesText, '-----BEGIN CERTIFICATE-----[A-Za-z0-9+/=\s]+?-----END CERTIFICATE-----').Value
    [System.IO.File]::WriteAllText($tampered, $intermediatesText.Replace($firstPem, (ConvertTo-Pem $rootA)), $ascii)
    [System.IO.File]::WriteAllText($bundle, $fixture, $ascii)
    $store = New-TestStoreName
    $result = Invoke-DistrustScript ($isolation + @{ SSL_CERT_FILE = $bundle }) @('-IntermediatesFile', $tampered, '-StoreLocation', 'CurrentUser', '-StoreName', $store, '-RubyExe', $ruby.Path)
    Assert-Equals '1' "$($result.ExitCode)" 'unpinned intermediate: exit code' | Out-Null
    Assert-Equals 'True' "$($result.Output -match 'is not pinned')" 'unpinned intermediate: error' | Out-Null
    Assert-Equals $fixtureSha256 (Get-Sha256 ([System.IO.File]::ReadAllBytes($bundle))) 'unpinned intermediate: CA bundle unchanged' | Out-Null
    Assert-Equals 'False' "$(Test-Path -LiteralPath (Get-StoreKey $store))" 'unpinned intermediate: store not created' | Out-Null

    # A missing CA bundle fails before anything changes.
    $store = New-TestStoreName
    $result = Invoke-DistrustScript ($isolation + @{ SSL_CERT_FILE = $bundle }) @('-RubyCertFile', (Join-Path $workDir 'missing.pem'), '-StoreLocation', 'CurrentUser', '-StoreName', $store, '-RubyExe', $ruby.Path)
    Assert-Equals '1' "$($result.ExitCode)" 'missing CA bundle: exit code' | Out-Null
    Assert-Equals 'True' "$($result.Output -match 'missing\.pem')" 'missing CA bundle: error' | Out-Null
    Assert-Equals $fixtureSha256 (Get-Sha256 ([System.IO.File]::ReadAllBytes($bundle))) 'missing CA bundle: the bundle Ruby loads is unchanged' | Out-Null
    Assert-Equals 'False' "$(Test-Path -LiteralPath (Get-StoreKey $store))" 'missing CA bundle: store not created' | Out-Null

    # Ruby loads a different CA bundle than the one updated: the trust check fails the script.
    $loaded = Join-Path $workDir 'loaded.pem'
    [System.IO.File]::WriteAllText($loaded, $fixture, $ascii)
    $store = New-TestStoreName
    $result = Invoke-DistrustScript ($isolation + @{ SSL_CERT_FILE = $loaded }) @('-RubyCertFile', $bundle, '-StoreLocation', 'CurrentUser', '-StoreName', $store, '-RubyExe', $ruby.Path)
    Assert-Equals '1' "$($result.ExitCode)" 'still trusted: exit code' | Out-Null
    Assert-Equals '10' "$([regex]::Matches($result.Output, 'STILL TRUSTED').Count)" 'still trusted: the 8 intermediates issued by AAA Certificate Services and the 2 anchors are reported' | Out-Null
}
finally {
    foreach ($name in $storeNames) {
        Remove-TestStore $name
    }
    Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
}

if (Print-TestSummary) {
    exit 0
}
exit 1
