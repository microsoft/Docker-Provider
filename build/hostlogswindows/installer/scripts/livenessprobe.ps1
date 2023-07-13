param(
    [Parameter( Position=0,
                mandatory=$true,
                HelpMessage="Path of the exeutable you want to check if it is running. Be sure to provide '\\' when entering the path.")] 
    [string]$exeRelativePath,

    [Parameter( Position=1,
                mandatory=$true,
                HelpMessage="Relative path of the file you want to check if it exists.")] 
    [string]$fileName
)

if (-Not (Test-Path -Path $fileName -PathType Leaf)) 
{
    Write-Error "File $fileName does not exist"
}

if(-not (Get-WmiObject Win32_Process -Filter "ExecutablePath LIKE '%$exeRelativePath'"))
{
    Write-Error "Process not running: $exeFullPath"
}