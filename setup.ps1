# setup.ps1 — Bootstrap del laboratorio en Windows nativo (PowerShell).
# Para macOS/Linux/WSL: usa setup.sh.

$ErrorActionPreference = "Continue"

function Write-Step($msg) { Write-Host ""; Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "  ·    $msg" -ForegroundColor Blue }
function Write-Warn($msg) { Write-Host "  !    $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  X    $msg" -ForegroundColor Red }

function Abort($msg) {
  Write-Host ""
  Write-Fail $msg
  Write-Host ""
  Write-Host "Si no sabes cómo arreglarlo, ejecuta:" -ForegroundColor Yellow
  Write-Host "    .\doctor.ps1" -ForegroundColor White
  Write-Host "y comparte la salida con tu profesor."
  exit 1
}

Set-Location $PSScriptRoot

Write-Host ""
Write-Host "================================================" -ForegroundColor White
Write-Host "  ANBAN · Setup del laboratorio MLOps/DataOps" -ForegroundColor White
Write-Host "================================================" -ForegroundColor White

# ----- 1. Docker -----
Write-Step "1. Comprobando Docker"
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
  Abort "Docker no está instalado o no está en el PATH. Instálalo desde https://www.docker.com/products/docker-desktop/"
}
$dockerVersion = & docker --version
Write-Ok "Docker encontrado: $dockerVersion"

& docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Abort "Docker está instalado pero no responde. Abre Docker Desktop y espera a que la ballena se quede fija (no animada)."
}
Write-Ok "El motor de Docker está activo"

& docker compose version 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Abort "No se encuentra 'docker compose' v2. Actualiza Docker Desktop."
}
Write-Ok "Docker Compose disponible"

# ----- 2. Descarga de imágenes -----
Write-Step "2. Descargando las imágenes del curso"
Write-Info "Es normal que la primera vez tarde 5-10 minutos."

$images = @(
  "postgres:16-alpine",
  "minio/minio:RELEASE.2024-10-13T13-34-11Z",
  "minio/mc:RELEASE.2024-10-08T09-37-26Z",
  "ghcr.io/mlflow/mlflow:v2.17.2",
  "jupyter/scipy-notebook:python-3.11"
)

function Pull-WithRetry($image) {
  for ($i = 1; $i -le 3; $i++) {
    & docker pull $image 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { return $true }
    Write-Warn "Intento $i/3 fallo para $image. Reintentando en 5s..."
    Start-Sleep -Seconds 5
  }
  return $false
}

foreach ($img in $images) {
  Write-Info "Descargando $img"
  if (-not (Pull-WithRetry $img)) {
    Abort "No he podido descargar $img tras 3 intentos. Revisa conexión y proxies."
  }
  Write-Ok $img
}

# ----- 3. Compose up -----
Write-Step "3. Levantando los servicios"
Set-Location docker
& docker compose up -d
$composeExit = $LASTEXITCODE
Set-Location ..
if ($composeExit -ne 0) {
  Abort "Fallo al lanzar docker compose. Mira el mensaje anterior."
}
Write-Ok "docker compose up -d lanzado"

# ----- 4. Espera HTTP -----
Write-Step "4. Esperando a que los servicios estén listos"

function Wait-Http($name, $url, $timeout = 120) {
  $start = Get-Date
  while (((Get-Date) - $start).TotalSeconds -lt $timeout) {
    try {
      $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
      Write-Ok "$name listo"
      return $true
    } catch {
      Start-Sleep -Seconds 3
    }
  }
  return $false
}

if (-not (Wait-Http "MinIO API" "http://localhost:9000/minio/health/live")) {
  Write-Warn "MinIO no respondió a tiempo, dale 1-2 minutos más."
}
if (-not (Wait-Http "MLflow" "http://localhost:5050")) {
  Write-Warn "MLflow no respondió a tiempo, dale 1-2 minutos más."
}
if (-not (Wait-Http "Jupyter" "http://localhost:8888")) {
  Write-Warn "Jupyter no respondió a tiempo, dale 1 minuto más."
}

# ----- 5. Resumen -----
Write-Host ""
Write-Host "================================================" -ForegroundColor White
Write-Host "  LISTO. Abre estos enlaces en tu navegador:" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor White
Write-Host ""
Write-Host "  Jupyter   : http://localhost:8888   (token: anban)"
Write-Host "  MLflow    : http://localhost:5050"
Write-Host "  MinIO UI  : http://localhost:9001   (minio / minio12345)"
Write-Host ""
Write-Host "  Para hacer el Lab 1, ejecuta:"
Write-Host "      cd labs\lab1_dataops" -ForegroundColor White
Write-Host "      .\run.ps1" -ForegroundColor White
Write-Host ""
