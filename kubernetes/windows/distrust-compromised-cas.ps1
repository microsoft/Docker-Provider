<#
.SYNOPSIS
Distrusts the eMudhra (emSign) certificate authorities affected by the October 2026 intermediate CA
key compromise. Runs during the Windows image build.

.DESCRIPTION
1. Imports the compromised intermediate CA certificates into the Windows Disallowed store, so
   CryptoAPI/Schannel clients reject them even when the node cannot download Microsoft's
   disallowed certificate list.
2. Removes the roots that anchor those intermediates from Ruby's own CA bundle. Ruby (fluentd and
   its plugins) uses OpenSSL with that bundle instead of the Windows certificate stores, and
   OpenSSL cannot distrust an intermediate, so the anchors have to go.
3. Uses Ruby to check that the compromised certificates are no longer trusted and that every
   remaining certificate in the bundle still is.

Every certificate is pinned by SHA-256 (https://emudhra.we-have-a-problem.com/). The script exits
with code 1 when a step or check fails, which fails the image build.
#>
[CmdletBinding()]
param(
    # PEM file with the compromised intermediate CA certificates.
    [string]$IntermediatesFile = '',
    [string]$StoreName = 'Disallowed',
    [ValidateSet('LocalMachine', 'CurrentUser')]
    [string]$StoreLocation = 'LocalMachine',
    # Ruby whose CA bundle is changed and checked. Defaults to ruby.exe on PATH.
    [string]$RubyExe = '',
    # CA bundle to change. Defaults to the bundle that RubyExe loads.
    [string]$RubyCertFile = ''
)

$ErrorActionPreference = 'Stop'

# SHA-256 (DER) of the compromised intermediates, from impacted-intermediates.json.
$intermediatePinTable = @'
42C4ACCD12C4F59597925E1A08A7A90102608543809308D50EC427E118BA1493  EM DV TLS CA - G3B, issued by emSign Root TLS CA - G3
45A883F349AEDFD5F3A649B5498FFB121712BA8B448F3F2A91DBC5A766FCDDBE  EM DV TLS CA - G3B, issued by AAA Certificate Services
98B896625C0C230ADEEC3EB2CF6AAD5001ECF9156A68644E82374CE5833BC25B  EM OV TLS CA - G3B, issued by emSign Root TLS CA - G3
5F1DED4DD590AF74631290CF073B122A2AAC6A1FA479778A0BD43579BD832699  EM OV TLS CA - G3B, issued by AAA Certificate Services
E7568FE6E12331F4FD7DE61DA4C7559D0F8EB192A218D4741A3BA75184333838  EM EV TLS CA - G3B, issued by emSign Root TLS CA - G3
579480AEA166290BD3C643589E795FC0D0E54E86505D180F1DFF99EFD3199512  EM EV TLS CA - G3B, issued by AAA Certificate Services
0164D7CEAE5BB909C272AF151FF44B1177AE9B47D9424B94F1D9558C30934D19  EM DV TLS CA - G3C, issued by emSign Root TLS CA - G3
62B7F9868263F72F6911FC78CEAF72C1979158B7368BF648683BB2AA39B02E72  EM DV TLS CA - G3C, issued by AAA Certificate Services
CB6E15165AC802E9B3F993F16C25D41F4E81C21EBDE71AE1B012AC00BF9C7C3F  EM OV TLS CA - G3C, issued by emSign Root TLS CA - G3
7485B51C0ED192878FA1D2F948FB529AE1842CC5086C4B67F7BE5B2039DE9489  EM OV TLS CA - G3C, issued by AAA Certificate Services
432EC25F0D28DE9006D97BF752F17BBB2CD41F669933FCB072D9A1148D0261F3  EM EV TLS CA - G3C, issued by emSign Root TLS CA - G3
FD9D5C2DBBD4995AB69B8D50C439D9527B00529199C2FD01B2174EB58F07021F  EM EV TLS CA - G3C, issued by AAA Certificate Services
9E39DE2881273ACC225A149C72BA3E0F51424963669AB633EE1DC7DF5DB067B4  EM OV CS CA - G3B, issued by emSign Root CS CA - G3
A496E23AC0CAB8155FC9B117B97EAE368EFCBB9041AEC8804D5A308D2D01C2D8  EM OV CS CA - G3B, issued by AAA Certificate Services
4B2460A466F95FD40113BCDCCA2CEB29B3B093921DE45474DA7DF48874C630B1  EM OV CS CA - G3C, issued by emSign Root CS CA - G3
84112972B8E59D14560AE7E7119654474AAD119990CF3722BFC1E3B91615E1FD  EM OV CS CA - G3C, issued by AAA Certificate Services
'@

# Roots that anchor the compromised intermediates, from roots.json. They are removed from Ruby's CA
# bundle but not added to the Disallowed store: AAA Certificate Services also anchors legitimate
# Sectigo chains that Windows still trusts.
$rootPinTable = @'
D7A7A0FB5D7E2731D771E9484EBCDEF71D5F0C3E0A2948782BC83EE0EA699EF4  AAA Certificate Services (cross-signer of the compromised intermediates)
86A1ECBA089C4A8D3BBE2734C612BA341D813E043CF9E8A862CD5C57A36BBE6B  emSign ECC Root CA - G3 (cross-signer)
7DD78D5F4F13459A83DFF9ABBBA62EDBAF6F2D102BF257FD712F4D9F2746ED8D  emSign Root TLS CA - G3
F2EDAAFF3D9B701FB4D14C9F285F8C0BAD90FC3BCC1FA07D47F4718EDABA34A5  emSign Root CS CA - G3
'@

$pemPattern = '(?<pem>-----BEGIN CERTIFICATE-----(?<b64>[A-Za-z0-9+/=\s]+?)-----END CERTIFICATE-----)'
# An entry in a Ruby (curl/Mozilla format) CA bundle: an optional title line with a "====" underline,
# the PEM block, and the blank lines after it.
$bundleEntryPattern = '(?m)(?:^[^\r\n]*\r?\n=+[ \t]*\r?\n)?' + $pemPattern + '[ \t]*(?:\r?\n)?(?:[ \t]*\r?\n)*'

# Runs with the Ruby that fluentd uses. Arguments: intermediates PEM, removed roots PEM, CA bundle.
$rubyCheck = @'
require "openssl"

intermediates_file, removed_file, bundle_file = ARGV

def certificates(path)
  File.binread(path).scan(/-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----/m).map do |pem|
    OpenSSL::X509::Certificate.new(pem)
  end
end

# The trust that fluentd and its plugins get: OpenSSL's default CA file and directory (and default
# certificate store on OpenSSL 3). Expiry is ignored so that only trust is judged.
store = OpenSSL::X509::Store.new
store.set_default_paths
store.flags = OpenSSL::X509::V_FLAG_NO_CHECK_TIME

failures = 0
distrusted = certificates(intermediates_file) + certificates(removed_file)
distrusted.each do |cert|
  next unless store.verify(cert)
  puts "STILL TRUSTED: #{cert.subject}"
  failures += 1
end

remaining = certificates(bundle_file)
remaining.each do |cert|
  next if store.verify(cert)
  puts "NO LONGER TRUSTED: #{cert.subject} (#{store.error_string})"
  failures += 1
end

if distrusted.empty? || remaining.empty?
  puts "Nothing to check"
  failures += 1
end

puts "Checked #{distrusted.size} compromised and #{remaining.size} CA bundle certificates with " \
     "#{OpenSSL::OPENSSL_LIBRARY_VERSION}: #{failures} failures"
exit(failures.zero? ? 0 : 1)
'@

function ConvertFrom-PinTable([string]$Table) {
    $pins = @{}
    foreach ($line in ($Table -split '\r?\n')) {
        $line = $line.Trim()
        if ($line.Length -eq 0) { continue }
        $fields = $line -split '\s+', 2
        if ($fields[0] -notmatch '^[0-9A-F]{64}$') { throw "Invalid SHA-256 pin: $line" }
        $pins[$fields[0]] = $fields[1]
    }
    return $pins
}

function Get-Sha256([byte[]]$Bytes) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($sha256.ComputeHash($Bytes)).Replace('-', '')
    }
    finally {
        $sha256.Dispose()
    }
}

