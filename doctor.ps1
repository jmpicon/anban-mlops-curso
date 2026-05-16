# doctor.ps1 — Diagnostico del laboratorio en Windows nativo.

function Write-Step($msg) { Write-Host ""; Write-Host "- $msg -" -ForegroundColor White }
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "  ·    $msg" -ForegroundColor Blue }
function Write-Warn($msg) { Write-Host "  !    $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  X    $msg" -ForegroundColor Red }
function Write-Fix($msg)  { Write-Host "       arreglo: $msg" -ForegroundColor Yellow }

Set-Location $PSScriptRoot
$problems = 0

Write-Host ""
Write-Host "================================================" -ForegroundColor White
Write-Host "  Diagnostico del laboratorio ANBAN" -ForegroundColor White
Write-Host "================================================" -ForegroundColor White

# ---------- Sistema ----------
Write-Step "Sistema"
Write-Info "Sistema operativo: Windows $([System.Environment]::OSVersion.Version)"

# ---------- Docker ----------
Write-Step "Docker instalado"
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if ($dockerCmd) {
  $v = & docker --version
  Write-Ok "docker encontrado: $v"
} else {
  Write-Fail "docker no encontrado en el PATH"
  Write-Fix "instala Docker Desktop desde https://www.docker.com/products/docker-desktop/"
  $problems++
}

Write-Step "Motor de Docker activo"
& docker info 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
  Write-Ok "el motor responde"
} else {
  Write-Fail "docker esta instalado pero no responde"
  Write-Fix "abre Docker Desktop y espera a que la ballena se quede fija"
  $problems++
}

Write-Step "Docker Compose v2"
& docker compose version 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
  Write-Ok "docker compose disponible"
} else {
  Write-Fail "no se encuentra 'docker compose'"
  Write-Fix "actualiza Docker Desktop"
  $problems++
}

# ---------- Registries ----------
Write-Step "Acceso a registries (Docker Hub, GHCR)"
function Test-Url($url) {
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    return $true
  } catch {
    # 401 cuenta como respondio
    if ($_.Exception.Response.StatusCode.value__ -ge 100) { return $true }
    return $false
  }
}
if (Test-Url "https://registry-1.docker.io/v2/") {
  Write-Ok "Docker Hub accesible"
} else {
  Write-Fail "no llego a Docker Hub"
  Write-Fix "comprueba conexion a internet o proxy de empresa"
  $problems++
}
if (Test-Url "https://ghcr.io") {
  Write-Ok "GHCR accesible"
} else {
  Write-Fail "no llego a ghcr.io"
  Write-Fix "tu red bloquea ghcr.io; pide a IT que abra *.ghcr.io"
  $problems++
}

# ---------- Puertos ----------
Write-Step "Puertos del laboratorio"
$ports = @(5050, 5432, 8888, 9000, 9001)

function Get-DockerPortMap {
  $blob = & docker ps --format '{{.Ports}}' 2>$null
  $maps = @()
  if ($blob) {
    foreach ($line in $blob) {
      foreach ($entry in ($line -split ',')) {
        if ($entry -match ':([0-9]+)(-([0-9]+))?->') {
          $start = [int]$Matches[1]
          $end = if ($Matches[3]) { [int]$Matches[3] } else { $start }
          $maps += ,@($start, $end)
        }
      }
    }
  }
  return $maps
}
$portMap = Get-DockerPortMap

function Is-PortInDocker($p, $map) {
  foreach ($range in $map) { if ($p -ge $range[0] -and $p -le $range[1]) { return $true } }
  return $false
}

foreach ($p in $ports) {
  $listening = Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue
  if ($listening) {
    if (Is-PortInDocker $p $portMap) {
      Write-Ok "puerto $p ocupado por un contenedor del curso"
    } else {
      Write-Warn "puerto $p ocupado por otro proceso"
      Write-Fix "cierra la aplicacion que lo usa o cambia el puerto en docker-compose.yml"
      $problems++
    }
  } else {
    Write-Ok "puerto $p libre"
  }
}

# ---------- Contenedores ----------
Write-Step "Contenedores del curso"
$containers = @("anban-postgres", "anban-minio", "anban-mlflow", "anban-jupyter")
foreach ($c in $containers) {
  $status = (& docker ps -a --filter "name=^$c$" --format '{{.Status}}' 2>$null) -join ""
  if (-not $status) {
    Write-Fail "$c no existe"
    Write-Fix "ejecuta: .\setup.ps1"
    $problems++
  } elseif ($status -match '^Up') {
    Write-Ok "$c arriba ($status)"
  } else {
    Write-Warn "$c existe pero NO esta arriba ($status)"
    Write-Fix "ejecuta: cd docker; docker compose up -d"
    $problems++
  }
}
$status = (& docker ps -a --filter "name=^anban-minio-init$" --format '{{.Status}}' 2>$null) -join ""
if ($status -match 'Exited \(0\)') {
  Write-Ok "anban-minio-init termino correctamente"
}

# ---------- HTTP ----------
Write-Step "Servicios HTTP"
$urls = @{
  "Jupyter"   = "http://localhost:8888"
  "MLflow"    = "http://localhost:5050"
  "MinIO API" = "http://localhost:9000/minio/health/live"
  "MinIO UI"  = "http://localhost:9001"
}
foreach ($name in $urls.Keys) {
  if (Test-Url $urls[$name]) {
    Write-Ok "$name responde en $($urls[$name])"
  } else {
    Write-Fail "$name no responde en $($urls[$name])"
    Write-Fix "espera 30 segundos; si sigue, .\setup.ps1"
    $problems++
  }
}

# ---------- Disco ----------
Write-Step "Espacio en disco"
$drive = (Get-Item $PSScriptRoot).PSDrive
$free = [math]::Round($drive.Free / 1GB)
if ($free -lt 5) {
  Write-Fail "solo te quedan ${free}G libres; el curso necesita 10G"
  Write-Fix "libera espacio: docker system prune -a -f"
  $problems++
} else {
  Write-Ok "${free}G disponibles"
}

# ---------- Resumen ----------
Write-Host ""
Write-Host "================================================" -ForegroundColor White
if ($problems -eq 0) {
  Write-Host "  Todo en orden. No hay problemas detectados." -ForegroundColor Green
} else {
  Write-Host "  Detectados $problems problemas. Mira arriba y" -ForegroundColor Yellow
  Write-Host "  aplica los 'arreglo:'." -ForegroundColor Yellow
}
Write-Host "================================================" -ForegroundColor White
Write-Host ""
