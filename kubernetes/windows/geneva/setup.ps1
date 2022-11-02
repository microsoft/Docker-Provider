$ProgressPreference = 'SilentlyContinue'

Write-Host ('Creating folder structure')
  New-Item -Type Directory -Path /installation -ErrorAction SilentlyContinue
  New-Item -Type Directory -Path /opt/genevamonitoringagent
  New-Item -Type Directory -Path /opt/genevamonitoringagent/datadirectory

Write-Host ('Installing GenevaMonitoringAgent');
  try {
    $genevamonitoringagentUri='https://github.com/microsoft/Docker-Provider/releases/download/windows-ama-bits/genevamonitoringagent.45.13.1.zip'
    Invoke-WebRequest -Uri $genevamonitoringagentUri -OutFile /installation/genevamonitoringagent.zip
    Expand-Archive -Path /installation/genevamonitoringagent.zip -Destination /installation/genevamonitoringagent
    Move-Item -Path /installation/genevamonitoringagent -Destination /opt/genevamonitoringagent/ -ErrorAction SilentlyContinue
  }
  catch {
    $ex = $_.Exception
    Write-Host "exception while downloading genevamonitoringagent for windows"
    Write-Host $ex
    exit 1
  }
Write-Host ('Finished downloading GenevaMonitoringAgent')   