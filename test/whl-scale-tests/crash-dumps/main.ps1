<#
.SYNOPSIS
Generate Crash Dumps
.DESCRIPTION
Uses Azure watson's hugedump exe to generate crash dumps. Requires the following Env vars are set:
* CRASHD_NUM_CRASHES - Number of crash dumps to generate
* CRASHD_ALLOC_STRATEGY - Strategy to use for memory allocation. Options are:
      va : allocate using VirtualAlloc
      ha : allocate using HeapAlloc
      sa : allocate on threads' stacks
* CRASHD_ALLOC_TOTAL_SIZE: Total number of GB to allocate before crashing
* CRASHD_ALLOC_PORTION_SIZE: Allocation portion size in KB
#>

Set-Location $PSScriptRoot

function Get-Timestamp{
  return (Get-Date).ToString("[MM/dd/yy hh:mm:ss.ffff]")
}

# Validate env vars are set
$numCrashes = $env:CRASHD_NUM_CRASHES;
$strategy = $env:CRASHD_ALLOC_STRATEGY;
$totalSize = $env:CRASHD_ALLOC_TOTAL_SIZE;
$portionSize = $env:CRASHD_ALLOC_PORTION_SIZE;
if(
  [string]::IsNullOrEmpty($numCrashes) -or 
  [string]::IsNullOrEmpty($strategy) -or 
  [string]::IsNullOrEmpty($totalSize ) -or 
  [string]::IsNullOrEmpty($portionSize)
){
  Throw [System.ArgumentNullException]"All of the following env vars must be set: CRASHD_NUM_CRASHES, CRASHD_ALLOC_STRATEGY, CRASHD_ALLOC_TOTAL_SIZE, CRASHD_ALLOC_PORTION_SIZE";
  exit 1;
}

Write-Host "Unziping crash dump generator package";
Expand-Archive ".\crashdumpgenerator.zip";

# Generate Crash dumps
for($i = 0; $i -lt $numCrashes; $i++){
  Write-Host "$(Get-Timestamp) Generating crash dump $($i+1)"
  Start-Process ".\crashdumpgenerator\lib\native\hugedump.exe" -ArgumentList "$strategy $totalSize $portionSize" -NoNewWindow -PassThru -Wait
}
Write-Host "$(Get-Timestamp) Crash dump generation completed"

# Execute Notepad.exe to keep container alive to prevent crash loop
Notepad.exe | Out-Null
