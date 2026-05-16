# run.ps1 — Lab 3 ASISTIDO (Windows PowerShell).

$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Banner($t) {
  Write-Host ""
  Write-Host "================================================" -ForegroundColor White
  Write-Host "  $t" -ForegroundColor White
  Write-Host "================================================" -ForegroundColor White
}
function Paso($t)    { Write-Host ""; Write-Host ">>> $t" -ForegroundColor Cyan }
function Explica($t) { Write-Host "    $t" -ForegroundColor DarkGray }
function Run-Cmd {
  $cmd = $args -join ' '
  Write-Host ""
  Write-Host "    `$ $cmd" -ForegroundColor Yellow
  Write-Host ""
  & $args[0] @($args[1..($args.Length - 1)])
  if ($LASTEXITCODE -eq 0) { Write-Host ""; Write-Host "    [OK]" -ForegroundColor Green }
  else { Write-Host ""; Write-Host "    [FALLO]" -ForegroundColor Red; exit 1 }
}
function Pausa { Write-Host ""; Write-Host "    (Enter para continuar)" -ForegroundColor DarkGray; Read-Host | Out-Null }
function Test-Url($url) {
  try { Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

$IMG = "anban/income-api:lab3"
$CONTAINER = "anban-income-api"

# detectar la red real
$NETWORK = (& docker inspect anban-mlflow --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>$null) -join "" -replace "\s",""
if (-not $NETWORK) { $NETWORK = "docker_default" }

Banner "LAB 3 - Servir el modelo con FastAPI + Docker"
Write-Host ""
Write-Host "  En este lab vas a:"
Write-Host "    1. Construir una imagen Docker con la API."
Write-Host "    2. Lanzarla apuntando al modelo del Registry."
Write-Host "    3. Probar /health, /version, /predict, /metrics."
Pausa

# Paso 0
Paso "Paso 0 - Prerrequisitos"
if (-not (Test-Url "http://localhost:5050")) {
  Write-Host "    [FALLO] MLflow no responde" -ForegroundColor Red; exit 1
}
$staging = ""
try {
  $r = Invoke-WebRequest -Uri "http://localhost:5050/api/2.0/mlflow/registered-models/get?name=heart-failure-clf" -UseBasicParsing -TimeoutSec 5
  $j = $r.Content | ConvertFrom-Json
  foreach ($v in $j.registered_model.latest_versions) {
    if ($v.current_stage -eq "Staging") { $staging = $v.version; break }
  }
} catch {}
if (-not $staging) {
  Write-Host "    [FALLO] No hay version de heart-failure-clf en Staging" -ForegroundColor Red
  Write-Host "    Ejecuta primero:  cd ..\lab2_mlflow_dvc; .\run.ps1"
  exit 1
}
Write-Host "    [OK] heart-failure-clf v$staging en Staging" -ForegroundColor Green
& docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "    [FALLO] Docker no responde" -ForegroundColor Red; exit 1 }
Write-Host "    [OK] Docker activo, red: $NETWORK" -ForegroundColor Green
Pausa

# Paso 1 - limpieza contenedor previo
Paso "Paso 1 - Limpiar contenedor previo"
$existing = & docker ps -a --filter "name=^$CONTAINER`$" --format '{{.Names}}' 2>$null
if ($existing) {
  & docker rm -f $CONTAINER 2>&1 | Out-Null
  Write-Host "    contenedor previo eliminado"
} else {
  Write-Host "    no habia contenedor previo"
}
Pausa

# Paso 2 - build
Paso "Paso 2 - Construir la imagen Docker"
Explica "Multi-stage build. Primera vez 1-3 min."
Run-Cmd docker build -t $IMG .
Write-Host "    Tamano de la imagen:"
& docker images $IMG --format "    {{.Repository}}:{{.Tag}}  {{.Size}}"
Pausa

# Paso 3 - run
Paso "Paso 3 - Lanzar el contenedor"
Run-Cmd docker run -d --name $CONTAINER --network $NETWORK -p 8000:8000 `
  -e MLFLOW_TRACKING_URI=http://anban-mlflow:5000 `
  -e MLFLOW_S3_ENDPOINT_URL=http://anban-minio:9000 `
  -e AWS_ACCESS_KEY_ID=minio `
  -e AWS_SECRET_ACCESS_KEY=minio12345 `
  -e MODEL_URI=models:/heart-failure-clf/Staging `
  $IMG

Write-Host "    Esperando a que la API arranque..."
$ready = $false
for ($i = 0; $i -lt 40; $i++) {
  if (Test-Url "http://localhost:8000/health") { $ready = $true; break }
  Write-Host -NoNewline "."
  Start-Sleep -Seconds 2
}
Write-Host ""
if (-not $ready) {
  Write-Host "    [FALLO] La API no arranco en 80s" -ForegroundColor Red
  Write-Host "    Mira los logs:  docker logs $CONTAINER"
  exit 1
}
Write-Host "    [OK] API en http://localhost:8000" -ForegroundColor Green
Pausa

# Paso 4 - health y version
Paso "Paso 4 - /health y /version"
Write-Host ""
Write-Host "    `$ curl http://localhost:8000/health" -ForegroundColor Yellow
Invoke-RestMethod -Uri http://localhost:8000/health | ConvertTo-Json | ForEach-Object { "      $_" }
Write-Host ""
Write-Host "    `$ curl http://localhost:8000/version" -ForegroundColor Yellow
Invoke-RestMethod -Uri http://localhost:8000/version | ConvertTo-Json | ForEach-Object { "      $_" }
Pausa

# Paso 5 - predict
Paso "Paso 5 - Hacer una prediccion"
$payload = @{
  age = 39; workclass = "State-gov"; education_num = 13
  marital_status = "Never-married"; occupation = "Adm-clerical"
  relationship = "Not-in-family"; race = "White"; sex = "Male"
  capital_gain = 2174; capital_loss = 0
  hours_per_week = 40; native_country = "United-States"
} | ConvertTo-Json
Write-Host ""
Write-Host "    `$ curl -X POST http://localhost:8000/predict ..." -ForegroundColor Yellow
Invoke-RestMethod -Uri http://localhost:8000/predict -Method Post -ContentType "application/json" -Body $payload | ConvertTo-Json | ForEach-Object { "      $_" }
Write-Host "    [OK] prediccion servida" -ForegroundColor Green
Pausa

# Paso 6 - input invalido
Paso "Paso 6 - Probar input invalido (age=200)"
$bad = '{"age":200,"workclass":"Private","education_num":10,"marital_status":"x","occupation":"x","relationship":"x","race":"x","sex":"Male","capital_gain":0,"capital_loss":0,"hours_per_week":40,"native_country":"x"}'
try {
  Invoke-RestMethod -Uri http://localhost:8000/predict -Method Post -ContentType "application/json" -Body $bad -ErrorAction Stop
} catch {
  $sc = $_.Exception.Response.StatusCode.value__
  Write-Host "    HTTP $sc"
  if ($sc -eq 422) { Write-Host "    [OK] Pydantic rechazo age=200 con 422" -ForegroundColor Green }
}
Pausa

# Paso 7 - metrics
Paso "Paso 7 - /metrics"
Invoke-WebRequest -Uri http://localhost:8000/metrics -UseBasicParsing | Select-Object -ExpandProperty Content | ForEach-Object { "      $_" }
Pausa

# Paso 8 - swagger
Paso "Paso 8 - Swagger"
Write-Host "    Abre en el navegador: http://localhost:8000/docs"
Pausa

Banner "LAB 3 COMPLETO"
Write-Host ""
Write-Host "  El contenedor sigue arriba."
Write-Host "  Para pararlo:   docker stop $CONTAINER"
Write-Host ""
Write-Host "  Cuando estes listo, ve al Lab 4:"
Write-Host "      cd ..\lab4_cicd_monitoring"
Write-Host "      .\run.ps1"
Write-Host ""
