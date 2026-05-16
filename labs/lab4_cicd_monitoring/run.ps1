# run.ps1 — Lab 4 ASISTIDO (Windows PowerShell).

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

$env:MLFLOW_TRACKING_URI = "http://localhost:5050"
$env:MLFLOW_S3_ENDPOINT_URL = "http://localhost:9000"
$env:AWS_ACCESS_KEY_ID = "minio"
$env:AWS_SECRET_ACCESS_KEY = "minio12345"

Banner "LAB 4 - CI/CD para ML + Drift detection"
Write-Host ""
Write-Host "  En este lab vas a:"
Write-Host "    1. Inyectar drift sintetico."
Write-Host "    2. Generar un reporte PSI."
Write-Host "    3. Probar el promote condicional."
Pausa

# Paso 0
Paso "Paso 0 - Prerrequisitos"
$dataDir = "..\lab1_dataops\data\processed"
if (-not (Test-Path "$dataDir\test.parquet")) {
  Write-Host "    [FALLO] no encuentro $dataDir\test.parquet" -ForegroundColor Red
  Write-Host "    Ejecuta primero:  cd ..\lab1_dataops; .\run.ps1"
  exit 1
}
Write-Host "    [OK] parquet del Lab 1" -ForegroundColor Green
if (-not (Test-Url "http://localhost:5050")) {
  Write-Host "    [FALLO] MLflow no responde" -ForegroundColor Red; exit 1
}
Write-Host "    [OK] MLflow vivo" -ForegroundColor Green
& python -c "import mlflow, pandas, numpy" 2>$null
if ($LASTEXITCODE -ne 0) {
  pip install --quiet mlflow==2.17.2 pandas numpy pyarrow boto3
}
Write-Host "    [OK] dependencias Python" -ForegroundColor Green
Pausa

# Paso 1 - drift sintetico
Paso "Paso 1 - Inyectar drift sintetico"
New-Item -ItemType Directory -Path "data\processed","reports" -Force | Out-Null
Run-Cmd python synthetic/make_drift.py
Pausa

# Paso 2 - reporte
Paso "Paso 2 - Calcular PSI y generar HTML"
Explica "PSI < 0.1 estable; 0.1-0.25 vigilar; >= 0.25 drift importante."
Run-Cmd python src/drift_report.py `
  --reference "$dataDir\test.parquet" `
  --current data\processed\drifted.parquet `
  --output reports\drift.html

if (Test-Path "reports\drift.json") {
  Write-Host ""
  Write-Host "    Top 5 features con drift:"
  $py = @'
import json
with open("reports/drift.json") as f:
    s = json.load(f)
if isinstance(s, dict):
    items = sorted([(k, v) for k, v in s.items() if isinstance(v, (int, float))], key=lambda x: -x[1])[:5]
    for k, v in items:
        m = "DRIFT" if v > 0.25 else "    "
        print(f"      {m}  {k:35s} PSI={v:.4f}")
'@
  $py | python
}
Write-Host "    Abre reports\drift.html en el navegador."
Pausa

# Paso 3 - promote condicional
Paso "Paso 3 - Promote condicional"
$py2 = @'
import os, mlflow
from mlflow.tracking import MlflowClient
mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
client = MlflowClient()
print("    Estado actual de heart-failure-clf:")
for v in client.search_model_versions("name='heart-failure-clf'"):
    run = client.get_run(v.run_id)
    f1 = run.data.metrics.get("f1", float("nan"))
    print(f"      v{v.version}  stage={v.current_stage:<12}  f1={f1:.4f}")
'@
$py2 | python
Write-Host ""
Run-Cmd python src/promote_if_better.py --name heart-failure-clf --metric f1 --min-improvement 0.01
Pausa

# Paso 4 - workflow
Paso "Paso 4 - Revisar el workflow CI/CD"
if (Test-Path ".github\workflows\ml.yml") {
  Write-Host "    Estructura del workflow:"
  Get-Content ".github\workflows\ml.yml" | Select-String -Pattern '^(name:|jobs:|  [a-z-]+:|    runs-on:)' | ForEach-Object { "      $_" }
}
Pausa

Banner "LAB 4 COMPLETO"
Write-Host ""
Write-Host "  Cosas que mirar:"
Write-Host "    - reports\drift.html"
Write-Host "    - http://localhost:5050 -> Models -> heart-failure-clf"
Write-Host ""
Write-Host "  Cuando estes listo, ve al Lab 5:"
Write-Host "      cd ..\lab5_e2e"
Write-Host "      .\run.ps1"
Write-Host ""
