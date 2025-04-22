# Speed up Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

Write-Host ('Creating folder structure')
New-Item -Type Directory -Path C:\installation -ErrorAction SilentlyContinue

# Create minimal required directory structure
New-Item -Type Directory -Path C:\opt\fluent-bit -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\opt\fluent-bit\bin -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\etc\fluent-bit -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\opt\amalogswindows\state -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\opt\amalogswindows\state\ContainerInventory -ErrorAction SilentlyContinue

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
        
        # Copy just the executable to the bin directory
        Copy-Item -Path $fluentBitExePath -Destination C:\opt\fluent-bit\bin\ -Verbose
        
        # Note: Only the three basic DLLs (msvcp140.dll, vcruntime140.dll, vccorlib140.dll)
        # are copied directly from the dll-extractor stage in the Dockerfile
        
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

[INPUT]
    Name         dummy
    Tag          dummy.log

[OUTPUT]
    Name         stdout
    Match        *
"@ | Set-Content -Path C:\etc\fluent-bit\fluent-bit.conf

Write-Host ('Removing installation directory')
Remove-Item C:\installation -Recurse -ErrorAction SilentlyContinue

Write-Host ('Setup completed successfully')