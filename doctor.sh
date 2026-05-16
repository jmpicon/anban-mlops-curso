#!/usr/bin/env bash
# doctor.sh — Diagnóstico de problemas comunes del laboratorio.
# No arregla nada por su cuenta; te dice qué está mal y qué hacer.

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
step()  { echo ""; echo "${C_BOLD}— $* —${C_RESET}"; }
fixit() { echo "    ${C_YELLOW}arreglo:${C_RESET} $*"; }

cd "$(dirname "$0")"

problems=0

echo ""
echo "${C_BOLD}================================================${C_RESET}"
echo "${C_BOLD}  Diagnóstico del laboratorio ANBAN${C_RESET}"
echo "${C_BOLD}================================================${C_RESET}"

# ---------- Sistema ----------
step "Sistema"
info "Sistema operativo: $(uname -s) $(uname -r)"
if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null; then
  info "Estás en WSL (Linux dentro de Windows)"
  if [[ "$PWD" == /mnt/c/* ]] || [[ "$PWD" == /mnt/d/* ]]; then
    warn "Estás trabajando en /mnt/c/ ó /mnt/d/. Esto va MUY lento con Docker."
    fixit "mueve el repo a tu home de Linux: cp -r \"$PWD\" ~/Anbam-alumno && cd ~/Anbam-alumno"
    problems=$((problems+1))
  fi
fi

# ---------- Docker instalado ----------
step "Docker instalado"
if command -v docker >/dev/null 2>&1; then
  ok "docker encontrado: $(docker --version)"
else
  fail "docker no encontrado en el PATH"
  fixit "instala Docker Desktop (mac/win) o docker.io (linux) según el apéndice A de EMPIEZA_AQUI.md"
  problems=$((problems+1))
fi

# ---------- Docker funcionando ----------
step "Motor de Docker activo"
if docker info >/dev/null 2>&1; then
  ok "el motor responde"
else
  fail "docker está instalado pero no responde"
  fixit "Mac/Win: abre Docker Desktop y espera a que la ballena se quede fija (no animada)"
  fixit "Linux: sudo systemctl start docker"
  problems=$((problems+1))
fi

# ---------- Docker compose v2 ----------
step "Docker Compose v2"
if docker compose version >/dev/null 2>&1; then
  ok "docker compose disponible"
else
  fail "no se encuentra 'docker compose'"
  fixit "actualiza Docker Desktop o instala docker-compose-plugin"
  problems=$((problems+1))
fi

# ---------- Acceso a registries ----------
step "Acceso a registries (Docker Hub, GHCR)"
# La API /v2/ devuelve 401 sin auth pero significa que el host responde.
http_ok() {
  local url="$1"
  local code
  code=$(curl -fsS -o /dev/null -m 5 -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  # cualquier código >= 100 (servidor respondió) cuenta como accesible
  [[ "$code" != "000" ]]
}
if http_ok "https://registry-1.docker.io/v2/" || http_ok "https://hub.docker.com"; then
  ok "Docker Hub accesible"
else
  fail "no llego a Docker Hub"
  fixit "comprueba conexión a internet o proxy de empresa (debes permitir *.docker.io)"
  problems=$((problems+1))
fi

if http_ok "https://ghcr.io"; then
  ok "GHCR (GitHub Container Registry) accesible"
else
  fail "no llego a ghcr.io"
  fixit "tu red bloquea ghcr.io. Pide a IT que abra *.ghcr.io"
  problems=$((problems+1))
fi

# ---------- Puertos libres ----------
step "Puertos del laboratorio"
ports=(5050 5432 8888 9000 9001)

# detecta si un puerto está publicado por algún contenedor del curso
# (soporta tanto "0.0.0.0:9000->9000/tcp" como rangos "0.0.0.0:9000-9001->9000-9001/tcp")
port_in_docker() {
  local p="$1"
  local ports_blob
  ports_blob=$(docker ps --format '{{.Ports}}' 2>/dev/null | tr ',' '\n')
  # extrae los X o X-Y que aparecen antes de "->"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # pilla la parte "NUMERO" o "NUMERO-NUMERO" antes de ->
    local mapping
    mapping=$(echo "$line" | sed -nE 's/.*:([0-9]+(-[0-9]+)?)->.*/\1/p')
    [[ -z "$mapping" ]] && continue
    if [[ "$mapping" == *-* ]]; then
      local start="${mapping%-*}"
      local end="${mapping##*-}"
      if (( p >= start && p <= end )); then return 0; fi
    else
      if (( p == mapping )); then return 0; fi
    fi
  done <<< "$ports_blob"
  return 1
}

for p in "${ports[@]}"; do
  in_use=0
  if ss -tln 2>/dev/null | awk '{print $4}' | grep -qE ":${p}\$"; then
    in_use=1
  elif command -v lsof >/dev/null && lsof -iTCP:${p} -sTCP:LISTEN >/dev/null 2>&1; then
    in_use=1
  fi
  if [[ $in_use -eq 1 ]]; then
    if port_in_docker "$p"; then
      ok "puerto $p ocupado por un contenedor del curso"
    else
      warn "puerto $p ocupado por otro proceso"
      fixit "cierra la aplicación que lo usa o cambia el puerto en docker-compose.yml"
      problems=$((problems+1))
    fi
  else
    ok "puerto $p libre"
  fi
done

# ---------- Contenedores del curso ----------
step "Contenedores del curso"
for c in anban-postgres anban-minio anban-mlflow anban-jupyter; do
  status=$(docker ps -a --filter "name=^${c}$" --format '{{.Status}}' 2>/dev/null)
  if [[ -z "$status" ]]; then
    fail "$c no existe"
    fixit "ejecuta: ./setup.sh"
    problems=$((problems+1))
  elif echo "$status" | grep -qi "^up"; then
    ok "$c arriba ($status)"
  else
    warn "$c existe pero NO está arriba ($status)"
    fixit "ejecuta: cd docker && docker compose up -d"
    problems=$((problems+1))
  fi
done

# minio-init es one-shot: tiene que estar Exited (0)
status=$(docker ps -a --filter "name=^anban-minio-init$" --format '{{.Status}}' 2>/dev/null)
if echo "$status" | grep -qi "exited (0)"; then
  ok "anban-minio-init terminó correctamente"
elif [[ -n "$status" ]]; then
  warn "anban-minio-init: $status (esperado 'Exited (0)')"
fi

# ---------- HTTP de los servicios ----------
step "Servicios HTTP del laboratorio"
check_http() {
  local name="$1"; local url="$2"
  if curl -fsS -m 5 -o /dev/null "$url" 2>/dev/null; then
    ok "$name responde en $url"
  else
    fail "$name no responde en $url"
    fixit "espera 30 segundos y vuelve a probar; si sigue, ./setup.sh"
    problems=$((problems+1))
  fi
}
check_http "Jupyter"   "http://localhost:8888"
check_http "MLflow"    "http://localhost:5050"
check_http "MinIO API" "http://localhost:9000/minio/health/live"
check_http "MinIO UI"  "http://localhost:9001"

# ---------- Espacio en disco ----------
step "Espacio en disco"
avail=$(df -BG "$PWD" 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}')
if [[ -n "$avail" ]]; then
  if (( avail < 5 )); then
    fail "solo te quedan ${avail}G libres; el curso necesita al menos 10G"
    fixit "libera espacio: docker system prune -a -f"
    problems=$((problems+1))
  else
    ok "${avail}G disponibles"
  fi
fi

# ---------- Resumen ----------
echo ""
echo "${C_BOLD}================================================${C_RESET}"
if [[ $problems -eq 0 ]]; then
  echo "${C_GREEN}${C_BOLD}  Todo en orden. No hay problemas detectados.${C_RESET}"
else
  echo "${C_YELLOW}${C_BOLD}  Detectados $problems problemas. Mira arriba el${C_RESET}"
  echo "${C_YELLOW}${C_BOLD}  detalle y aplica los 'arreglo:'.${C_RESET}"
fi
echo "${C_BOLD}================================================${C_RESET}"
echo ""
