$ErrorActionPreference = 'Stop'

function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length
    )
    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789{-)}$^%(_!#'.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
 
    $rng.GetBytes($bytes)
 
    $result = New-Object char[]($length)
 
    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i]%$charSet.Length]
    }
 
    return (-join $result).ToString()
}


function SubstituteNameValuePairs {
    param(
        [string][Parameter(Mandatory=$true)] $InputFilePath,
        [string][Parameter(Mandatory=$true)] $OutputFilePath,
        [hashtable][Parameter(Mandatory=$true)] $Substitutions
    )

    # Ensure the input file exists
    if (-not (Test-Path -Path $InputFilePath)) {
        Write-Host "  Input File: '$InputFilePath' does not exist" -ForegroundColor Red
        exit
    }

    foreach($subItem in $Substitutions.GetEnumerator())
    {
        (Get-Content $InputFilePath).Replace($subItem.Name, $subItem.Value) | Set-Content $OutputFilePath
    }
}