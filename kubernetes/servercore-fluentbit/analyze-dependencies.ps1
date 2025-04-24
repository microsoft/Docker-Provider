param(
    [Parameter(Mandatory=$true)]
    [string]$ExecutablePath
)

function Get-PEFileImports {
    param (
        [string]$FilePath
    )
    
    try {
        # Read the binary file
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        
        # Parse PE header to find imports (simplified approach)
        # This is a basic implementation that looks for DLL names in the binary
        $content = [System.Text.Encoding]::ASCII.GetString($bytes)
        
        # Look for strings ending in .dll in the binary (simplistic but often effective)
        $dllPattern = "([a-zA-Z0-9_-]+\.dll)"
        $matches = [regex]::Matches($content, $dllPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        
        # Create a hashtable to track unique DLLs
        $dlls = @{}
        foreach ($match in $matches) {
            $dllName = $match.Groups[1].Value
            if (-not $dlls.ContainsKey($dllName)) {
                $dlls[$dllName] = $true
            }
        }
        
        return $dlls.Keys
    }
    catch {
        Write-Warning "Error analyzing file imports: $_"
        return @()
    }
}

Write-Host "Analyzing dependencies for: $ExecutablePath"

# Check if the file exists
if (-not (Test-Path $ExecutablePath)) {
    Write-Host "ERROR: The executable file does not exist at path: $ExecutablePath"
    exit 1
}

# Use Get-Item to check basic file info
$fileInfo = Get-Item $ExecutablePath
Write-Host "File Information:"
Write-Host "Name: $($fileInfo.Name)"
Write-Host "Size: $($fileInfo.Length) bytes"
Write-Host "Last Modified: $($fileInfo.LastWriteTime)"
Write-Host "Created: $($fileInfo.CreationTime)"

# Extract DLL dependencies using our custom function
Write-Host "Extracting DLL dependencies from the executable..."
$imports = Get-PEFileImports -FilePath $ExecutablePath

if ($imports.Count -gt 0) {
    Write-Host "Found the following potential DLL dependencies:"
    $systemDllsPaths = @{}
    $missingDlls = @{}
    
    foreach ($dll in $imports) {
        # Check if the DLL exists in various paths
        $system32Path = "C:\Windows\System32\$dll"
        $sysWOW64Path = "C:\Windows\SysWOW64\$dll"
        $localPath = Join-Path -Path (Split-Path -Path $ExecutablePath -Parent) -ChildPath $dll
        
        if (Test-Path $system32Path) {
            $systemDllsPaths[$dll] = $system32Path
            Write-Host "  [FOUND IN SYSTEM32] $dll"
        } elseif (Test-Path $sysWOW64Path) {
            $systemDllsPaths[$dll] = $sysWOW64Path
            Write-Host "  [FOUND IN SYSWOW64] $dll"
        } elseif (Test-Path $localPath) {
            Write-Host "  [FOUND LOCALLY] $dll"
        } else {
            $missingDlls[$dll] = $true
            Write-Host "  [MISSING] $dll"
        }
    }
    
    if ($missingDlls.Count -gt 0) {
        Write-Host "`nThe following DLLs are referenced but not found in System32, SysWOW64, or locally:"
        $missingDlls.Keys | ForEach-Object { Write-Host "  - $_" }
    }
} else {
    Write-Host "No DLL dependencies found in the executable."
}

# Check if process can be started
Write-Host "`nAttempting to start the process with no arguments to check for immediate errors..."
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

# Try to examine the error via LoadLibrary
Write-Host "`nAttempting to load the executable to identify specific missing dependencies..."
$code = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class DllCheck {
    [DllImport("kernel32.dll")]
    static extern IntPtr LoadLibrary(string lpFileName);

    [DllImport("kernel32.dll")]
    static extern bool FreeLibrary(IntPtr hModule);

    [DllImport("kernel32.dll")]
    static extern uint GetLastError();

    public static uint TryLoadLibrary(string path) {
        IntPtr handle = LoadLibrary(path);
        if (handle == IntPtr.Zero) {
            return GetLastError();
        }
        FreeLibrary(handle);
        return 0;
    }
}
"@

try {
    Add-Type -TypeDefinition $code -Language CSharp
    $errorCode = [DllCheck]::TryLoadLibrary($ExecutablePath)
    if ($errorCode -ne 0) {
        Write-Host "Failed to load the executable. Error code: $errorCode (0x$($errorCode.ToString('X')))"
        # 0x7e = 126 = ERROR_MOD_NOT_FOUND - The specified module could not be found
        if ($errorCode -eq 126) {
            Write-Host "Error indicates a missing dependency DLL."
        }
    } else {
        Write-Host "Successfully loaded the executable."
    }
} catch {
    Write-Warning "Error attempting to load library: $_"
}

Write-Host "`nAnalysis complete."