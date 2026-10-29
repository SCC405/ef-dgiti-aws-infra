# Despliega toda la infraestructura con Terraform y guarda cada salida en salidas\.
#   powershell -ExecutionPolicy Bypass -File scripts\deploy.ps1
# Tarda unos 15-20 minutos (la réplica de RDS es lo más lento).

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_terraform.ps1"

$raiz    = Split-Path $PSScriptRoot -Parent
$infra   = Join-Path $raiz 'infra'
$salidas = Join-Path $raiz 'salidas'
New-Item -ItemType Directory -Force $salidas | Out-Null

Push-Location $infra
try {
    if (-not (Test-Path 'terraform.tfvars')) {
        Copy-Item 'terraform.tfvars.example' 'terraform.tfvars'
    }

    & $tf version          | Tee-Object "$salidas\00-version.txt"
    & $tf init -input=false -no-color | Tee-Object "$salidas\01-init.txt"
    if ($LASTEXITCODE) { throw 'terraform init fallo' }

    & $tf validate -no-color | Tee-Object "$salidas\02-validate.txt"
    & $tf plan -input=false -no-color -out=tfplan | Tee-Object "$salidas\03-plan.txt"
    if ($LASTEXITCODE) { throw 'terraform plan fallo' }

    & $tf apply -input=false -no-color tfplan | Tee-Object "$salidas\04-apply.txt"
    if ($LASTEXITCODE) { throw 'terraform apply fallo' }

    & $tf output -no-color | Tee-Object "$salidas\05-output.txt"
} finally {
    Pop-Location
}

Write-Host "`nListo. Las instancias tardan ~5 minutos en instalar Docker y pasar el health check." -ForegroundColor Green
