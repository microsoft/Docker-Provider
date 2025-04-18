# Simple PowerShell script to analyze DLL dependencies in Windows Nano Server
# This is a lightweight approach that doesn't rely on external tools

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
        $dlls = @{
        }
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

function Analyze-Dependencies {
    param (
        [string]$ExecutablePath
    )

    Write-Host "Analyzing dependencies for: $ExecutablePath"
    
    if (!(Test-Path $ExecutablePath)) {
        Write-Error "File not found: $ExecutablePath"
        return
    }
    
    # Try to get basic file info
    try {
        $fileInfo = Get-Item $ExecutablePath
        Write-Host "File size: $($fileInfo.Length) bytes"
        Write-Host "Last modified: $($fileInfo.LastWriteTime)"
    } catch {
        Write-Warning "Could not get file information: $_"
    }
    
    # Get imports using our custom function
    try {
        Write-Host "Extracting DLL dependencies from the executable..."
        $imports = Get-PEFileImports -FilePath $ExecutablePath
        
        if ($imports.Count -gt 0) {
            Write-Host "Found the following potential DLL dependencies:"
            $systemDllsPaths = @{}
            $missingDlls = @{}
            
            foreach ($dll in $imports) {
                # Check if the DLL exists in various paths
                $system32Path = "C:\Windows\System32\$dll"
                $localPath = Join-Path -Path (Split-Path -Path $ExecutablePath -Parent) -ChildPath $dll
                
                if (Test-Path $system32Path) {
                    $systemDllsPaths[$dll] = $system32Path
                    Write-Host "  [FOUND IN SYSTEM32] $dll"
                } elseif (Test-Path $localPath) {
                    Write-Host "  [FOUND LOCALLY] $dll"
                } else {
                    $missingDlls[$dll] = $true
                    Write-Host "  [MISSING] $dll"
                }
            }
            
            if ($missingDlls.Count -gt 0) {
                Write-Host "`nThe following DLLs are referenced but not found in System32 or locally:"
                $missingDlls.Keys | ForEach-Object { Write-Host "  - $_" }
                Write-Host "These missing DLLs might need to be copied from Windows Server Core."
            }
        } else {
            Write-Host "No DLL dependencies found in the executable."
        }
    } catch {
        Write-Warning "Failed to extract imports: $_"
    }
    
    # Define list of common Visual C++ and UCRT dependencies
    $commonDlls = @(
        # Visual C++ Runtime DLLs
        "msvcp140.dll",
        "vcruntime140.dll",
        "vccorlib140.dll",
        "vcruntime140_1.dll",
        "msvcp140_1.dll",
        "concrt140.dll",
        # Universal CRT DLLs
        "ucrtbase.dll",
        # Common API MS Win CRT DLLs
        "api-ms-win-crt-runtime-l1-1-0.dll",
        "api-ms-win-crt-string-l1-1-0.dll",
        "api-ms-win-crt-stdio-l1-1-0.dll",
        "api-ms-win-crt-heap-l1-1-0.dll",
        "api-ms-win-crt-convert-l1-1-0.dll",
        "api-ms-win-crt-math-l1-1-0.dll",
        "api-ms-win-crt-locale-l1-1-0.dll",
        "api-ms-win-crt-time-l1-1-0.dll",
        "api-ms-win-crt-filesystem-l1-1-0.dll",
        "api-ms-win-crt-environment-l1-1-0.dll",
        "api-ms-win-crt-process-l1-1-0.dll",
        "api-ms-win-crt-utility-l1-1-0.dll"
    )
    
    # Check what exists in Windows Nano Server
    Write-Host "`n======= WINDOWS NANO SERVER ANALYSIS ======="
    Write-Host "Checking what's available in Windows Nano Server base image..."
    
    $system32Path = "C:\Windows\System32"
    $availableSystemDlls = @{}
    
    # Check if System32 exists (it should)
    if (Test-Path $system32Path) {
        # Get all DLLs in System32
        $systemDlls = Get-ChildItem -Path $system32Path -Filter "*.dll" -ErrorAction SilentlyContinue
        $systemDllCount = $systemDlls.Count
        Write-Host "Found $systemDllCount total DLLs in C:\Windows\System32"
        
        # Store available DLLs in a lookup table
        foreach ($dll in $systemDlls) {
            $availableSystemDlls[$dll.Name.ToLower()] = $dll.FullName
        }
        
        # Check for common VC++ Runtime DLLs
        Write-Host "`nChecking for Visual C++ Runtime DLLs in Windows Nano Server:"
        $vcppDlls = $commonDlls | Where-Object { $_ -like "msvc*" -or $_ -like "vcruntime*" -or $_ -like "vccorlib*" -or $_ -like "concrt*" }
        foreach ($dll in $vcppDlls) {
            $lowercase = $dll.ToLower()
            if ($availableSystemDlls.ContainsKey($lowercase)) {
                Write-Host "  [AVAILABLE] $dll"
            } else {
                Write-Host "  [MISSING] $dll"
            }
        }
        
        # Check for Universal CRT (UCRT) base DLL
        Write-Host "`nChecking for Universal CRT base DLLs:"
        $ucrtDlls = $commonDlls | Where-Object { $_ -like "ucrt*" }
        foreach ($dll in $ucrtDlls) {
            $lowercase = $dll.ToLower()
            if ($availableSystemDlls.ContainsKey($lowercase)) {
                Write-Host "  [AVAILABLE] $dll"
            } else {
                Write-Host "  [MISSING] $dll"
            }
        }
        
        # Check for API-MS-WIN-CRT DLLs
        Write-Host "`nChecking for API-MS-WIN-CRT DLLs:"
        $apiCrtDlls = $commonDlls | Where-Object { $_ -like "api-ms-win-crt*" }
        foreach ($dll in $apiCrtDlls) {
            $lowercase = $dll.ToLower()
            if ($availableSystemDlls.ContainsKey($lowercase)) {
                Write-Host "  [AVAILABLE] $dll"
            } else {
                Write-Host "  [MISSING] $dll"
            }
        }
        
        # Check for any other API-MS-WIN-CRT DLLs not in our common list
        $otherApiCrtDlls = $systemDlls | Where-Object { $_.Name -like "api-ms-win-crt*" -and $_.Name -notIn $apiCrtDlls }
        if ($otherApiCrtDlls.Count -gt 0) {
            Write-Host "`nOther API-MS-WIN-CRT DLLs available in Windows Nano Server:"
            foreach ($dll in $otherApiCrtDlls) {
                Write-Host "  [AVAILABLE] $($dll.Name)"
            }
        }
    } else {
        Write-Warning "C:\Windows\System32 directory not found. This is unexpected."
    }
    
    # Check for common Visual C++ Runtime DLLs in the application directory
    $directory = Split-Path -Path $ExecutablePath -Parent
    Write-Host "`nChecking for common VC++ Runtime DLLs in the application directory ($directory):"
    foreach ($dll in $commonDlls) {
        $path = Join-Path -Path $directory -ChildPath $dll
        if (Test-Path $path) {
            Write-Host "  [FOUND] $dll"
        } else {
            Write-Host "  [MISSING] $dll"
        }
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
    
    # Generate recommendations
    Write-Host "`n======= RECOMMENDATIONS ======="
    Write-Host "Based on the analysis, the following DLLs should be copied from Windows Server Core to the Fluent Bit bin directory:"
    
    $recommendedDlls = @()
    foreach ($dll in $commonDlls) {
        $lowercase = $dll.ToLower()
        $localPath = Join-Path -Path $directory -ChildPath $dll
        
        if (-not (Test-Path $localPath) -and -not $availableSystemDlls.ContainsKey($lowercase)) {
            $recommendedDlls += $dll
        }
    }
    
    if ($recommendedDlls.Count -gt 0) {
        foreach ($dll in $recommendedDlls) {
            Write-Host "- $dll"
        }
        
        Write-Host "`nDockerfile RUN commands to add these DLLs:"
        Write-Host "```"
        foreach ($dll in $recommendedDlls) {
            Write-Host "RUN Copy-Item -Path `$env:windir\System32\$dll -Destination C:\vcruntime -ErrorAction SilentlyContinue"
        }
        Write-Host "```"
        
        Write-Host "`nDockerfile COPY commands:"
        Write-Host "```"
        foreach ($dll in $recommendedDlls) {
            Write-Host "COPY --from=dll-extractor C:/vcruntime/$dll C:/opt/fluent-bit/bin/"
        }
        Write-Host "```"
    } else {
        Write-Host "No additional DLLs need to be copied."
    }
}

# Example usage
if ($args.Count -eq 0) {
    Write-Host "Usage: analyze-dependencies.ps1 <path-to-executable>"
    Write-Host "Example: analyze-dependencies.ps1 C:\opt\fluent-bit\bin\fluent-bit.exe"
} else {
    Analyze-Dependencies -ExecutablePath $args[0]
}