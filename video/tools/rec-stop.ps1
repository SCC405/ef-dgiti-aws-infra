# Detiene la grabacion de una escena.  rec-stop.ps1 s03-terraform
param([string] $Name)
$out = "D:\EF-DGITI-Final\video\raw\$Name.mp4"
New-Item -ItemType File -Force "$out.stop" | Out-Null
for ($i = 0; $i -lt 40 -and (Test-Path "$out.stop"); $i++) { Start-Sleep -Milliseconds 250 }
Write-Host ("{0}: {1:N1} MB" -f $Name, ((Get-Item $out).Length / 1MB))
