#!/usr/bin/env bash
# run.sh — Lab 2 ASISTIDO. Tracking de experimentos y Model Registry.

set -uo pipefail
cd "$(dirname "$0")"

if [[ -t 1 ]]; then
  C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'
  C_BLUE=$'\033[1;34m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'; C_DIM=$'\033[2m'
else
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""; C_BOLD=""; C_RESET=""; C_DIM=""
fi

banner() {
  echo ""
  echo "${C_BOLD}================================================${C_RESET}"
  echo "${C_BOLD}  $*${C_RESET}"
  echo "${C_BOLD}================================================${C_RESET}"
}
paso()    { echo ""; echo "${C_BLUE}${C_BOLD}>>> $*${C_RESET}"; }
explica() { echo "${C_DIM}    $*${C_RESET}"; }
run_cmd() {
  echo ""; echo "    ${C_YELLOW}\$ $*${C_RESET}"; echo ""
  if "$@"; then echo ""; echo "    ${C_GREEN}✓ ok${C_RESET}"
  else echo ""; echo "    ${C_RED}✗ falló${C_RESET}"; exit 1; fi
}
pausa() { echo ""; echo "${C_DIM}    (Enter para continuar)${C_RESET}"; read -r _; }

# ============================================================
banner "LAB 2 — MLflow Tracking y Model Registry"
echo ""
echo "  En este lab vas a:"
echo "    1. Entrenar tres modelos (logreg, random forest, xgboost)."
echo "    2. Loguearlos a MLflow con params, métricas, signature, tags."
echo "    3. Compararlos en la UI."
echo "    4. Registrar el mejor en el Model Registry."
echo "    5. Promocionarlo a Staging."
echo "    6. Cargarlo desde Python con una sola línea."
pausa

# ============================================================
# Paso 0 — Prerrequisitos
# ============================================================
paso "Paso 0 · Comprobar prerrequisitos"
explica "Necesitamos los parquet del Lab 1 y los servicios arriba."

DATA_DIR="../lab1_dataops/data/processed"
if [ ! -f "$DATA_DIR/train.parquet" ] || [ ! -f "$DATA_DIR/test.parquet" ]; then
  echo ""
  echo "    ${C_RED}✗ No encuentro los parquet del Lab 1${C_RESET}"
  echo "    Ejecuta primero:  cd ../lab1_dataops && ./run.sh"
  exit 1
fi
echo "    ${C_GREEN}✓${C_RESET} encontrados $DATA_DIR/train.parquet y test.parquet"

if ! curl -fsS -m 5 -o /dev/null http://localhost:5050; then
  echo "    ${C_RED}✗ MLflow no responde en http://localhost:5050${C_RESET}"
  echo "    Ejecuta desde la raíz:  ./setup.sh"
  exit 1
fi
echo "    ${C_GREEN}✓${C_RESET} MLflow vivo en http://localhost:5050"

if ! curl -fsS -m 5 -o /dev/null http://localhost:9000/minio/health/live; then
  echo "    ${C_RED}✗ MinIO no responde en http://localhost:9000${C_RESET}"
  exit 1
fi
echo "    ${C_GREEN}✓${C_RESET} MinIO vivo"
pausa

# ============================================================
# Paso 1 — Variables de entorno
# ============================================================
paso "Paso 1 · Exportar variables de entorno"
explica "MLflow y boto3 (cliente S3) leen estas variables para hablar con"
explica "el tracking server y el almacenamiento de artefactos (MinIO)."

export MLFLOW_TRACKING_URI=http://localhost:5050
export MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=minio
export AWS_SECRET_ACCESS_KEY=minio12345

echo ""
echo "    MLFLOW_TRACKING_URI    = $MLFLOW_TRACKING_URI"
echo "    MLFLOW_S3_ENDPOINT_URL = $MLFLOW_S3_ENDPOINT_URL"
echo "    AWS_ACCESS_KEY_ID      = $AWS_ACCESS_KEY_ID"
echo "    AWS_SECRET_ACCESS_KEY  = ************"
echo ""
echo "    ${C_GREEN}✓ variables exportadas en esta sesión${C_RESET}"
pausa

# ============================================================
# Paso 2 — Dependencias Python
# ============================================================
paso "Paso 2 · Comprobar dependencias Python"
explica "Necesitamos mlflow, scikit-learn, xgboost, pandas, pyarrow."

if ! python -c "import mlflow, sklearn, xgboost, pandas, pyarrow, boto3" 2>/dev/null; then
  echo ""
  echo "    Faltan algunas. Las instalo:"
  pip install --quiet mlflow==2.17.2 scikit-learn xgboost pandas pyarrow boto3 \
    || { echo "    ${C_RED}✗ pip install falló${C_RESET}"; exit 1; }
fi
echo "    ${C_GREEN}✓ todas las dependencias presentes${C_RESET}"
pausa

# ============================================================
# Paso 2.5 — Limpieza idempotente de MLflow
# ============================================================
paso "Limpieza previa de MLflow (si quedó algo de antes)"
explica "Si ya has ejecutado este lab y el experimento se quedó en mal"
explica "estado, lo restauramos o creamos limpio."

