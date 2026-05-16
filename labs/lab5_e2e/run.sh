#!/usr/bin/env bash
# run.sh — Lab 5 E2E. Orquesta los cuatro labs anteriores en cadena
# y termina rellenando la Model Card.

set -uo pipefail
cd "$(dirname "$0")"

if [[ -t 1 ]]; then
  C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'
  C_BLUE=$'\033[1;34m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'; C_DIM=$'\033[2m'
else
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""; C_BOLD=""; C_RESET=""; C_DIM=""
fi

banner() { echo ""; echo "${C_BOLD}================================================${C_RESET}"; echo "${C_BOLD}  $*${C_RESET}"; echo "${C_BOLD}================================================${C_RESET}"; }
paso()    { echo ""; echo "${C_BLUE}${C_BOLD}>>> $*${C_RESET}"; }
explica() { echo "${C_DIM}    $*${C_RESET}"; }
pausa()   { echo ""; echo "${C_DIM}    (Enter para continuar)${C_RESET}"; read -r _; }
check_url() {
  curl -fsS -m 5 -o /dev/null "$1" 2>/dev/null
}

ROOT_DIR="$(cd ../.. && pwd)"

# ============================================================
banner "LAB 5 — Caso end-to-end + Model Card"
echo ""
echo "  Vamos a recorrer el ciclo entero como si fuera el día 1 en una"
echo "  empresa nueva: datos → modelo → registry → API → drift → governance."
echo ""
echo "  No volvemos a reentrenar de cero: comprobamos que cada pieza"
echo "  está en su sitio y dejamos un commit demostrativo."
pausa

# ============================================================
# Paso 0 — Comprobar estado del entorno
# ============================================================
paso "Paso 0 · Comprobar que el stack está vivo"

if check_url http://localhost:5050; then
  echo "    ${C_GREEN}✓${C_RESET} MLflow"
else
  echo "    ${C_RED}✗${C_RESET} MLflow no responde. Ejecuta ./setup.sh desde la raíz."
  exit 1
fi
if check_url http://localhost:9000/minio/health/live; then
  echo "    ${C_GREEN}✓${C_RESET} MinIO"
else
  echo "    ${C_RED}✗${C_RESET} MinIO no responde"
  exit 1
fi
if check_url http://localhost:8888; then
  echo "    ${C_GREEN}✓${C_RESET} Jupyter"
fi
pausa

# ============================================================
# Paso 1 — Datos
# ============================================================
paso "Paso 1 · Comprobar la parte de datos (lab 1)"
explica "El pipeline reproducible del Lab 1 debe haber dejado los parquet."

DATA_DIR="$ROOT_DIR/labs/lab1_dataops/data/processed"
if [ -f "$DATA_DIR/train.parquet" ] && [ -f "$DATA_DIR/test.parquet" ]; then
  echo "    ${C_GREEN}✓${C_RESET} parquet de entrenamiento listos"
  echo ""
  echo "    Filas y peso:"
  python3 -c "
import pandas as pd
for n in ['train', 'test']:
    df = pd.read_parquet('$DATA_DIR/' + n + '.parquet')
    print(f'      {n+\".parquet\":<18s} {len(df):>7,} filas · {df.shape[1]} columnas')
"
else
  echo "    ${C_YELLOW}!${C_RESET} faltan parquet. Lanza:  cd ../lab1_dataops && ./run.sh"
  exit 1
fi
pausa

# ============================================================
# Paso 2 — Modelo en el Registry
# ============================================================
paso "Paso 2 · Comprobar el modelo en MLflow Registry (lab 2)"
explica "El modelo income-clf debe tener al menos una versión en Staging."

python3 <<'PYTHON'
import os, sys, mlflow
from mlflow.tracking import MlflowClient

mlflow.set_tracking_uri("http://localhost:5050")
client = MlflowClient()

try:
    versions = list(client.search_model_versions("name='income-clf'"))
except Exception:
    print("    ✗ no existe income-clf en el Registry"); sys.exit(1)

if not versions:
    print("    ✗ no hay versiones de income-clf"); sys.exit(1)

print("    Versiones registradas:")
for v in sorted(versions, key=lambda x: int(x.version)):
    run = client.get_run(v.run_id)
    f1 = run.data.metrics.get('f1', float('nan'))
    print(f"      v{v.version}  stage={v.current_stage:<12}  f1={f1:.4f}")
