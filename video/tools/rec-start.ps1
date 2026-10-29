# Inicia la grabacion de una escena en segundo plano.  rec-start.ps1 s03-terraform
param([string] $Name)
& "$PSScriptRoot\focus-chrome.ps1" -Match 'Chrome' | Out-Null
$out = "D:\EF-DGITI-Final\video\raw\$Name.mp4"
Start-Process -WindowStyle Hidden -FilePath 'D:\EF-DGITI-Final\.venv\Scripts\python.exe' -ArgumentList "`"$PSScriptRoot\rec.py`" `"$out`""
Start-Sleep -Milliseconds 1500
Write-Host "grabando $Name"
