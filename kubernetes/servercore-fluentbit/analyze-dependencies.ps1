param(
    [Parameter(Mandatory=$true)]
    [string]$ExecutablePath
)

Write-Host "Analyzing dependencies for: $ExecutablePath"

# Check if the file exists
if (-not (Test-Path $ExecutablePath)) {
    Write-Host "ERROR: The executable file does not exist at path: $ExecutablePath"
    exit 1
}

# Check if DUMPBIN is available (part of Visual Studio/Build Tools)
$dumpbin = $null
$possibleDumpbinPaths = @(
    "C:\Program Files (x86)\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe",
    "C:\Program Files\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\Hostx64\x64\dumpbin.exe"
)

foreach ($path in $possibleDumpbinPaths) {
    $dumpbinFound = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Sort-Object -Property FullName -Descending | Select-Object -First 1
    if ($dumpbinFound) {
        $dumpbin = $dumpbinFound.FullName
        break
    }
}

# Use Get-Item to check basic file info
$fileInfo = Get-Item $ExecutablePath
Write-Host "File Information:"
Write-Host "Name: $($fileInfo.Name)"
Write-Host "Size: $($fileInfo.Length) bytes"
Write-Host "Last Modified: $($fileInfo.LastWriteTime)"
Write-Host "Created: $($fileInfo.CreationTime)"

# Check if we have access to dumpbin
if ($dumpbin -and (Test-Path $dumpbin)) {
    Write-Host "Found DUMPBIN at: $dumpbin"
    Write-Host "Analyzing dependencies with DUMPBIN..."
    
    try {
        # Use dumpbin to list dependencies
        $dependencyOutput = & $dumpbin /DEPENDENTS $ExecutablePath
        Write-Host "Dependencies:"
        $dependencyOutput | Where-Object { $_ -like "*dll*" } | Write-Host
    }
    catch {
        Write-Host "Error running DUMPBIN: $_"
    }
}
else {
    Write-Host "DUMPBIN not available. Using alternative method to check dependencies."
    
    # Alternative method using PowerShell's Add-Type
    try {
        Add-Type -AssemblyName System.Reflection
        $assembly = [System.Reflection.Assembly]::LoadFile($ExecutablePath)
        
        Write-Host "Referenced Assemblies:"
        $assembly.GetReferencedAssemblies() | Format-Table Name, Version
    }
    catch {
        Write-Host "Could not load assembly for reflection: $_"
    }
}

# Check if process can be started
Write-Host "Attempting to start the process with no arguments to check for immediate errors..."
try {
    # Start the process and immediately stop it
    $process = Start-Process -FilePath $ExecutablePath -ArgumentList "--help" -NoNewWindow -PassThru
    Start-Sleep -Seconds 2
    
    if (-not $process.HasExited) {
        Write-Host "Process started successfully and is still running."
        $process | Stop-Process -Force
    }
    else {
        Write-Host "Process exited with code: $($process.ExitCode)"
    }
}
catch {
    Write-Host "Failed to start process: $_"
}

# Check for common Windows DLLs that might be missing
$commonDlls = @(
    "MSVCR120.dll",
    "MSVCP120.dll",
    "MSVCR140.dll",
    "MSVCP140.dll",
    "VCRUNTIME140.dll",
    "VCRUNTIME140_1.dll",
    "ucrtbase.dll"
)

Write-Host "Checking for common required DLLs in system directories..."
$systemDirs = @(
    "$env:windir\System32",
    "$env:windir\SysWOW64"
)

foreach ($dll in $commonDlls) {
    $found = $false
    
    foreach ($dir in $systemDirs) {
        $path = Join-Path $dir $dll
        if (Test-Path $path) {
            $found = $true
            Write-Host "$dll found at: $path"
            break
        }
    }
    
    if (-not $found) {
        Write-Host "WARNING: $dll not found in system directories."
    }
}

Write-Host "Analysis complete."