PYTHON
pausa

# ============================================================
# Paso 3 — API en contenedor
# ============================================================
paso "Paso 3 · Comprobar la API (lab 3)"
explica "Si el contenedor del Lab 3 está corriendo, miramos health y version."

if curl -fsS -m 5 -o /dev/null http://localhost:8000/health 2>/dev/null; then
  echo "    ${C_GREEN}✓${C_RESET} API arriba en http://localhost:8000"
  echo ""
  echo "    Health:"
  curl -s http://localhost:8000/health | python3 -m json.tool | sed 's/^/      /'
  echo ""
  echo "    Version:"
  curl -s http://localhost:8000/version | python3 -m json.tool | sed 's/^/      /'
else
  echo "    ${C_YELLOW}!${C_RESET} la API no está activa. Para levantarla:"
  echo "       cd ../lab3_serving && ./run.sh"
fi
pausa

# ============================================================
# Paso 4 — Reporte de drift
# ============================================================
paso "Paso 4 · Comprobar el reporte de drift (lab 4)"

DRIFT_HTML="$ROOT_DIR/labs/lab4_cicd_monitoring/reports/drift.html"
DRIFT_JSON="$ROOT_DIR/labs/lab4_cicd_monitoring/reports/drift.json"
if [ -f "$DRIFT_HTML" ] && [ -f "$DRIFT_JSON" ]; then
  echo "    ${C_GREEN}✓${C_RESET} reportes encontrados"
  echo ""
  echo "    Top 3 features con drift:"
  python3 -c "
import json
with open('$DRIFT_JSON') as f:
    s = json.load(f)
if isinstance(s, dict):
    items = sorted([(k, v) for k, v in s.items() if isinstance(v, (int, float))],
                   key=lambda x: -x[1])[:3]
    for k, v in items:
        m = '⚠' if v > 0.25 else ' '
        print(f'      {m} {k:30s} PSI={v:.4f}')
"
else
  echo "    ${C_YELLOW}!${C_RESET} no hay reportes. Ejecuta:  cd ../lab4_cicd_monitoring && ./run.sh"
fi
pausa

# ============================================================
# Paso 5 — Generar Model Card
# ============================================================
paso "Paso 5 · Rellenar la Model Card del modelo en Staging"
explica "Generamos automáticamente lo que se puede sacar del Registry."
explica "Los apartados de governance hay que rellenarlos a mano."

python3 <<'PYTHON' > MODEL_CARD.md
import os, datetime, json
import mlflow
from mlflow.tracking import MlflowClient
mlflow.set_tracking_uri("http://localhost:5050")
client = MlflowClient()

# Buscamos la versión más reciente con stage no archivado
versions = list(client.search_model_versions("name='income-clf'"))
candidates = [v for v in versions if v.current_stage in ("Staging", "Production")]
if not candidates:
    candidates = versions
mv = sorted(candidates, key=lambda v: int(v.version))[-1]

run = client.get_run(mv.run_id)
metrics = run.data.metrics
params = run.data.params
tags = run.data.tags

date = datetime.date.today().isoformat()

print(f"""# Model Card — income-clf

> Fecha: {date}
> Versión: v{mv.version}
> Stage: {mv.current_stage}

## 1. Propósito

Modelo de clasificación binaria que predice si una persona tiene ingresos
anuales superiores a 50.000 USD a partir de variables demográficas y
laborales del censo de Estados Unidos de 1994 (UCI Adult).

Uso docente. NO usar para decisiones reales sobre personas.

## 2. Datos de entrenamiento

- Dataset: UCI Adult Income.
- Origen: archive.ics.uci.edu/ml/datasets/adult.
- Tamaño: ~30.000 filas, 14 variables originales.
- Año de los datos: 1994.
- Limpieza: filas con `?` en workclass, occupation o native_country eliminadas.
- Codificación: one-hot de variables categóricas.
- Split: 80/20 estratificado por income.

## 3. Modelo

- Framework: {tags.get('framework', 'desconocido')}
- Algoritmo: {params.get('model', 'desconocido')}
- Run ID: {mv.run_id}
- Hash del commit: {tags.get('git_commit', 'n/a')}

### Hiperparámetros

| Parámetro | Valor |
|-----------|-------|""")

for k, v in sorted(params.items()):
    print(f"| {k} | {v} |")

