# run.ps1 — Lab 2 ASISTIDO (Windows PowerShell).

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

Banner "LAB 2 - MLflow Tracking y Model Registry"
Write-Host ""
Write-Host "  En este lab vas a:"
Write-Host "    1. Entrenar tres modelos (logreg, rf, xgboost)."
Write-Host "    2. Loguearlos a MLflow."
Write-Host "    3. Compararlos en la UI."
Write-Host "    4. Registrar el mejor."
Write-Host "    5. Promocionarlo a Staging."
Pausa

# Paso 0
Paso "Paso 0 - Prerrequisitos"
$dataDir = "..\lab1_dataops\data\processed"
if (-not (Test-Path "$dataDir\train.parquet") -or -not (Test-Path "$dataDir\test.parquet")) {
  Write-Host "    [FALLO] Faltan los parquet del Lab 1" -ForegroundColor Red
  Write-Host "    Ejecuta primero:  cd ..\lab1_dataops; .\run.ps1"
  exit 1
}
Write-Host "    [OK] parquet del Lab 1 disponibles" -ForegroundColor Green
if (-not (Test-Url "http://localhost:5050")) {
  Write-Host "    [FALLO] MLflow no responde" -ForegroundColor Red
  exit 1
}
Write-Host "    [OK] MLflow vivo" -ForegroundColor Green
if (-not (Test-Url "http://localhost:9000/minio/health/live")) {
  Write-Host "    [FALLO] MinIO no responde" -ForegroundColor Red
  exit 1
}
Write-Host "    [OK] MinIO vivo" -ForegroundColor Green
Pausa

# Paso 1 - env vars
Paso "Paso 1 - Variables de entorno"
$env:MLFLOW_TRACKING_URI = "http://localhost:5050"
$env:MLFLOW_S3_ENDPOINT_URL = "http://localhost:9000"
$env:AWS_ACCESS_KEY_ID = "minio"
$env:AWS_SECRET_ACCESS_KEY = "minio12345"
Write-Host ""
Write-Host "    MLFLOW_TRACKING_URI    = $env:MLFLOW_TRACKING_URI"
Write-Host "    MLFLOW_S3_ENDPOINT_URL = $env:MLFLOW_S3_ENDPOINT_URL"
Write-Host "    AWS_ACCESS_KEY_ID      = $env:AWS_ACCESS_KEY_ID"
Write-Host "    AWS_SECRET_ACCESS_KEY  = ************"
Write-Host "    [OK]" -ForegroundColor Green
Pausa

# Paso 2 - deps
Paso "Paso 2 - Dependencias Python"
& python -c "import mlflow, sklearn, xgboost, pandas, pyarrow, boto3" 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "    Instalando dependencias..."
  pip install --quiet mlflow==2.17.2 scikit-learn xgboost pandas pyarrow boto3
}
Write-Host "    [OK]" -ForegroundColor Green
Pausa

# Paso 2.5 - limpieza idempotente
Paso "Limpieza previa de MLflow"
$py = @'
import os, mlflow
from mlflow.tracking import MlflowClient
from mlflow.exceptions import RestException

mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
client = MlflowClient()
exp = client.get_experiment_by_name("income-classifier")
if exp is not None and exp.lifecycle_stage == "deleted":
    client.restore_experiment(exp.experiment_id)
    print("    restaurado experimento previo")
elif exp is None:
    print("    no existia, se creara al primer log")
else:
    print("    experimento activo")
try:
    client.delete_registered_model("income-clf")
    print("    modelo registrado anterior eliminado")
except RestException:
    pass
'@
$py | python
Pausa

# Paso 3 - train
Paso "Paso 3 - Entrenar tres modelos"
Run-Cmd python src/train.py --model logreg
Run-Cmd python src/train.py --model rf
Run-Cmd python src/train.py --model xgb
Write-Host "    Abre http://localhost:5050 -> experimento 'income-classifier'"
Pausa

# Paso 4 - register
Paso "Paso 4 - Registrar el mejor"
Run-Cmd python src/register_best.py --experiment income-classifier --metric f1 --name income-clf
Pausa

# Paso 5 - promote
Paso "Paso 5 - Promocionar a Staging"
Run-Cmd python src/promote.py --name income-clf --version 1 --stage Staging
Pausa

# Paso 6 - load
Paso "Paso 6 - Cargar el modelo desde el Registry"
$py2 = @'
import os, mlflow.pyfunc
os.environ["MLFLOW_TRACKING_URI"] = "http://localhost:5050"
os.environ["MLFLOW_S3_ENDPOINT_URL"] = "http://localhost:9000"
os.environ["AWS_ACCESS_KEY_ID"] = "minio"
os.environ["AWS_SECRET_ACCESS_KEY"] = "minio12345"
m = mlflow.pyfunc.load_model("models:/income-clf/Staging")
print("    Modelo cargado correctamente")
print(f"    Run ID:   {m.metadata.run_id}")
if m.metadata.signature:
    n = len(m.metadata.signature.inputs.inputs)
    print(f"    Inputs:   {n} columnas esperadas")
'@
$py2 | python
Pausa

Banner "LAB 2 COMPLETO"
Write-Host ""
Write-Host "  Cuando estes listo, ve al Lab 3:"
Write-Host "      cd ..\lab3_serving"
Write-Host "      .\run.ps1"
Write-Host ""
