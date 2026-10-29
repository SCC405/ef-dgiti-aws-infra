# Copia las credenciales temporales de AWS Academy (~/.aws/credentials) a los
# GitHub Secrets del repositorio, sin mostrarlas en pantalla.
# Repetir cada vez que se reinicia el laboratorio (las credenciales caducan).
#
#   powershell -ExecutionPolicy Bypass -File scripts\set-github-secrets.ps1

$ErrorActionPreference = 'Stop'
$repo = 'SCC405/ef-dgiti-aws-infra'
$archivo = Join-Path $env:USERPROFILE '.aws\credentials'

$valores = @{}
foreach ($linea in Get-Content $archivo) {
    if ($linea -match '^\s*(aws_access_key_id|aws_secret_access_key|aws_session_token)\s*=\s*(.+?)\s*$') {
        $valores[$Matches[1]] = $Matches[2]
    }
}

$mapa = @{
    aws_access_key_id     = 'AWS_ACCESS_KEY_ID'
    aws_secret_access_key = 'AWS_SECRET_ACCESS_KEY'
    aws_session_token     = 'AWS_SESSION_TOKEN'
}

foreach ($k in $mapa.Keys) {
    if (-not $valores[$k]) { throw "No se encontro $k en $archivo" }
    $valores[$k] | gh secret set $mapa[$k] --repo $repo --env aws-academy
    Write-Host "Secreto $($mapa[$k]) actualizado" -ForegroundColor Green
}
