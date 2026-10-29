# Envía N solicitudes a /status y cuenta qué instancia respondió cada una.
# Evidencia directa de que el ALB reparte el tráfico entre las EC2 de las dos zonas.
#
#   powershell -ExecutionPolicy Bypass -File load-tests\balance-check.ps1 -Url http://<alb_dns_name> -N 30

param(
    [Parameter(Mandatory)] [string] $Url,
    [int] $N = 30
)

$Url = $Url.TrimEnd('/')
$respuestas = @()
$fallos = 0

for ($i = 1; $i -le $N; $i++) {
    try {
        $r = Invoke-RestMethod "$Url/status" -TimeoutSec 5
        $respuestas += [pscustomobject]@{ instancia = $r.instance_id; zona = $r.availability_zone; version = $r.version }
        Write-Host ("{0,3}  {1}  {2}  v{3}" -f $i, $r.instance_id, $r.availability_zone, $r.version)
    } catch {
        $fallos++
        Write-Host ("{0,3}  ERROR: {1}" -f $i, $_.Exception.Message) -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 200
}

Write-Host "`nReparto de solicitudes por instancia:" -ForegroundColor Cyan
$respuestas | Group-Object instancia, zona |
    Sort-Object Count -Descending |
    Format-Table @{ n = 'Instancia / Zona'; e = { $_.Name } }, @{ n = 'Solicitudes'; e = { $_.Count } },
                 @{ n = '%'; e = { [math]::Round($_.Count * 100 / $N, 1) } } -AutoSize

Write-Host "Fallos: $fallos de $N"
