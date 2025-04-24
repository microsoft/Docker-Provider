# Speed up Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

Write-Host ('Creating folder structure')
New-Item -Type Directory -Path C:\installation -ErrorAction SilentlyContinue

# Create minimal required directory structure
New-Item -Type Directory -Path C:\opt\fluent-bit -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\opt\fluent-bit\bin -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\etc\fluent-bit -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\opt\amalogswindows\state -ErrorAction SilentlyContinue

Write-Host ('Installing Fluent Bit')
try {
    $fluentBitUri='https://fluentbit.io/releases/3.0/fluent-bit-3.0.6-win64.zip'
    Invoke-WebRequest -Uri $fluentBitUri -OutFile C:\installation\fluent-bit.zip
    Expand-Archive -Path C:\installation\fluent-bit.zip -Destination C:\installation\fluent-bit
    
    # Find the extracted directory that contains fluent-bit.exe
    $fluentBitExePath = Get-ChildItem -Path C:\installation\fluent-bit -Filter "fluent-bit.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName
    if ($fluentBitExePath) {
        $fluentBitExeDir = Split-Path -Path $fluentBitExePath -Parent
        Write-Host "Found Fluent Bit executable in: $fluentBitExeDir"
        
        # Copy all files from the bin directory - Server Core can support more dependencies directly
        Copy-Item -Path "$fluentBitExeDir\*" -Destination C:\opt\fluent-bit\bin\ -Recurse -Force -Verbose
        
        # List what we've copied to bin directory
        Write-Host "Copied files to bin directory:"
        Get-ChildItem -Path C:\opt\fluent-bit\bin | Format-Table Name, Length
    } else {
        Write-Host "Error: fluent-bit.exe not found in extracted files"
        exit 1
    }
    
    # Move all other files to the main fluent-bit directory
    Move-Item -Path C:\installation\fluent-bit\*\* -Destination C:\opt\fluent-bit\ -ErrorAction SilentlyContinue
}
catch {
    $e = $_.Exception
    Write-Host "Exception when installing Fluent Bit:"
    Write-Host $e
    exit 1
}
Write-Host ('Finished Installing Fluentbit')

Write-Host ('Creating minimal fluent-bit.conf')
@"
[SERVICE]
    Flush        1
    Daemon       Off
    Log_Level    info
    Parsers_File parsers.conf

# Generate test messages every second
[INPUT]
    Name         dummy
    Tag          dummy.log
    Dummy        {"message": "This is a test message from Fluent Bit", "timestamp": "\${TIMESTAMP}"}
    Samples      1
    Rate         1

# Also monitor the system logs
[INPUT]
    Name         winlog
    Tag          windows.system
    Channels     System,Application
    Interval_Sec 5

# Format the output to be more visible
[OUTPUT]
    Name         stdout
    Match        *
    Format       json_lines

# Also write to a log file for persistence
[OUTPUT]
    Name         file
    Match        *
    Path         C:/opt/amalogswindows/state/fluent-bit.log
"@ | Set-Content -Path C:\etc\fluent-bit\fluent-bit.conf

# Create parsers.conf file
@"
[PARSER]
    Name   json
    Format json
    Time_Key time
    Time_Format %d/%b/%Y:%H:%M:%S %z

[PARSER]
    Name   syslog
    Format regex
    Regex  ^\<(?<pri>[0-9]+)\>(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?(?:[^\:]*\:)? *(?<message>.*)$
    Time_Key time
    Time_Format %b %d %H:%M:%S
"@ | Set-Content -Path C:\etc\fluent-bit\parsers.conf

Write-Host ('Removing installation directory')
Remove-Item C:\installation -Recurse -ErrorAction SilentlyContinue

Write-Host ('Setup completed successfully')