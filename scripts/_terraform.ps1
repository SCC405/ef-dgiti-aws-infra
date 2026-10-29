# Localiza terraform.exe: primero el del PATH, luego la copia de D:\DESCARGAS.
# Uso:  . "$PSScriptRoot\_terraform.ps1"   y después   & $tf <args>

$tf = $null
$enPath = Get-Command terraform -ErrorAction SilentlyContinue
if ($enPath) {
    $tf = $enPath.Source
} else {
    foreach ($c in @(
        'D:\DESCARGAS\terraform_1.16.5_windows_amd64\terraform.exe',
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\terraform.exe"
    )) {
        if (Test-Path $c) { $tf = $c; break }
    }
}
if (-not $tf) {
    Write-Host 'No se encontro terraform.exe. Instalar con: winget install --id HashiCorp.Terraform -e' -ForegroundColor Red
    exit 1
}

$credenciales = Join-Path $env:USERPROFILE '.aws\credentials'
if (-not (Test-Path $credenciales)) {
    Write-Host "Falta $credenciales. En AWS Academy: AWS Details -> AWS CLI -> Show, y pegar los tres valores." -ForegroundColor Red
    exit 1
}
