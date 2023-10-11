<#
.SYNOPSIS
Generate Event Logs
.DESCRIPTION
Generates Event Logs for scale testing. Requires the following Env vars are set:
* EVTLOGS_JOB_COUNT: Number of event log generation jobs to run in parallel
* EVTLOGS_LOG_COUNT: Number of event logs to generate per job
* EVTLOGS_DELAY: Time to wait between writing each event
#>

Set-Location $PSScriptRoot

$LOG_NAME = "WHLScaleTest"
$LOG_SOURCE = "WHLScaleTestSource"
$LOG_LEVEL = "Information"

$JobCount = $env:EVTLOGS_JOB_COUNT
$LogCount = $env:EVTLOGS_LOG_COUNT
$Delay = $env:EVTLOGS_DELAY

if (
  [string]::IsNullOrWhiteSpace($JobCount) -or 
  [string]::IsNullOrWhiteSpace($LogCount) -or 
  [string]::IsNullOrWhiteSpace($Delay)
) {
  Throw "All of the following env vars must be set: 
  EVTLOGS_JOB_COUNT, 
  EVTLOGS_LOG_COUNT,
  EVTLOGS_DELAY"
  exit 1
}

Remove-EventLog -LogName $LOG_NAME 2> $null # Cleanup from previous runs
New-EventLog -LogName $LOG_NAME -Source $LOG_SOURCE

# Script block to execute in job
$writeEventLogs_sb = {
  param (
    [Parameter(Mandatory)][int]$LogCount,
    [Parameter(Mandatory)][int]$EventId,
    [Parameter(Mandatory)][int]$Delay
  )
  function Get-Timestamp {
    return (Get-Date).ToString("[MM/dd/yy hh:mm:ss.ffff]")
  }

  for ($i = 0; $i -lt $LogCount; $i ++) {
    Write-EventLog `
      -LogName "$using:LOG_NAME" `
      -Source $using:LOG_SOURCE `
      -EntryType $using:LOG_LEVEL `
      -EventId $EventId `
      -Message "$(Get-Timestamp) Test event $($i + 1)"
    Start-Sleep -Milliseconds $Delay
  }
}

$jobs = New-Object object[] $jobCount
for ($jobNum = 0; $jobNum -lt $JobCount; $jobNum++) {
  $jobName = "EventLogGenerator_$jobNum"
  Write-Host "Spawning job $jobName"
  $jobs[$jobNum] = Start-Job -ScriptBlock $writeEventLogs_sb -ArgumentList @($LogCount, $jobNum, $Delay) -Name $jobName
}
# Wait for all jobs to finish
$jobs | Wait-Job | Format-Table -Property Id, Name, State, PSBeginTime, PSEndTime
foreach ($job in $jobs) {
  Receive-Job $jobs # Output job logs
}
Write-Host "Done Generating Event Logs."

# Execute Notepad.exe to keep container alive to prevent crash loop
Notepad.exe | Out-Null