# Speed up Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

Write-Host ('Creating folder structure')
New-Item -Type Directory -Path C:\installation -ErrorAction SilentlyContinue

# Create minimal required directory structure
New-Item -Type Directory -Path C:\opt\fluent-bit -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\opt\fluent-bit\bin -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\etc\fluent-bit -ErrorAction SilentlyContinue

Write-Host ('Installing Fluent Bit')
try {
    #$fluentBitUri='https://fluentbit.io/releases/3.0/fluent-bit-3.0.6-win64.zip'
    $fluentBitUri='https://packages.fluentbit.io/windows/fluent-bit-4.0.1-win64.zip'
    Invoke-WebRequest -Uri $fluentBitUri -OutFile C:\installation\fluent-bit.zip
    Expand-Archive -Path C:\installation\fluent-bit.zip -Destination C:\installation\fluent-bit
    
    # Find the fluent-bit.exe file and copy it to bin directory
    $fluentBitExe = Get-ChildItem -Path C:\installation\fluent-bit -Recurse -Filter "fluent-bit.exe" | Select-Object -First 1 -ExpandProperty FullName
    
    if ($fluentBitExe) {
        Write-Host "Found fluent-bit.exe at: $fluentBitExe"
        Copy-Item -Path $fluentBitExe -Destination C:\opt\fluent-bit\bin\ -Force
        Write-Host "Copied fluent-bit.exe to C:\opt\fluent-bit\bin\"
        
        # Copy required DLLs to bin directory as well
        $fluentBitDir = Split-Path -Path $fluentBitExe -Parent
        Copy-Item -Path "$fluentBitDir\*.dll" -Destination C:\opt\fluent-bit\bin\ -Force
        Write-Host "Copied DLL files to C:\opt\fluent-bit\bin\"
    } else {
        Write-Error "Could not find fluent-bit.exe in the extracted files"
        exit 1
    }
    
    # Move other files to main fluent-bit directory
    Move-Item -Path C:\installation\fluent-bit\*\* -Destination C:\opt\fluent-bit\ -ErrorAction SilentlyContinue
}
catch {
    $e = $_.Exception
    Write-Host "Exception when installing Fluent Bit:"
    Write-Host $e
    exit 1
}
Write-Host ('Finished Installing Fluentbit')