Start-Transcript -Path fileSystemWatcherTranscript.txt
Write-Host "Removing Existing Event Subscribers"
Get-EventSubscriber -Force | ForEach-Object { $_.SubscriptionId } | ForEach-Object { Unregister-Event -SubscriptionId $_ }
Write-Host "Starting File System Watcher for config map updates"

$Paths = @(".\etc\config\settings")

foreach ($path in $Paths)
{
    $FileSystemWatcher = New-Object System.IO.FileSystemWatcher
    $FileSystemWatcher.Path = $path
    $FileSystemWatcher.IncludeSubdirectories = $true
    $EventName = 'Changed', 'Created', 'Deleted', 'Renamed'

    $Action = {
        $fileSystemWatcherStatusPath = ".\etc\hostlogswindows\filesystemwatcher.txt"
        $fileSystemWatcherLog = "{0} was  {1} at {2}" -f $Event.SourceEventArgs.FullPath,
        $Event.SourceEventArgs.ChangeType,
        $Event.TimeGenerated
        Write-Host $fileSystemWatcherLog
        Add-Content -Path $fileSystemWatcherStatusPath -Value $fileSystemWatcherLog
    }

    $ObjectEventParams = @{
        InputObject = $FileSystemWatcher
        Action      = $Action
    }

    ForEach ($Item in $EventName) {
        $ObjectEventParams.EventName = $Item
        $name = Split-Path -Path $path -Leaf
        $ObjectEventParams.SourceIdentifier = "$($name).$($Item)"
        Write-Host  "Starting watcher for Event: $($path).$($Item)"
        $Null = Register-ObjectEvent  @ObjectEventParams
    }
}

# keep this running for the container's lifetime, so that it can listen for changes to the config map mount path
try
{
    do
    {
        Wait-Event -Timeout 60
    } while ($true)
}
finally
{
    Get-EventSubscriber -Force | ForEach-Object { $_.SubscriptionId } | ForEach-Object { Unregister-Event -SubscriptionId $_ }
    Write-Host "Event Handler disabled."
}