param(
    [Parameter( Position=0,
                mandatory=$true,
                HelpMessage="Path of the MonAgentLauncher.exe to check if it is running as expected.")] 
    [string]$monAgentLauncherExePath,

    [Parameter( Position=1,
                mandatory=$true,
                HelpMessage="Relative path of filesystemwatcher.txt to check if it exists.")] 
    [string]$fileSystemWatcherTextFilePath
)

$SUCCESS=0
$FILESYSTEM_WATCHER_FILE_EXISTS=1
$NO_MONAGENT_LAUNCHER_PROCESS=2

if (Test-Path -Path $fileSystemWatcherTextFilePath -PathType Leaf) 
{
    Write-Error "INFO: File: $fileSystemWatcherTextFilePath exists indicates Config Map Updated since agent started."
    exit $FILESYSTEM_WATCHER_FILE_EXISTS
}

$Env:HOSTLOGS_MA_STARTED | Out-File livenessprobe.log

if($Env:HOSTLOGS_MA_STARTED -eq "true")
{
    $monAgentLauncherExePath.replace('\','\\')
    
    if(-not (Get-CimInstance Win32_Process -Filter "ExecutablePath LIKE '%$monAgentLauncherExePath'"))
    {
        Write-Error "ERROR: Process not running: $monAgentLauncherExePath"
        exit $NO_MONAGENT_LAUNCHER_PROCESS
    }
}

exit $SUCCESS