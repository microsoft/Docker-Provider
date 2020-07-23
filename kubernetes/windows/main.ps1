function Confirm-WindowsServiceExists($name)
{
    if (Get-Service $name -ErrorAction SilentlyContinue)
    {
        return $true
    }
    return $false
}

function Remove-WindowsServiceIfItExists($name)
{
    $exists = Confirm-WindowsServiceExists $name
    if ($exists)
    {
        sc.exe \\server delete $name
    }
}

function Start-FileSystemWatcher
{
    Start-Process powershell -NoNewWindow .\filesystemwatcher.ps1
}

#register fluentd as a windows service

function Set-EnvironmentVariables
{
    $domain = "opinsights.azure.com"
    if (Test-Path /etc/omsagent-secret/DOMAIN) {
        # TODO: Change to omsagent-secret before merging
        $domain =  Get-Content /etc/omsagent-secret/DOMAIN
    }

    # Set DOMAIN
    [System.Environment]::SetEnvironmentVariable("DOMAIN", $domain, "Process")
    [System.Environment]::SetEnvironmentVariable("DOMAIN", $domain, "Machine")

    $wsID = ""
    if (Test-Path /etc/omsagent-secret/WSID) {
        # TODO: Change to omsagent-secret before merging
        $wsID =  Get-Content /etc/omsagent-secret/WSID
    }

    # Set DOMAIN
    [System.Environment]::SetEnvironmentVariable("WSID", $wsID, "Process")
    [System.Environment]::SetEnvironmentVariable("WSID", $wsID, "Machine")

    $wsKey = ""
    if (Test-Path /etc/omsagent-secret/KEY) {
        # TODO: Change to omsagent-secret before merging
        $wsKey =  Get-Content /etc/omsagent-secret/KEY
    }

    # Set KEY
    [System.Environment]::SetEnvironmentVariable("WSKEY", $wsKey, "Process")
    [System.Environment]::SetEnvironmentVariable("WSKEY", $wsKey, "Machine")

    $proxy = ""
    if (Test-Path /etc/omsagent-secret/PROXY) {
        # TODO: Change to omsagent-secret before merging
        $proxy =  Get-Content /etc/omsagent-secret/PROXY
        Write-Host "Validating the proxy configuration since proxy configuration provided"
        # valide the proxy endpoint configuration
        if (![string]::IsNullOrEmpty($proxy)) {
            $proxy = [string]$proxy.Trim();
            if (![string]::IsNullOrEmpty($proxy)) {
                $proxy = [string]$proxy.Trim();
                $parts = $proxy -split "@"
                if ($parts.Length -ne 2)
                {
                    Write-Host "Invalid ProxyConfiguration $($proxy). EXITING....."
                    exit 1
                }
                $subparts1 = $parts[0] -split "//"
                if ($subparts1.Length -ne 2)
                {
                    Write-Host "Invalid ProxyConfiguration $($proxy). EXITING....."
                    exit 1
                }
                $protocol = $subparts1[0].ToLower().TrimEnd(":")
                if (!($protocol -eq "http") -and !($protocol -eq "https"))
                {
                    Write-Host "Unsupported protocol in ProxyConfiguration $($proxy). EXITING....."
                    exit 1
                }
                $subparts2 = $parts[1] -split ":"
                if ($subparts2.Length -ne 2)
                {
                    Write-Host "Invalid ProxyConfiguration $($proxy). EXITING....."
                    exit 1
                }
            }
        }
        Write-Host "Provided Proxy configuration is valid"
    }

    # Set PROXY
    [System.Environment]::SetEnvironmentVariable("PROXY", $proxy, "Process")
    [System.Environment]::SetEnvironmentVariable("PROXY", $proxy, "Machine")
    #set agent config schema version
    $schemaVersionFile = '/etc/config/settings/schema-version'
    if (Test-Path $schemaVersionFile) {
        $schemaVersion = Get-Content $schemaVersionFile | ForEach-Object { $_.TrimEnd() }
        if ($schemaVersion.GetType().Name -eq 'String') {
            [System.Environment]::SetEnvironmentVariable("AZMON_AGENT_CFG_SCHEMA_VERSION", $schemaVersion, "Process")
            [System.Environment]::SetEnvironmentVariable("AZMON_AGENT_CFG_SCHEMA_VERSION", $schemaVersion, "Machine")
        }
        $env:AZMON_AGENT_CFG_SCHEMA_VERSION
    }

    # Set environment variable for TELEMETRY_APPLICATIONINSIGHTS_KEY
    $aiKey = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($env:APPLICATIONINSIGHTS_AUTH))
    [System.Environment]::SetEnvironmentVariable("TELEMETRY_APPLICATIONINSIGHTS_KEY", $aiKey, "Process")
    [System.Environment]::SetEnvironmentVariable("TELEMETRY_APPLICATIONINSIGHTS_KEY", $aiKey, "Machine")

    # run config parser
    ruby /opt/omsagentwindows/scripts/ruby/tomlparser.rb
    .\setenv.ps1
}

function Start-Fluent
{
    # Run fluent-bit service first so that we do not miss any logs being forwarded by the fluentd service.
    # Run fluent-bit as a background job. Switch this to a windows service once fluent-bit supports natively running as a windows service
    Start-Job -ScriptBlock { Start-Process -NoNewWindow -FilePath "C:\opt\fluent-bit\bin\fluent-bit.exe" -ArgumentList @("-c", "C:\etc\fluent-bit\fluent-bit.conf", "-e", "C:\opt\omsagentwindows\out_oms.so") }

    #register fluentd as a service and start
    # there is a known issues with win32-service https://github.com/chef/win32-service/issues/70
    fluentd --reg-winsvc i --reg-winsvc-auto-start --winsvc-name fluentdwinaks --reg-winsvc-fluentdopt '-c C:/etc/fluent/fluent.conf -o C:/etc/fluent/fluent.log'

    Notepad.exe | Out-Null
}

function Generate-Certificates
{
    Write-Host "Generating Certificates"
    C:\\opt\\omsagentwindows\\certgenerator\\certificategenerator.exe
}

function Test-CertificatePath
{
    $certLocation = $env:CI_CERT_LOCATION
    $keyLocation =  $env:CI_KEY_LOCATION
    if  (!(Test-Path $certLocation))
    {
        Write-Host "Certificate file not found at $($certLocation). EXITING....."
        exit 1
    }
    else
    {
        Write-Host "Certificate file found at $($certLocation)"
    }

    if (! (Test-Path $keyLocation))
    {
        Write-Host "Key file not found at $($keyLocation). EXITING...."
        exit 1
    }
    else
    {
        Write-Host "Key file found at $($keyLocation)"
    }
}

Start-Transcript -Path main.txt

Remove-WindowsServiceIfItExists "fluentdwinaks"
Set-EnvironmentVariables
Start-FileSystemWatcher
Generate-Certificates
Test-CertificatePath
Start-Fluent

# List all powershell processes running. This should have main.ps1 and filesystemwatcher.ps1
Get-WmiObject Win32_process | Where-Object {$_.Name -match 'powershell'} | Format-Table -Property Name, CommandLine, ProcessId

#check if fluentd service is running
Get-Service fluentdwinaks




