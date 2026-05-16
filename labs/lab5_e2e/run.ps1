# run.ps1 — Lab 5 E2E (Windows PowerShell).

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
function Pausa { Write-Host ""; Write-Host "    (Enter para continuar)" -ForegroundColor DarkGray; Read-Host | Out-Null }
function Test-Url($url) {
  try { Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

$ROOT_DIR = (Get-Item "..\..").FullName

Banner "LAB 5 - Caso end-to-end + Model Card"
Write-Host ""
Write-Host "  Recorremos el ciclo entero: datos -> modelo -> registry"
Write-Host "  -> API -> drift -> governance."
Pausa

# Paso 0
Paso "Paso 0 - Stack vivo"
if (Test-Url "http://localhost:5050") { Write-Host "    [OK] MLflow" -ForegroundColor Green }
else { Write-Host "    [FALLO] MLflow no responde. Lanza .\setup.ps1 desde la raiz." -ForegroundColor Red; exit 1 }
if (Test-Url "http://localhost:9000/minio/health/live") { Write-Host "    [OK] MinIO" -ForegroundColor Green }
else { Write-Host "    [FALLO] MinIO" -ForegroundColor Red; exit 1 }
if (Test-Url "http://localhost:8888") { Write-Host "    [OK] Jupyter" -ForegroundColor Green }
Pausa

# Paso 1 - datos
Paso "Paso 1 - Datos (Lab 1)"
$dataDir = Join-Path $ROOT_DIR "labs\lab1_dataops\data\processed"
if ((Test-Path (Join-Path $dataDir "train.parquet")) -and (Test-Path (Join-Path $dataDir "test.parquet"))) {
  Write-Host "    [OK] parquet de entrenamiento listos" -ForegroundColor Green
  $py = @"
import pandas as pd
for n in ["train", "test"]:
    df = pd.read_parquet(r'$dataDir' + chr(92) + n + '.parquet')
    print(f'      {n+\".parquet\":<18s} {len(df):>7,} filas')
"@
  $py | python
} else {
  Write-Host "    [FALLO] Faltan parquet. Lanza:  cd ..\lab1_dataops; .\run.ps1" -ForegroundColor Red
  exit 1
}
Pausa

# Paso 2 - Registry
Paso "Paso 2 - Modelo en el Registry (Lab 2)"
$py2 = @'
import os, sys, mlflow
from mlflow.tracking import MlflowClient
mlflow.set_tracking_uri("http://localhost:5050")
client = MlflowClient()
try:
    versions = list(client.search_model_versions("name='income-clf'"))
except Exception:
    print("    [X] no existe income-clf"); sys.exit(1)
if not versions:
    print("    [X] no hay versiones"); sys.exit(1)
print("    Versiones registradas:")
for v in sorted(versions, key=lambda x: int(x.version)):
    run = client.get_run(v.run_id)
    f1 = run.data.metrics.get("f1", float("nan"))
    print(f"      v{v.version}  stage={v.current_stage:<12}  f1={f1:.4f}")
'@
$py2 | python
Pausa

# Paso 3 - API
Paso "Paso 3 - API (Lab 3)"
if (Test-Url "http://localhost:8000/health") {
  Write-Host "    [OK] API arriba" -ForegroundColor Green
  Invoke-RestMethod -Uri http://localhost:8000/health | ConvertTo-Json | ForEach-Object { "      $_" }
  Invoke-RestMethod -Uri http://localhost:8000/version | ConvertTo-Json | ForEach-Object { "      $_" }
} else {
  Write-Host "    [!] La API no esta activa. Levantala con:" -ForegroundColor Yellow
  Write-Host "       cd ..\lab3_serving; .\run.ps1"
}
Pausa

# Paso 4 - drift
Paso "Paso 4 - Reporte de drift (Lab 4)"
$driftHtml = Join-Path $ROOT_DIR "labs\lab4_cicd_monitoring\reports\drift.html"
$driftJson = Join-Path $ROOT_DIR "labs\lab4_cicd_monitoring\reports\drift.json"
if ((Test-Path $driftHtml) -and (Test-Path $driftJson)) {
  Write-Host "    [OK] reportes encontrados" -ForegroundColor Green
  $py3 = @"
import json
with open(r'$driftJson') as f:
    s = json.load(f)
if isinstance(s, dict):
    items = sorted([(k, v) for k, v in s.items() if isinstance(v, (int, float))], key=lambda x: -x[1])[:3]
    print('    Top 3 features con drift:')
    for k, v in items:
        m = 'DRIFT' if v > 0.25 else '    '
        print(f'      {m}  {k:30s} PSI={v:.4f}')
"@
  $py3 | python
} else {
  Write-Host "    [!] No hay reportes. Lanza:  cd ..\lab4_cicd_monitoring; .\run.ps1" -ForegroundColor Yellow
}
Pausa

# Paso 5 - Model Card
Paso "Paso 5 - Generar la Model Card"
$py4 = @'
import os, datetime, mlflow
from mlflow.tracking import MlflowClient
mlflow.set_tracking_uri("http://localhost:5050")
client = MlflowClient()
versions = list(client.search_model_versions("name='income-clf'"))
candidates = [v for v in versions if v.current_stage in ("Staging", "Production")]
if not candidates: candidates = versions
mv = sorted(candidates, key=lambda v: int(v.version))[-1]
run = client.get_run(mv.run_id)
metrics, params, tags = run.data.metrics, run.data.params, run.data.tags
date = datetime.date.today().isoformat()

with open("MODEL_CARD.md", "w", encoding="utf-8") as f:
    f.write(f"""# Model Card - income-clf

> Fecha: {date}
> Version: v{mv.version}
> Stage: {mv.current_stage}

## 1. Proposito

Modelo de clasificacion binaria que predice si una persona tiene
ingresos > 50.000 USD/anio. Uso docente. NO usar para decisiones reales.

## 2. Datos de entrenamiento

- Dataset: UCI Adult Income (1994).
- Origen: archive.ics.uci.edu/ml/datasets/adult.

## 3. Modelo

- Framework: {tags.get("framework", "desconocido")}
- Algoritmo: {params.get("model", "desconocido")}
- Run ID: {mv.run_id}
- Commit: {tags.get("git_commit", "n/a")}

## 4. Metricas

| Metrica | Valor |
|---------|-------|
""")
    for k in ("accuracy", "precision", "recall", "f1", "roc_auc"):
        if k in metrics:
            f.write(f"| {k} | {metrics[k]:.4f} |\n")
    f.write("""

## 5. Limitaciones conocidas

- Dataset de 1994.
- Sesgos historicos en sex y race.
- No incluye variables socioeconomicas relevantes.

## 6. Contraindicaciones (RELLENAR)

- [ ] NO usar para scoring de credito real.
- [ ] NO usar para seleccion de personal.
- [ ] NO usar para decisiones automatizadas (RGPD Art. 22).

## 7. Governance (TO DO)

- [ ] Owner identificado.
- [ ] Audit log activado.
- [ ] Plan de rollback.
- [ ] DPIA si afecta a personas.
""")
print("    [OK] MODEL_CARD.md generada")
'@
$py4 | python
Pausa

# Paso 6 - checklist
Paso "Paso 6 - Checklist final del curso"
Write-Host ""
Write-Host "  Marca lo que tienes completo:"
Write-Host ""
Write-Host "  DataOps"
Write-Host "    [ ] Repo git inicializado en lab1_dataops"
Write-Host "    [ ] Dataset versionado por DVC"
Write-Host "    [ ] Pipeline reproducible"
Write-Host "    [ ] train/test.parquet generados"
Write-Host ""
Write-Host "  MLflow"
Write-Host "    [ ] Experimento con 3 runs"
Write-Host "    [ ] Modelo income-clf registrado"
Write-Host "    [ ] Version 1 en Staging"
Write-Host ""
Write-Host "  Serving"
Write-Host "    [ ] Imagen Docker construida"
Write-Host "    [ ] API respondiendo"
Write-Host "    [ ] Pydantic rechaza inputs invalidos"
Write-Host ""
Write-Host "  Drift y CI/CD"
Write-Host "    [ ] reports/drift.html"
Write-Host "    [ ] promote_if_better.py ejecutado"
Write-Host ""
Write-Host "  Governance"
Write-Host "    [ ] MODEL_CARD.md generada"
Pausa

Banner "CURSO COMPLETO"
Write-Host ""
Write-Host "  Has recorrido el ciclo entero MLOps:"
Write-Host "    1. Datos versionados y validados"
Write-Host "    2. Modelos trackeados y comparables"
Write-Host "    3. Modelo registrado y promocionado"
Write-Host "    4. Servido en produccion local"
Write-Host "    5. Vigilado contra drift"
Write-Host "    6. Documentado con Model Card"
Write-Host ""
