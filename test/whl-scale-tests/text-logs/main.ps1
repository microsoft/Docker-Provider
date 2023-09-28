<#
.SYNOPSIS
Generate example text log files
.DESCRIPTION
Requires the following env vars are set
* TXTLOGS_LOG_DIRECTORY: File path where logs should be stored
* TXTLOGS_FILE_NAME_PREFIX: Prefix for new log files
* TXTLOGS_FILE_COUNT: Number of distinct files to generate in parallel
* TXTLOGS_LINE_COUNT: Number of lines to write per file before rotation
* TXTLOGS_ROTATION_COUNT: Number of times to rotate each file
* TXTLOGS_ROTATION_STRATEGY: What strategy to use for file rotation. Options:
    - RenameReplace - Rename original file and recreate file with the original name
    - NewFile - Create a new file with a different name
    - Overwrite - Overwrite the original file. Note this option is likely to result in lost log lines
#>

function Get-TimestampForFilename{
  return (Get-Date).ToString("yyyy-MM-dd_hh_mm_ss")
}

function RotateFile(){
  param (
    [Parameter(Mandatory)] [string]  $FileNamePrefix,
    [Parameter(Mandatory)] [string]  $LogDirectory,
    [Parameter(Mandatory)] [string]  $RotationStrategy
  )

  $newFile = ""

  Switch ($RotationStrategy)
  {
    "RenameReplace" {
      $newFile = "$FileNamePrefix.log"
      $oldFile = "$(Get-TimestampForFilename)-$FileNamePrefix.log"
      $newFilePath = Join-Path $LogDirectory $NewFile
      $oldFilePath = Join-Path $LogDirectory $OldFile

      if((Test-Path $newFilePath)){
        Move-Item $newFilePath $oldFilePath | Out-Null #Rename
      }
      New-Item $newFilePath -type file | Out-Null #Replace
    }
    "NewFile" {
      $newFile = "$FileNamePrefix-$(Get-TimestampForFilename).log"
      $NewFilePath = Join-Path $LogDirectory $NewFile
      New-Item $newFilePath -type file | Out-Null # New File
    }
    "Overwrite" {
      $newFile = "$FileNamePrefix.log"
      $NewFilePath = Join-Path $LogDirectory $NewFile
      Write-Output $null > $newFilePath # Overwrite
    }
    default {
      Write-Error "Unknown rotation type: $RotationType. Accepted options are RenameReplace, NewFile, or Overwrite"
    }
  }

  return $newFile
}

# Get env vars
$LogDirectory     = $env:TXTLOGS_LOG_DIRECTORY
$FileNamePrefix   = $env:TXTLOGS_FILE_NAME_PREFIX
$FileCount        = $env:TXTLOGS_FILE_COUNT
$LineCount        = $env:TXTLOGS_LINE_COUNT
$RotationCount    = $env:TXTLOGS_ROTATION_COUNT
$RotationStrategy = $env:TXTLOGS_ROTATION_STRATEGY

if(
  [string]::IsNullOrWhiteSpace($LogDirectory) -or 
  [string]::IsNullOrWhiteSpace($FileNamePrefix) -or 
  [string]::IsNullOrWhiteSpace($FileCount) -or 
  [string]::IsNullOrWhiteSpace($LineCount) -or 
  [string]::IsNullOrWhiteSpace($RotationCount) -or 
  [string]::IsNullOrWhiteSpace($RotationStrategy)
){
  Throw "All of the following env vars must be set: 
  TXTLOGS_LOG_DIRECTORY, 
  TXTLOGS_FILE_NAME_PREFIX, 
  TXTLOGS_FILE_COUNT, 
  TXTLOGS_LINE_COUNT,
  TXTLOGS_ROTATION_COUNT,
  TXTLOGS_ROTATION_STRATEGY"
  exit 1
}

if (!(Test-Path $LogDirectory)) {
  New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
}

# Script block to execute in job
$writeLogFile_sb = {
  param (
    [Parameter(Mandatory)]  [string]  $FilePath,
    [Parameter(Mandatory)]  [int]     $LineCount
  )
  for ($i = 0; $i -lt $LineCount; $i++) {
    "[$(Get-Date)] Example log line $i" | Out-File -FilePath $FilePath -Append
  }
}

for ($RotationNum = 0; $RotationNum -lt $RotationCount; $RotationNum++) {
  # Create separate jobs for writing each file
  $jobs = New-Object object[] $FileCount

  for($FileNum = 0; $FileNum -lt $FileCount; $FileNum++){
    $File = RotateFile "$FileNamePrefix$FileNum" $LogDirectory $RotationStrategy
    $FilePath = Join-Path $LogDirectory $File
    $jobName = "TextLogGenerator_$FileNum-$RotationNum"
    Write-Host "Spawning job $jobName to write logs to $FilePath"

    $jobs[$FileNum] = Start-Job -ScriptBlock $writeLogFile_sb -ArgumentList @($FilePath, $LineCount) -Name $jobName 
  }

  Write-Host "Writing Log Files..."

  # Wait for all files to finish writing and print out result before rotation
  $jobs | Wait-Job | Format-Table -Property Id, Name, State, PSBeginTime, PSEndTime
}

# Execute Notepad.exe to keep container alive to prevent crash loop
Notepad.exe | Out-Null