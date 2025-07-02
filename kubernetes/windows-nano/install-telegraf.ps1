# Speed up Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

Write-Host ('Installing Telegraf for Windows Nano Server')

try {
    Write-Host ('Creating folder structure for Telegraf')
    New-Item -Type Directory -Path C:\installation -ErrorAction SilentlyContinue
    New-Item -Type Directory -Path C:\opt\telegraf -ErrorAction SilentlyContinue
    New-Item -Type Directory -Path C:\opt\telegraf\bin -ErrorAction SilentlyContinue
    New-Item -Type Directory -Path C:\etc\telegraf -ErrorAction SilentlyContinue

    Write-Host ('Downloading Telegraf')
    # Using same version as Windows Server Core version for compatibility
    $telegrafUri = 'https://dl.influxdata.com/telegraf/releases/telegraf-1.24.2_windows_amd64.zip'
    Invoke-WebRequest -Uri $telegrafUri -OutFile C:\installation\telegraf.zip
    
    Write-Host ('Extracting Telegraf')
    Expand-Archive -Path C:\installation\telegraf.zip -Destination C:\installation\telegraf
    
    # Find the telegraf.exe file and copy it to bin directory
    $telegrafExe = Get-ChildItem -Path C:\installation\telegraf -Recurse -Filter "telegraf.exe" | Select-Object -First 1 -ExpandProperty FullName
    
    if ($telegrafExe) {
        Write-Host "Found telegraf.exe at: $telegrafExe"
        Copy-Item -Path $telegrafExe -Destination C:\opt\telegraf\bin\ -Force
        Write-Host "Copied telegraf.exe to C:\opt\telegraf\bin\"
        
        # Copy any additional files from the telegraf directory
        $telegrafDir = Split-Path -Path $telegrafExe -Parent
        Copy-Item -Path "$telegrafDir\*" -Destination C:\opt\telegraf\ -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Copied Telegraf files to C:\opt\telegraf\"
    } else {
        Write-Error "Could not find telegraf.exe in the extracted files"
        exit 1
    }
    
    Write-Host ('Cleaning up installation files')
    Remove-Item -Path C:\installation\telegraf.zip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path C:\installation\telegraf -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    $e = $_.Exception
    Write-Host "Exception when installing Telegraf:"
    Write-Host $e
    exit 1
}

Write-Host ('Finished Installing Telegraf')
