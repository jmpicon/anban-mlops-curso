#!/usr/bin/env bash
# setup.sh — Bootstrap del laboratorio del curso ANBAN MLOps/DataOps.
# Comprueba dependencias, descarga imágenes y levanta el stack.
# Pensado para Linux, macOS y WSL. Para Windows nativo: setup.ps1.

set -uo pipefail

# ----- Colores -----
if [[ -t 1 ]]; then
  C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'
  C_BLUE=$'\033[1;34m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""; C_BOLD=""; C_RESET=""
fi

ok()    { echo "  ${C_GREEN}✓${C_RESET} $*"; }
info()  { echo "  ${C_BLUE}·${C_RESET} $*"; }
warn()  { echo "  ${C_YELLOW}!${C_RESET} $*"; }
fail()  { echo "  ${C_RED}✗${C_RESET} $*"; }
step()  { echo ""; echo "${C_BOLD}$*${C_RESET}"; }

abort() {
  echo ""
  fail "$*"
  echo ""
  echo "Si no sabes cómo arreglarlo, ejecuta:"
  echo "    ${C_BOLD}./doctor.sh${C_RESET}"
  echo "y comparte la salida con tu profesor."
  exit 1
}

cd "$(dirname "$0")"

echo ""
echo "${C_BOLD}================================================${C_RESET}"
echo "${C_BOLD}  ANBAN · Setup del laboratorio MLOps/DataOps${C_RESET}"
echo "${C_BOLD}================================================${C_RESET}"

# ============================================================
# 1. Comprobar Docker
# ============================================================
step "1. Comprobando Docker"

if ! command -v docker >/dev/null 2>&1; then
  abort "Docker no está instalado o no está en el PATH.
        Instálalo siguiendo el apéndice A de EMPIEZA_AQUI.md"
fi
ok "Docker encontrado: $(docker --version)"

if ! docker info >/dev/null 2>&1; then
  abort "Docker está instalado pero no responde.
        En Windows/Mac: abre Docker Desktop y espera a que la ballena se quede fija.
        En Linux: sudo systemctl start docker"
fi
ok "El motor de Docker está activo"

if ! docker compose version >/dev/null 2>&1; then
  abort "No se encuentra 'docker compose' (v2).
        Actualiza Docker Desktop o instala docker-compose-plugin."
fi
ok "Docker Compose: $(docker compose version --short 2>/dev/null || echo v2)"

# ============================================================
# 2. Descargar imágenes con reintentos
# ============================================================
step "2. Descargando las imágenes del curso"
info "Es normal que la primera vez tarde 5-10 minutos."

IMAGES=(
  "postgres:16-alpine"
  "minio/minio:RELEASE.2024-10-13T13-34-11Z"
  "minio/mc:RELEASE.2024-10-08T09-37-26Z"
  "ghcr.io/mlflow/mlflow:v2.17.2"
  "jupyter/scipy-notebook:python-3.11"
)

pull_with_retry() {
  local image="$1"
  local attempts=3
  local i
  for i in $(seq 1 $attempts); do
    if docker pull "$image" >/dev/null 2>&1; then
      ok "$image"
      return 0
    fi
    warn "Intento $i/$attempts falló para $image. Reintentando en 5s..."
    sleep 5
  done
  return 1
}

for img in "${IMAGES[@]}"; do
  info "Descargando $img"
  if ! pull_with_retry "$img"; then
    abort "No he podido descargar $img tras 3 intentos.
        Posibles causas:
          - Sin conexión a internet.
          - Tu red/empresa bloquea Docker Hub o GHCR.
          - Docker Desktop atascado (cierra y abre de nuevo).
        Ejecuta ./doctor.sh para más detalle."
  fi
done

# ============================================================
# 3. Levantar el stack
# ============================================================
step "3. Levantando los servicios"

cd docker
if ! docker compose up -d 2>&1 | sed 's/^/    /'; then
  cd ..
  abort "Fallo al lanzar docker compose. Mira el mensaje anterior."
fi
cd ..
ok "docker compose up -d lanzado"

# ============================================================
# 4. Esperar a que los servicios respondan
# ============================================================
step "4. Esperando a que los servicios estén listos"

wait_for_http() {
  local name="$1"
  local url="$2"
  local timeout=120
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    if curl -fsS -o /dev/null -m 3 "$url" 2>/dev/null; then
      ok "$name listo"
      return 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
    if (( elapsed % 15 == 0 )); then
      info "Aún esperando a $name... ($elapsed s)"
    fi
  done
  return 1
}

wait_for_http "MinIO API"   "http://localhost:9000/minio/health/live" \
  || warn "MinIO no respondió a tiempo, pero puede estar arrancando."

wait_for_http "MLflow"      "http://localhost:5050" \
  || warn "MLflow no respondió a tiempo. Espera un par de minutos más y prueba a abrir http://localhost:5050"

wait_for_http "Jupyter"     "http://localhost:8888" \
  || warn "Jupyter no respondió a tiempo. Espera un minuto más y prueba a abrir http://localhost:8888"

# ============================================================
# 5. Resumen final
# ============================================================
echo ""
echo "${C_BOLD}================================================${C_RESET}"
echo "${C_GREEN}${C_BOLD}  LISTO. Abre estos enlaces en tu navegador:${C_RESET}"
echo "${C_BOLD}================================================${C_RESET}"
echo ""
echo "  ${C_BOLD}Jupyter${C_RESET}   : http://localhost:8888   (token: anban)"
echo "  ${C_BOLD}MLflow${C_RESET}    : http://localhost:5050"
echo "  ${C_BOLD}MinIO UI${C_RESET}  : http://localhost:9001   (minio / minio12345)"
echo ""
echo "  Para hacer el Lab 1, ejecuta:"
echo "      ${C_BOLD}cd labs/lab1_dataops && ./run.sh${C_RESET}"
echo ""
echo "  Si algo no va, ejecuta:"
echo "      ${C_BOLD}./doctor.sh${C_RESET}"
echo ""
echo "${C_BOLD}================================================${C_RESET}"