python3 <<'PYTHON'
import os
import mlflow
from mlflow.tracking import MlflowClient
from mlflow.exceptions import RestException

mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
client = MlflowClient()
name = "heart-failure-classifier"

# Buscamos el experimento activo o eliminado.
exp = client.get_experiment_by_name(name)
if exp is not None and exp.lifecycle_stage == "deleted":
    client.restore_experiment(exp.experiment_id)
    print(f"    restaurado experimento previo {name}")
elif exp is None:
    print(f"    no existía, se creará al primer log")
else:
    print(f"    experimento {name} ya estaba activo")

# Modelo registrado: si existe, lo borramos para empezar versión 1 limpia.
try:
    client.delete_registered_model("heart-failure-clf")
    print("    modelo registrado anterior eliminado")
except RestException:
    pass
PYTHON
pausa

# ============================================================
# Paso 3 — Entrenar tres modelos
# ============================================================
paso "Paso 3 · Entrenar tres modelos y loguearlos en MLflow"
explica "Cada modelo genera un 'run' en MLflow con: params, métricas,"
explica "tags (commit, owner...), signature y el modelo serializado."
explica "Esto tarda 30-60 segundos por modelo."

run_cmd python src/train.py --model logreg
run_cmd python src/train.py --model rf
run_cmd python src/train.py --model xgb

echo ""
echo "    Abre ${C_BOLD}http://localhost:5050${C_RESET} y entra en el experimento"
echo "    'heart-failure-classifier'. Verás tres runs. Si marcas los tres y pulsas"
echo "    Compare, ves la comparación de hiperparámetros y métricas."
pausa

# ============================================================
# Paso 4 — Registrar el mejor
# ============================================================
paso "Paso 4 · Registrar el mejor en el Model Registry"
explica "El script busca el run con mayor f1 y lo registra como 'heart-failure-clf'."

run_cmd python src/register_best.py \
  --experiment heart-failure-classifier \
  --metric f1 \
  --name heart-failure-clf

echo ""
echo "    Vuelve a la UI de MLflow → pestaña 'Models' arriba a la derecha."
echo "    Verás 'heart-failure-clf' con la versión 1."
pausa

# ============================================================
# Paso 5 — Promocionar a Staging
# ============================================================
paso "Paso 5 · Promocionar la versión 1 a Staging"
explica "En el Registry, los modelos tienen 'stages' (None, Staging,"
explica "Production, Archived). Mover una versión a Staging es decir:"
explica "'lista para que la API de servicio la cargue'."

run_cmd python src/promote.py --name heart-failure-clf --version 1 --stage Staging

echo ""
echo "    Recarga la UI. El modelo heart-failure-clf v1 está en stage 'Staging'."
pausa

# ============================================================
# Paso 6 — Cargar el modelo desde Python
# ============================================================
paso "Paso 6 · Cargar el modelo desde el Registry (una línea Python)"
explica "Así es como lo cargará la API en el Lab 3."

python3 <<PYTHON
import os, mlflow.pyfunc
os.environ["MLFLOW_TRACKING_URI"] = "http://localhost:5050"
os.environ["MLFLOW_S3_ENDPOINT_URL"] = "http://localhost:9000"
os.environ["AWS_ACCESS_KEY_ID"] = "minio"
os.environ["AWS_SECRET_ACCESS_KEY"] = "minio12345"

m = mlflow.pyfunc.load_model("models:/heart-failure-clf/Staging")
print("")
print("    Modelo cargado correctamente")
print(f"    Run ID:   {m.metadata.run_id}")
if m.metadata.signature:
    n = len(m.metadata.signature.inputs.inputs)
    print(f"    Inputs:   {n} columnas esperadas")
PYTHON

echo ""
echo "    ${C_GREEN}✓ El modelo viaja con su esquema completo. Esto es${C_RESET}"
echo "    ${C_GREEN}  reproducibilidad: cualquiera puede cargarlo y saber${C_RESET}"
echo "    ${C_GREEN}  exactamente qué datos meter.${C_RESET}"
pausa

# ============================================================
# Cierre
# ============================================================
banner "LAB 2 COMPLETO"
echo ""
echo "  ${C_GREEN}Has hecho:${C_RESET}"
echo "    ✓ Entrenado 3 modelos con tracking automático en MLflow"
echo "    ✓ Comparado runs por métricas en la UI"
echo "    ✓ Registrado el mejor como 'heart-failure-clf'"
echo "    ✓ Promocionado a Staging"
echo "    ✓ Cargado el modelo con su signature desde Python"
echo ""
echo "  ${C_BOLD}Comprobaciones:${C_RESET}"
echo "    - http://localhost:5050  → experimento con 3 runs"
echo "    - Tab Models → heart-failure-clf v1 en Staging"
echo "    - El bucket 'mlflow' de MinIO tiene los artefactos"
echo ""
echo "  Cuando estés listo, ve al Lab 3:"
echo "    ${C_BOLD}cd ../lab3_serving && ./run.sh${C_RESET}"
echo ""
