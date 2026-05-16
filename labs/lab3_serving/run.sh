#!/usr/bin/env bash
# run.sh — Lab 3 ASISTIDO. Empaquetar el modelo y servirlo con FastAPI.

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

IMG="anban/income-api:lab3"
CONTAINER="anban-income-api"

# Detectar la red del stack: miramos en qué red está anban-mlflow.
detect_network() {
  docker inspect anban-mlflow --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null | head -1
}
NETWORK="$(detect_network)"
if [[ -z "$NETWORK" ]]; then
  NETWORK="docker_default"
fi

# ============================================================
banner "LAB 3 — Servir el modelo con FastAPI + Docker"
echo ""
echo "  En este lab vas a:"
echo "    1. Construir una imagen Docker con la API."
echo "    2. Lanzarla apuntando al modelo del Registry."
echo "    3. Probar /health, /version, /predict y /metrics."
echo "    4. Detener el contenedor."
pausa

# ============================================================
# Paso 0 — Prerrequisitos
# ============================================================
paso "Paso 0 · Comprobar prerrequisitos"
explica "Hace falta que el modelo income-clf esté en Staging."

if ! curl -fsS -m 5 -o /dev/null http://localhost:5050; then
  echo "    ${C_RED}✗ MLflow no responde${C_RESET}"
  exit 1
fi

