# Elimina toda la infraestructura (al terminar la sustentación, para no gastar créditos).
#   powershell -ExecutionPolicy Bypass -File scripts\destroy.ps1

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_terraform.ps1"

$raiz = Split-Path $PSScriptRoot -Parent
Push-Location (Join-Path $raiz 'infra')
try {
    & $tf destroy -auto-approve -no-color | Tee-Object (Join-Path $raiz 'salidas\99-destroy.txt')
} finally {
    Pop-Location
}
