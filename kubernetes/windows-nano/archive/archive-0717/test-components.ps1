# Test script to verify component installations
Write-Host "Testing component installations in Windows Nano Server..."

# Test Fluent Bit installation
Write-Host "`nTesting Fluent Bit:"
if (Test-Path "C:\opt\fluent-bit\bin\fluent-bit.exe") {
    Write-Host "✓ Fluent Bit executable found"
    try {
        $fluentBitVersion = & "C:\opt\fluent-bit\bin\fluent-bit.exe" --version
        Write-Host "✓ Fluent Bit version: $fluentBitVersion"
    }
    catch {
        Write-Host "⚠ Fluent Bit executable found but version check failed: $($_.Exception.Message)"
    }
} else {
    Write-Host "✗ Fluent Bit executable not found"
}

# Test Telegraf installation
Write-Host "`nTesting Telegraf:"
if (Test-Path "C:\opt\telegraf\bin\telegraf.exe") {
    Write-Host "✓ Telegraf executable found"
    try {
        $telegrafVersion = & "C:\opt\telegraf\bin\telegraf.exe" --version
        Write-Host "✓ Telegraf version: $telegrafVersion"
    }
    catch {
        Write-Host "⚠ Telegraf executable found but version check failed: $($_.Exception.Message)"
    }
} else {
    Write-Host "✗ Telegraf executable not found"
}

# Test Windows Azure Monitor Agent installation
Write-Host "`nTesting Windows Azure Monitor Agent:"
$amaLauncherPath = "C:\opt\windowsazuremonitoragent\windowsazuremonitoragent\Monitoring\Agent\MonAgentLauncher.exe"
if (Test-Path $amaLauncherPath) {
    Write-Host "✓ Windows AMA launcher found"
    try {
        $amaCorePath = "C:\opt\windowsazuremonitoragent\windowsazuremonitoragent\Monitoring\Agent\MonAgentCore.exe"
        if (Test-Path $amaCorePath) {
            $amaVersion = (Get-Item $amaCorePath).VersionInfo.ProductVersion
            if (![string]::IsNullOrEmpty($amaVersion)) {
                Write-Host "✓ Windows AMA version: $amaVersion"
            } else {
                Write-Host "⚠ Windows AMA core found but version not available"
            }
        } else {
            Write-Host "⚠ Windows AMA launcher found but core executable missing"
        }
    }
    catch {
        Write-Host "⚠ Windows AMA found but version check failed: $($_.Exception.Message)"
    }
} else {
    Write-Host "⚠ Windows AMA not found (this is expected if installation failed during build)"
}

# Test configuration files
Write-Host "`nTesting configuration files:"
if (Test-Path "C:\etc\telegraf\telegraf.conf") {
    Write-Host "✓ Telegraf configuration found"
} else {
    Write-Host "✗ Telegraf configuration not found"
}

# Test directory structure
Write-Host "`nTesting directory structure:"
$requiredDirs = @(
    "C:\opt\fluent-bit",
    "C:\opt\telegraf", 
    "C:\opt\windowsazuremonitoragent",
    "C:\etc\telegraf"
)

foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Host "✓ Directory exists: $dir"
    } else {
        Write-Host "✗ Directory missing: $dir"
    }
}

Write-Host "`nComponent testing completed."