# Returns the regex match, DER bytes and SHA-256 of every certificate in $Text. Fails unless every
# PEM block in $Text is a certificate that matches $Pattern.
function Get-PemCertificate([string]$Text, [string]$Pattern, [string]$Path) {
    $blocks = [regex]::Matches($Text, $Pattern)
    $beginCount = [regex]::Matches($Text, '-----BEGIN ').Count
    if ($blocks.Count -eq 0 -or $blocks.Count -ne $beginCount) {
        throw "$Path has $beginCount PEM blocks, of which $($blocks.Count) could be read as certificates"
    }
    foreach ($block in $blocks) {
        $der = [System.Convert]::FromBase64String(($block.Groups['b64'].Value -replace '\s', ''))
        [pscustomobject]@{
            Match  = $block
            Der    = $der
            Sha256 = (Get-Sha256 $der)
        }
    }
}

try {
    $intermediatePins = ConvertFrom-PinTable $intermediatePinTable
    $rootPins = ConvertFrom-PinTable $rootPinTable
    $distrusted = @{}
    foreach ($pins in @($intermediatePins, $rootPins)) {
        foreach ($sha256 in $pins.Keys) { $distrusted[$sha256] = $pins[$sha256] }
    }

    if ([string]::IsNullOrEmpty($IntermediatesFile)) {
        $IntermediatesFile = Join-Path $PSScriptRoot 'emudhra-compromised-intermediates.pem'
    }
    $IntermediatesFile = (Resolve-Path -LiteralPath $IntermediatesFile).ProviderPath

    if ([string]::IsNullOrEmpty($RubyExe)) {
        $rubyCommand = Get-Command ruby.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -eq $rubyCommand) { throw 'ruby.exe was not found on PATH. Pass -RubyExe.' }
        $RubyExe = $rubyCommand.Path
    }
    $RubyExe = (Resolve-Path -LiteralPath $RubyExe).ProviderPath

    if ([string]::IsNullOrEmpty($RubyCertFile)) {
        # OpenSSL loads SSL_CERT_FILE instead of its built-in default when the variable is set.
        $RubyCertFile = (& $RubyExe -ropenssl -e "print(ENV.fetch('SSL_CERT_FILE', OpenSSL::X509::DEFAULT_CERT_FILE))" | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw "$RubyExe failed to report its CA bundle (exit code $LASTEXITCODE)" }
    }
    $RubyCertFile = (Resolve-Path -LiteralPath $RubyCertFile.Replace('/', '\')).ProviderPath

    Write-Host "Distrusting the compromised eMudhra CAs: store $StoreLocation\$StoreName, Ruby $RubyExe, CA bundle $RubyCertFile"

    # Validate all inputs before changing anything.
    $intermediates = @(Get-PemCertificate ([System.IO.File]::ReadAllText($IntermediatesFile)) $pemPattern $IntermediatesFile)
    $seen = @{}
    foreach ($certificate in $intermediates) {
        if (-not $intermediatePins.ContainsKey($certificate.Sha256)) {
            throw "$IntermediatesFile contains a certificate that is not pinned (SHA-256 $($certificate.Sha256))"
        }
        if ($seen.ContainsKey($certificate.Sha256)) {
            throw "$IntermediatesFile contains the certificate with SHA-256 $($certificate.Sha256) more than once"
        }
        $seen[$certificate.Sha256] = $true
    }
    if ($seen.Count -ne $intermediatePins.Count) {
        throw "$IntermediatesFile contains $($seen.Count) of the $($intermediatePins.Count) pinned certificates"
    }

    # Latin-1 maps every byte to one character, so the parts of the bundle that are kept are written
    # back byte for byte.
    $latin1 = [System.Text.Encoding]::GetEncoding(28591)
    $bundleText = $latin1.GetString([System.IO.File]::ReadAllBytes($RubyCertFile))
    $bundleEntries = @(Get-PemCertificate $bundleText $bundleEntryPattern $RubyCertFile)

    # 1. Windows Disallowed store
    $location = [System.Security.Cryptography.X509Certificates.StoreLocation]$StoreLocation
    $x509Certificates = @(foreach ($certificate in $intermediates) {
        [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificate.Der)
    })
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($StoreName, $location)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    try {
        foreach ($x509Certificate in $x509Certificates) { $store.Add($x509Certificate) }
    }
    finally {
        $store.Close()
    }
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($StoreName, $location)
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]'ReadOnly, OpenExistingOnly')
    try {
        foreach ($x509Certificate in $x509Certificates) {
            $found = $store.Certificates.Find([System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint, $x509Certificate.Thumbprint, $false)
            if ($found.Count -eq 0) { throw "$($x509Certificate.Subject) is missing from $StoreLocation\$StoreName after the import" }
            Write-Host "Distrusted $($x509Certificate.Subject) (thumbprint $($x509Certificate.Thumbprint)) in $StoreLocation\$StoreName"
        }
    }
    finally {
        $store.Close()
    }

    # 2. Ruby CA bundle
    $builder = New-Object System.Text.StringBuilder
    $position = 0
    $removedPems = @()
    foreach ($entry in $bundleEntries) {
        if (-not $distrusted.ContainsKey($entry.Sha256)) { continue }
        [void]$builder.Append($bundleText, $position, $entry.Match.Index - $position)
        $position = $entry.Match.Index + $entry.Match.Length
        $removedPems += $entry.Match.Groups['pem'].Value
        Write-Host "Removing $($distrusted[$entry.Sha256]) (SHA-256 $($entry.Sha256)) from $RubyCertFile"
    }
    [void]$builder.Append($bundleText, $position, $bundleText.Length - $position)
    if ($removedPems.Count -gt 0) {
        [System.IO.File]::WriteAllBytes($RubyCertFile, $latin1.GetBytes($builder.ToString()))
    }
    else {
        Write-Host "$RubyCertFile does not contain any of the distrusted certificates"
    }

    $remaining = @(Get-PemCertificate ($latin1.GetString([System.IO.File]::ReadAllBytes($RubyCertFile))) $bundleEntryPattern $RubyCertFile)
    if ($remaining.Count -ne $bundleEntries.Count - $removedPems.Count) {
        throw "$RubyCertFile has $($remaining.Count) certificates after the update, expected $($bundleEntries.Count - $removedPems.Count)"
    }
    foreach ($entry in $remaining) {
        if ($distrusted.ContainsKey($entry.Sha256)) { throw "$RubyCertFile still contains $($distrusted[$entry.Sha256])" }
    }
    Write-Host "$RubyCertFile has $($remaining.Count) certificates ($($removedPems.Count) removed)"

    # 3. Check what Ruby trusts now
    $workDir = Join-Path ([System.IO.Path]::GetTempPath()) ('distrust-compromised-cas-' + [guid]::NewGuid().ToString('N'))
    [void][System.IO.Directory]::CreateDirectory($workDir)
    try {
        $utf8 = New-Object System.Text.UTF8Encoding $false
        $checkScript = Join-Path $workDir 'check.rb'
        $removedFile = Join-Path $workDir 'removed.pem'
        [System.IO.File]::WriteAllText($checkScript, $rubyCheck, $utf8)
        [System.IO.File]::WriteAllText($removedFile, ($removedPems -join "`n"), $utf8)
        $output = & $RubyExe -W0 $checkScript $IntermediatesFile $removedFile $RubyCertFile
        $rubyExitCode = $LASTEXITCODE
        $output | ForEach-Object { Write-Host $_ }
        if ($rubyExitCode -ne 0) { throw "Ruby trust check failed (exit code $rubyExitCode)" }
    }
    finally {
        Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Host 'exception while distrusting the compromised eMudhra CAs'
    Write-Host $_
    Write-Host $_.ScriptStackTrace
    exit 1
}
Write-Host 'Finished distrusting the compromised eMudhra CAs'
exit 0