print(f"""

## 4. Métricas globales (test set 20%)

| Métrica | Valor |
|---------|-------|""")

for k in ('accuracy', 'precision', 'recall', 'f1', 'roc_auc'):
    if k in metrics:
        print(f"| {k} | {metrics[k]:.4f} |")

print("""

## 5. Limitaciones conocidas

- Dataset de 1994: la distribución actual de la población es distinta.
- Sesgos del propio dataset:
  - Mujeres infrarrepresentadas en altos ingresos por la época.
  - Sobre-representación de población blanca y de origen US.
- Definición binaria de `sex` (solo Male/Female).
- No incluye variables socioeconómicas relevantes (deuda, patrimonio, etc.).

## 6. Contraindicaciones (RELLENAR)

NO usar este modelo para:

- [ ] Scoring de crédito real.
- [ ] Selección de personal.
- [ ] Decisiones automatizadas sobre personas físicas (RGPD Art. 22).
- [ ] Sistemas en producción con tráfico real.

## 7. Métricas por subgrupo (TO DO)

Calcular y rellenar:

- [ ] F1 por `sex` (Female vs Male).
- [ ] F1 por `race`.
- [ ] Diferencia de tasa de falsos positivos entre subgrupos.
- [ ] Decisión: ¿se acepta la disparidad? ¿se mitiga? ¿se descarta el modelo?

## 8. Governance

- [ ] Owner identificado y on-call documentado.
- [ ] Audit log activado en producción (request_id, payload, predicción).
- [ ] Plan de rollback: a qué versión volver si la actual rompe.
- [ ] Política de reentrenamiento: cada cuánto, con qué datos.
- [ ] DPIA hecha si el modelo afecta a personas (RGPD Art. 35).

## 9. Trazabilidad

- Tracking URI: http://localhost:5050
- Run en MLflow: """ + f"http://localhost:5050/#/experiments/{run.info.experiment_id}/runs/{mv.run_id}")
PYTHON

echo "    ${C_GREEN}✓ MODEL_CARD.md generada${C_RESET}"
echo ""
echo "    Vista previa (primeras 30 líneas):"
head -30 MODEL_CARD.md | sed 's/^/      /'
pausa

# ============================================================
# Paso 6 — Checklist final
# ============================================================
paso "Paso 6 · Checklist final del curso"

cat <<'CHECKLIST'

    Marca lo que tienes completo:

    DataOps
      [ ] Repo Git inicializado en lab1_dataops
      [ ] Dataset versionado por DVC (no por Git)
      [ ] Pipeline reproducible (dvc.yaml)
      [ ] train.parquet y test.parquet generados

    MLflow
      [ ] Experimento income-classifier con 3 runs
      [ ] Modelo income-clf registrado
      [ ] Versión 1 en stage Staging

    Serving
      [ ] Imagen Docker construida
      [ ] API respondiendo a /health, /version, /predict, /metrics
      [ ] Pydantic rechaza entradas inválidas

    Drift y CI/CD
      [ ] reports/drift.html con resultados visibles
      [ ] promote_if_better.py ejecutado al menos una vez

    Governance
      [ ] MODEL_CARD.md generada
      [ ] Secciones marcadas como TO DO entendidas

CHECKLIST
pausa

# ============================================================
# Cierre
# ============================================================
banner "CURSO COMPLETO"
echo ""
echo "  Has recorrido el ciclo entero MLOps de un proyecto pequeño:"
echo ""
echo "    1. Datos versionados y validados"
echo "    2. Modelos trackeados y comparables"
echo "    3. Modelo registrado y promocionado"
echo "    4. Servido en producción local"
echo "    5. Vigilado contra drift"
echo "    6. Documentado con Model Card"
echo ""
echo "  ${C_BOLD}Próximos pasos:${C_RESET}"
echo "    - Llevar este flujo a tu trabajo con datos reales."
echo "    - Sustituir MinIO por S3, postgres por RDS, etc."
echo "    - Añadir un orquestador (Airflow, Prefect)."
echo "    - Añadir tu CI real con GitHub Actions o GitLab CI."
echo ""
echo "  El reto opcional: enviar un PR a tu repo personal con:"
echo "    - pipeline de datos versionado"
echo "    - 3 experimentos comparados"
echo "    - modelo en Registry"
echo "    - API funcionando"
echo "    - CI verde"
echo "    - Model Card terminada (con los TO DO rellenos)"
echo ""
