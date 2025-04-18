# Speed up Invoke-WebRequest
$ProgressPreference = 'SilentlyContinue'

Write-Host ('Creating folder structure')
New-Item -Type Directory -Path C:\installation -ErrorAction SilentlyContinue

# Create minimal required directory structure
New-Item -Type Directory -Path C:\opt\fluent-bit -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\etc\fluent-bit -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\opt\amalogswindows\state -ErrorAction SilentlyContinue
New-Item -Type Directory -Path C:\opt\amalogswindows\state\ContainerInventory -ErrorAction SilentlyContinue

Write-Host ('Installing Fluent Bit')
try {
    $fluentBitUri='https://fluentbit.io/releases/3.0/fluent-bit-3.0.6-win64.zip'
    Invoke-WebRequest -Uri $fluentBitUri -OutFile C:\installation\fluent-bit.zip
    Expand-Archive -Path C:\installation\fluent-bit.zip -Destination C:\installation\fluent-bit
    Move-Item -Path C:\installation\fluent-bit\*\* -Destination C:\opt\fluent-bit\ -ErrorAction SilentlyContinue
}
catch {
    $e = $_.Exception
    Write-Host "Exception when installing Fluent Bit:"
    Write-Host $e
    exit 1
}
Write-Host ('Finished Installing Fluentbit')

# Copy required DLLs for Fluent Bit from the base Windows image
# Note: In a multi-stage build, we'd copy these from a Server Core image
# For this POC, we're assuming the DLLs are provided separately

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