STAGING=$(curl -fsS -m 5 "http://localhost:5050/api/2.0/mlflow/registered-models/get?name=income-clf" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    versions = d.get('registered_model', {}).get('latest_versions', [])
    for v in versions:
        if v.get('current_stage') == 'Staging':
            print(v['version']); break
except Exception:
    pass
")

if [[ -z "$STAGING" ]]; then
  echo "    ${C_RED}✗ No hay versión de income-clf en Staging${C_RESET}"
  echo "    Ejecuta primero:  cd ../lab2_mlflow_dvc && ./run.sh"
  exit 1
fi
echo "    ${C_GREEN}✓${C_RESET} income-clf v$STAGING está en Staging"

if ! docker info >/dev/null 2>&1; then
  echo "    ${C_RED}✗ Docker no responde${C_RESET}"
  exit 1
fi
echo "    ${C_GREEN}✓${C_RESET} Docker activo"
echo "    Red de Docker que usaremos: ${C_BOLD}$NETWORK${C_RESET}"
pausa

# ============================================================
# Paso 1 — Limpieza previa del contenedor
# ============================================================
paso "Paso 1 · Limpiar contenedor previo si existe"
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  echo "    contenedor previo eliminado"
else
  echo "    no había contenedor previo"
fi
pausa

# ============================================================
# Paso 2 — Construir la imagen
# ============================================================
paso "Paso 2 · Construir la imagen Docker"
explica "Multi-stage: builder instala deps, imagen final solo trae lo justo."
explica "La primera vez tarda 1-3 minutos. Las siguientes, segundos (caché)."

run_cmd docker build -t "$IMG" .
echo ""
echo "    Tamaño de la imagen:"
docker images "$IMG" --format "    {{.Repository}}:{{.Tag}}  {{.Size}}"
pausa

# ============================================================
# Paso 3 — Lanzar el contenedor
# ============================================================
paso "Paso 3 · Lanzar el contenedor"
explica "Lo conectamos a la red de Docker Compose para que vea MLflow y MinIO"
explica "por sus nombres internos (anban-mlflow:5000, anban-minio:9000)."

run_cmd docker run -d \
  --name "$CONTAINER" \
  --network "$NETWORK" \
  -p 8000:8000 \
  -e MLFLOW_TRACKING_URI=http://anban-mlflow:5000 \
  -e MLFLOW_S3_ENDPOINT_URL=http://anban-minio:9000 \
  -e AWS_ACCESS_KEY_ID=minio \
  -e AWS_SECRET_ACCESS_KEY=minio12345 \
  -e MODEL_URI=models:/income-clf/Staging \
  "$IMG"

echo "    Esperando a que la API arranque y cargue el modelo..."
echo ""

ready=0
for i in {1..40}; do
  if curl -fsS -m 2 -o /dev/null http://localhost:8000/health 2>/dev/null; then
    ready=1; break
  fi
  echo -n "."
  sleep 2
done
echo ""

if [ $ready -eq 0 ]; then
  echo "    ${C_RED}✗ La API no arrancó en 80 segundos${C_RESET}"
  echo "    Mira los logs:"
  echo "    docker logs $CONTAINER"
  exit 1
fi
echo "    ${C_GREEN}✓ API arriba en http://localhost:8000${C_RESET}"
pausa

# ============================================================
# Paso 4 — Health y versión
# ============================================================
paso "Paso 4 · Probar /health y /version"
explica "Estos endpoints los usaría un load balancer para saber si la"
explica "API está sana y qué versión del modelo está sirviendo."

echo ""
echo "    ${C_YELLOW}\$ curl -s http://localhost:8000/health${C_RESET}"
curl -s http://localhost:8000/health | python3 -m json.tool | sed 's/^/      /'

echo ""
echo "    ${C_YELLOW}\$ curl -s http://localhost:8000/version${C_RESET}"
curl -s http://localhost:8000/version | python3 -m json.tool | sed 's/^/      /'

echo ""
echo "    Fíjate en el campo 'model_uri'. Es la referencia lógica al"
echo "    Model Registry, NO una ruta de fichero. Si mañana promocionamos"
echo "    income-clf v2, esta URI no cambia."
pausa

# ============================================================
# Paso 5 — Predicción real
# ============================================================
paso "Paso 5 · Hacer una predicción"
explica "Mandamos un JSON con las features. La API valida con Pydantic,"
explica "alinea las columnas con el schema del modelo y devuelve label+proba."

cat > /tmp/anban_payload.json <<'JSON'
{
  "age": 39,
  "workclass": "State-gov",
  "education_num": 13,
  "marital_status": "Never-married",
  "occupation": "Adm-clerical",
  "relationship": "Not-in-family",
  "race": "White",
  "sex": "Male",
  "capital_gain": 2174,
  "capital_loss": 0,
  "hours_per_week": 40,
  "native_country": "United-States"
}
JSON

echo ""
echo "    Payload:"
cat /tmp/anban_payload.json | sed 's/^/      /'

echo ""
echo "    ${C_YELLOW}\$ curl -s -X POST http://localhost:8000/predict ...${C_RESET}"
echo ""
curl -s -X POST http://localhost:8000/predict \
  -H "content-type: application/json" \
  -d @/tmp/anban_payload.json | python3 -m json.tool | sed 's/^/      /'

echo ""
echo "    ${C_GREEN}✓ Predicción servida${C_RESET}"
pausa

# ============================================================
# Paso 6 — Validación de entrada
# ============================================================
paso "Paso 6 · Probar que la API rechaza entradas inválidas"
explica "Mandamos age=200 (Pydantic dice: ge=17, le=90). Debe devolver 422."

echo ""
echo "    ${C_YELLOW}\$ curl -s -X POST http://localhost:8000/predict (age=200)${C_RESET}"
echo ""
http_code=$(curl -s -o /tmp/anban_err.json -w "%{http_code}" -X POST http://localhost:8000/predict \
  -H "content-type: application/json" \
  -d '{"age":200,"workclass":"Private","education_num":10,"marital_status":"Single","occupation":"x","relationship":"x","race":"x","sex":"Male","capital_gain":0,"capital_loss":0,"hours_per_week":40,"native_country":"x"}')
echo "    HTTP $http_code"
cat /tmp/anban_err.json | python3 -m json.tool 2>/dev/null | head -8 | sed 's/^/      /'

if [[ "$http_code" == "422" ]]; then
  echo ""
  echo "    ${C_GREEN}✓ La API protegida por Pydantic. age=200 → 422${C_RESET}"
fi
pausa

# ============================================================
# Paso 7 — Métricas Prometheus
# ============================================================
paso "Paso 7 · Endpoint /metrics en formato Prometheus"
explica "Cualquier Prometheus puede hacer scraping de este endpoint."

echo ""
echo "    ${C_YELLOW}\$ curl -s http://localhost:8000/metrics${C_RESET}"
echo ""
curl -s http://localhost:8000/metrics | sed 's/^/      /'
pausa

# ============================================================
# Paso 8 — Documentación Swagger
# ============================================================
paso "Paso 8 · Swagger automático"
explica "FastAPI genera documentación interactiva sin que escribas nada."
echo ""
echo "    Abre en el navegador:"
echo "      ${C_BOLD}http://localhost:8000/docs${C_RESET}"
echo ""
echo "    Puedes probar /predict desde ahí (botón 'Try it out')."
pausa

# ============================================================
# Cierre
# ============================================================
banner "LAB 3 COMPLETO"
echo ""
echo "  ${C_GREEN}Has hecho:${C_RESET}"
echo "    ✓ Imagen Docker multi-stage construida"
echo "    ✓ Modelo cargado desde Model Registry en runtime"
echo "    ✓ Endpoints /health, /version, /predict, /metrics funcionando"
echo "    ✓ Validación Pydantic protegiendo la entrada"
echo "    ✓ Swagger en /docs"
echo ""
echo "  ${C_BOLD}El contenedor sigue arriba.${C_RESET}"
echo "  - Para verlo:      docker ps | grep $CONTAINER"
echo "  - Para pararlo:    docker stop $CONTAINER"
echo "  - Para los logs:   docker logs $CONTAINER"
echo ""
echo "  Cuando estés listo, ve al Lab 4:"
echo "    ${C_BOLD}cd ../lab4_cicd_monitoring && ./run.sh${C_RESET}"
echo ""
