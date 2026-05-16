#!/usr/bin/env bash
# run.sh — Lab 4 ASISTIDO. CI/CD para ML, drift y promoción condicional.

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
run_cmd() {
  echo ""; echo "    ${C_YELLOW}\$ $*${C_RESET}"; echo ""
  if "$@"; then echo ""; echo "    ${C_GREEN}✓ ok${C_RESET}"
  else echo ""; echo "    ${C_RED}✗ falló${C_RESET}"; exit 1; fi
}
pausa() { echo ""; echo "${C_DIM}    (Enter para continuar)${C_RESET}"; read -r _; }

export MLFLOW_TRACKING_URI=http://localhost:5050
export MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=minio
export AWS_SECRET_ACCESS_KEY=minio12345

# ============================================================
banner "LAB 4 — CI/CD para ML + Drift detection"
echo ""
echo "  En este lab vas a:"
echo "    1. Inyectar drift sintético en el dataset de test."
echo "    2. Generar un reporte de drift por feature (PSI)."
echo "    3. Probar el promote condicional (acepta/rechaza por métrica)."
echo "    4. Entender el workflow de GitHub Actions del repo."
pausa

# ============================================================
# Paso 0 — Prerrequisitos
# ============================================================
paso "Paso 0 · Comprobar prerrequisitos"

DATA_DIR="../lab1_dataops/data/processed"
if [ ! -f "$DATA_DIR/test.parquet" ]; then
  echo "    ${C_RED}✗ No encuentro $DATA_DIR/test.parquet${C_RESET}"
  echo "    Ejecuta primero:  cd ../lab1_dataops && ./run.sh"
  exit 1
fi
echo "    ${C_GREEN}✓${C_RESET} parquet del Lab 1 disponible"

if ! curl -fsS -m 5 -o /dev/null http://localhost:5050; then
  echo "    ${C_RED}✗ MLflow no responde${C_RESET}"
  exit 1
fi
echo "    ${C_GREEN}✓${C_RESET} MLflow vivo"

if ! python -c "import mlflow, pandas, numpy" 2>/dev/null; then
  pip install --quiet mlflow==2.17.2 pandas numpy pyarrow boto3 \
    || { echo "    ${C_RED}✗ pip install falló${C_RESET}"; exit 1; }
fi
echo "    ${C_GREEN}✓${C_RESET} dependencias Python"
pausa

# ============================================================
# Paso 1 — Inyectar drift
# ============================================================
paso "Paso 1 · Crear un dataset con drift inyectado"
explica "Cogemos el test.parquet del Lab 1 y lo modificamos: shift en"
explica "hours_per_week, ruido en capital_gain, leves cambios de prevalencia."
explica "Esto simula que la realidad ha cambiado tras desplegar el modelo."

mkdir -p data/processed reports
run_cmd python synthetic/make_drift.py

echo ""
echo "    Ahora tenemos dos datasets para comparar:"
echo "      Referencia: $DATA_DIR/test.parquet (datos al entrenar)"
echo "      Actuales:   data/processed/drifted.parquet (con drift)"
pausa

# ============================================================
# Paso 2 — Generar reporte de drift
# ============================================================
paso "Paso 2 · Calcular PSI por feature y generar HTML"
explica "PSI (Population Stability Index): mide cuánto cambió la distribución."
explica "  PSI < 0.1   : estable"
explica "  PSI 0.1-0.25: vigilar"
explica "  PSI >= 0.25 : drift importante"

run_cmd python src/drift_report.py \
  --reference "$DATA_DIR/test.parquet" \
  --current data/processed/drifted.parquet \
  --output reports/drift.html

echo ""
echo "    Reporte generado en:"
ls -lh reports/drift.html reports/drift.json 2>/dev/null | sed 's/^/      /'
echo ""
echo "    Top 5 features con mayor drift (PSI):"
python3 -c "
import json
with open('reports/drift.json') as f:
    scores = json.load(f)
if isinstance(scores, dict):
    items = [(k, v) for k, v in scores.items() if isinstance(v, (int, float))]
    items.sort(key=lambda x: -x[1])
    for k, v in items[:5]:
        marker = '⚠' if v > 0.25 else (' ' if v < 0.1 else '·')
        print(f'      {marker} {k:35s} PSI={v:.4f}')
" 2>/dev/null
echo ""
echo "    Abre ${C_BOLD}reports/drift.html${C_RESET} en el navegador para verlo entero."
pausa

# ============================================================
# Paso 3 — Promote condicional: caso REJECT
# ============================================================
paso "Paso 3 · Probar el promote condicional"
explica "El script promote_if_better.py compara el f1 del candidato con"
explica "el del Production y solo asciende si mejora al menos --min-improvement."

echo ""
echo "    Estado actual de income-clf:"
python3 <<'PYTHON'
import os, mlflow
from mlflow.tracking import MlflowClient
mlflow.set_tracking_uri(os.environ['MLFLOW_TRACKING_URI'])
client = MlflowClient()
for v in client.search_model_versions("name='income-clf'"):
    run = client.get_run(v.run_id)
    f1 = run.data.metrics.get('f1', float('nan'))
    print(f"      v{v.version}  stage={v.current_stage:<12}  f1={f1:.4f}")
PYTHON

echo ""
explica "Como aún no hay Production, el script promociona el candidato a Staging."
echo ""
run_cmd python src/promote_if_better.py \
  --name income-clf \
  --metric f1 \
  --min-improvement 0.01
pausa

# ============================================================
# Paso 4 — Workflow GitHub Actions
# ============================================================
paso "Paso 4 · Revisar el workflow CI/CD"
explica "El fichero .github/workflows/ml.yml define la integración continua."
explica "No lo ejecutamos aquí (necesita un repo de GitHub real),"
explica "pero conviene saber qué hace cada job."

if [ -f .github/workflows/ml.yml ]; then
  echo ""
  echo "    Estructura del workflow:"
  grep -E "^(name:|jobs:|  [a-z-]+:|    runs-on:)" .github/workflows/ml.yml \
    | sed 's/^/      /' | head -25
else
  echo "    ${C_YELLOW}!${C_RESET} no se encuentra .github/workflows/ml.yml"
fi

echo ""
echo "    En CI haríamos:"
echo "      1. lint + tests"
echo "      2. train + evaluate"
echo "      3. promote_if_better.py  (auto-promoción)"
echo "      4. build de la imagen y push a registry"
pausa

# ============================================================
# Cierre
# ============================================================
banner "LAB 4 COMPLETO"
echo ""
echo "  ${C_GREEN}Has hecho:${C_RESET}"
echo "    ✓ Inyectado drift sintético sobre datos reales"
echo "    ✓ Calculado PSI por feature y generado reporte HTML"
echo "    ✓ Probado el promote condicional contra el Registry"
echo "    ✓ Visto la estructura de un workflow de CI/CD para ML"
echo ""
echo "  ${C_BOLD}Cosas que mirar:${C_RESET}"
echo "    - reports/drift.html   (abre en navegador)"
echo "    - reports/drift.json   (PSI numéricos por feature)"
echo "    - http://localhost:5050 → Models → income-clf con stages"
echo ""
echo "  Cuando estés listo, ve al Lab 5:"
echo "    ${C_BOLD}cd ../lab5_e2e && ./run.sh${C_RESET}"
echo ""
