<# 
.SYNOPSIS
Generate Event Tracing for Windows (ETW) events
.DESCRIPTION
Uses a list of ETW providers to create events with the provided event Ids. Requires the following environment variable is set:
* ETW_EVENTS_NUM - Number of ETW events to generate
#>

Set-Location $PSScriptRoot

class EtwProvider {
    [string]$ProviderName
    [Int32]$Id
    [byte]$Version
    [Object[]]$Payload

    EtwProvider (
        [string]$ProviderName,
        [Int32]$Id,
        [byte]$Version,
        [Object[]]$Payload
    ) {
        $this.ProviderName = $ProviderName
        $this.Id = $Id
        $this.Version = $Version
        $this.Payload = $Payload
    }
}

$etwProviders = @(
    [EtwProvider]::new("Microsoft-Windows-AppId", 4007, 0, @(1)),
    [EtwProvider]::new("Microsoft-Windows-AppLocker", 8026, 0, @()),
    [EtwProvider]::new("Microsoft-Windows-AppLocker", 8027, 0, @()),
    [EtwProvider]::new("Microsoft-Windows-AppLocker", 8036, 0, @($true, "ac69843f-f0ba-4140-b20c-b38e3f11c628")),
    [EtwProvider]::new("Microsoft-Windows-AppModel-Runtime", 217, 0, @("PackageName", "ContainerIds")),
    [EtwProvider]::new("Microsoft-Windows-AppModel-Runtime", 53, 0, @("PackageFullName")),
    [EtwProvider]::new("Microsoft-Windows-AppModel-Runtime", 54, 0, @("PackageFullName")),
    [EtwProvider]::new("Microsoft-Windows-AppModel-Runtime", 55, 0, @("PackageFullName")),
    [EtwProvider]::new("Microsoft-Windows-AppModel-Runtime", 56, 0, @("PackageFullName")),
    [EtwProvider]::new("Microsoft-Windows-AppReadiness", 5047, 0, @("User")),
    [EtwProvider]::new("Microsoft-Windows-AppReadiness", 5046, 0, @("User")),
    [EtwProvider]::new("Microsoft-Windows-AppReadiness", 5045, 0, @("User", 1))  
)

# read this value from env var
$etwCount = [int]$env:ETW_EVENTS_NUM

if ([string]::IsNullOrWhiteSpace($etwCount)) {
    throw "ETW_EVENTS_NUM env variable must be set with the number of ETW events to generate" 
} elseif ($etwCount -le 0) {
    throw "ETW_EVENTS_NUM env variable must be greater than 0"
}

Write-Host "START: Generating ETW events"

for ($i = 0; $i -lt $etwProviders.Count; $i++) {    
    New-WinEvent -ProviderName $etwProviders[$i].ProviderName `
        -Id $etwProviders[$i].Id `
        -Version $etwProviders[$i].Version `
        -Payload @($etwProviders[$i].Payload)

    Write-Host "ETW Event from Provider: $($etwProviders[$i].ProviderName) with Id: $($etwProviders[$i].Id) generated"
    $etwCount--
    Write-Host "Remaining ETW events to generate = $etwCount"

    # Check if all events were generated
    if ($etwCount -eq 0) {
        Break
    }
    # If we reached the end of the provider list, start over 
    elseif ($i + 1 -eq $($etwProviders.Count) ) {
        $i = -1
    }
    else {
        continue
    }
}

Write-Host "END: Generating ETW events"
Write-Host "Number of ETW events generated: $env:ETW_EVENTS_NUM)"

# Execute Notepad.exe to keep container alive to prevent crash loop
Notepad.exe | Out-Null