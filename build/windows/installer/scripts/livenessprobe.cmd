REM "Checking if fluent-bit is running"

tasklist /fi "imagename eq fluent-bit.exe" /fo "table"  | findstr fluent-bit

IF ERRORLEVEL 1 (
    echo "Fluent-Bit is not running"
    exit /b 1
)

REM "Checking if config map has been updated since agent start"

IF EXIST C:\etc\omsagentwindows\filesystemwatcher.txt (
    echo "Config Map Updated since agent started"
    exit /b  1
)

REM "Checking if certificate needs to be renewed (aka agent restart required)"

IF EXIST C:\etc\omsagentwindows\renewcertificate.txt (
    echo "Certificate needs to be renewed"
    exit /b  1
)

REM "Checking if fluentd service is running"
sc query fluentdwinaks | findstr /i STATE | findstr RUNNING

IF ERRORLEVEL 1 (
    echo "Fluentd Service is NOT Running"
    exit /b  1
)

exit /b 0




