#!/usr/bin/env bash
# run.sh — Lab 1 ASISTIDO. Te guía paso a paso, ejecuta los comandos
# y te explica lo que está haciendo. Tú solo lees y aprietas Enter.

set -uo pipefail
cd "$(dirname "$0")"

# ----- Colores -----
if [[ -t 1 ]]; then
  C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'
  C_BLUE=$'\033[1;34m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'; C_DIM=$'\033[2m'
else
  C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""; C_BOLD=""; C_RESET=""; C_DIM=""
fi

# ----- Helpers -----
banner() {
  echo ""
  echo "${C_BOLD}================================================${C_RESET}"
  echo "${C_BOLD}  $*${C_RESET}"
  echo "${C_BOLD}================================================${C_RESET}"
}

paso() {
  echo ""
  echo "${C_BLUE}${C_BOLD}>>> $*${C_RESET}"
}

explica() {
  echo "${C_DIM}    $*${C_RESET}"
}

run_cmd() {
  echo ""
  echo "    ${C_YELLOW}\$ $*${C_RESET}"
  echo ""
  if "$@"; then
    echo ""
    echo "    ${C_GREEN}✓ ok${C_RESET}"
  else
    echo ""
    echo "    ${C_RED}✗ falló${C_RESET}"
    exit 1
  fi
}

pausa() {
  echo ""
  echo "${C_DIM}    (Enter para continuar)${C_RESET}"
  read -r _
}

# ============================================================
banner "LAB 1 — DataOps con DVC"
echo ""
echo "  En este lab vas a:"
echo "    1. Crear un repo git nuevo."
echo "    2. Inicializar DVC dentro del repo."
echo "    3. Trackear un dataset (UCI Adult) con DVC."
echo "    4. Definir un pipeline declarativo (validar + preprocesar)."
echo "    5. Ejecutarlo y ver la magia."
echo "    6. Romper los datos a propósito para ver que DVC nos protege."
echo ""
echo "  El script va explicando lo que hace en cada paso."
echo "  Si quieres entender cada línea, está en el PDF del módulo 2."
pausa

# ============================================================
# Paso 0 — Limpieza previa por si quedó algo de una ejecución anterior
# ============================================================
paso "Paso 0 · Limpieza previa"
explica "Si ejecutaste este lab antes, vamos a borrar el estado anterior"
explica "para que empieces de cero (no afecta a ningún otro lab)."

if [ -d ".dvc" ] || [ -f "dvc.lock" ] || [ -d "data" ] || [ -d ".git" ]; then
  echo ""
  echo "    Encontré restos de una ejecución anterior. Los borro:"
  rm -rf .dvc .dvcignore dvc.lock data/raw data/processed 2>/dev/null || true
  # mantengo dvc.yaml y params.yaml porque son ficheros de partida del lab
  if [ -d ".git" ] && [ -f ".git/config" ]; then
    # solo borro el .git si lo creó este propio lab (no es el del repo padre)
    if grep -q "lab1_dataops" .git/config 2>/dev/null || true; then
      rm -rf .git
    fi
  fi
  echo "    ${C_GREEN}✓ limpio${C_RESET}"
else
  echo "    Nada que limpiar."
fi

mkdir -p data/raw data/processed
pausa

# ============================================================
# Paso 1 — Comprobar dependencias Python
# ============================================================
paso "Paso 1 · Comprobar que DVC y las librerías Python están instaladas"
explica "Las necesitamos para trackear datos y procesarlos."

# Comprueba todas las librerías a la vez (DVC + pandas + pyarrow + sklearn + pyyaml).
# Si falta cualquiera, instala el lote entero.
if ! python -c "import dvc, pandas, pyarrow, sklearn, yaml" >/dev/null 2>&1; then
  echo ""
  echo "    ${C_YELLOW}Faltan dependencias. Las instalo ahora.${C_RESET}"
  echo ""
  pip install --quiet "dvc[s3]==3.55.2" pandas pyarrow scikit-learn pyyaml \
    || { echo "    ${C_RED}✗ pip install falló${C_RESET}"; exit 1; }
fi

# Verifica que el ejecutable dvc esté en el PATH
if ! command -v dvc >/dev/null 2>&1; then
  echo "    ${C_RED}✗ dvc instalado pero no está en el PATH${C_RESET}"
  echo "    Activa tu virtualenv o reinstala: pip install \"dvc[s3]==3.55.2\""
  exit 1
fi

echo "    DVC: $(dvc --version)"
echo "    ${C_GREEN}✓ todo listo${C_RESET}"
pausa

# ============================================================
# Paso 2 — Inicializar Git
# ============================================================
paso "Paso 2 · Inicializar un repositorio Git"
explica "DVC vive DENTRO de Git. Sin Git no hay DVC."
run_cmd git init -q
run_cmd git config --local user.email "alumno@anban.es"
run_cmd git config --local user.name "Alumno ANBAN"

# Primer commit con lo que ya hay
git add -A 2>/dev/null || true
git commit -q -m "snapshot inicial" 2>/dev/null || true
echo "    ${C_GREEN}✓ commit inicial hecho${C_RESET}"
pausa

# ============================================================
# Paso 3 — Inicializar DVC
# ============================================================
paso "Paso 3 · Inicializar DVC"
explica "Esto crea la carpeta .dvc/ con la configuración mínima."
run_cmd dvc init -q
git add .dvc .dvcignore 2>/dev/null
git commit -q -m "inicializa dvc" 2>/dev/null || true
echo "    ${C_GREEN}✓ DVC dentro de Git${C_RESET}"
pausa

# ============================================================
# Paso 4 — Configurar el remoto MinIO
# ============================================================
paso "Paso 4 · Configurar MinIO como remoto de DVC"
explica "Los CSV pesados NO se guardan en Git, sino en MinIO."
explica "Git guarda solo un puntero (hash). MinIO guarda el blob real."
run_cmd dvc remote add -d minio s3://datasets/lab1
run_cmd dvc remote modify minio endpointurl http://localhost:9000

# las credenciales van en config local (NO commit)
dvc remote modify --local minio access_key_id minio >/dev/null
dvc remote modify --local minio secret_access_key minio12345 >/dev/null
echo "    credenciales puestas en .dvc/config.local (fuera de Git)"

git add .dvc/config 2>/dev/null
git commit -q -m "remoto minio configurado" 2>/dev/null || true
echo "    ${C_GREEN}✓ remoto MinIO listo${C_RESET}"
pausa

# ============================================================
# Paso 5 — Copiar el dataset
# ============================================================
paso "Paso 5 · Copiar el dataset UCI Adult"
explica "Es un CSV con datos de censo USA 1994. ~30K filas, 3.9 MB."

if [ -f "../../datasets/adult/adult.csv" ]; then
  cp ../../datasets/adult/adult.csv data/raw/adult.csv
  echo ""
  echo "    Dataset copiado desde el repo:"
  ls -lh data/raw/adult.csv
  echo "    ${C_GREEN}✓ ok${C_RESET}"
else
  echo "    ${C_RED}✗ no encuentro datasets/adult/adult.csv${C_RESET}"
  echo "    ${C_YELLOW}avisa al profesor.${C_RESET}"
  exit 1
fi
pausa

# ============================================================
# Paso 6 — Trackear con DVC
# ============================================================
paso "Paso 6 · Decirle a DVC que trackee el dataset"
explica "DVC calcula el hash, mueve el fichero a su caché interna,"
explica "y crea un puntero .dvc minúsculo que SÍ se commitea en Git."
run_cmd dvc add data/raw/adult.csv

echo ""
echo "    Mira los archivos que se han creado:"
ls -la data/raw/
echo ""
echo "    El puntero .dvc dice:"
cat data/raw/adult.csv.dvc | sed 's/^/      /'
echo ""
echo "    El .gitignore generado dice:"
cat data/raw/.gitignore | sed 's/^/      /'

git add data/raw/adult.csv.dvc data/raw/.gitignore 2>/dev/null
git commit -q -m "trackea dataset" 2>/dev/null || true
echo ""
echo "    ${C_GREEN}✓ dataset trackeado por DVC, no por Git${C_RESET}"
pausa

# ============================================================
# Paso 7 — Subir el blob a MinIO
# ============================================================
paso "Paso 7 · Subir el blob a MinIO (dvc push)"
explica "Ahora el dataset vive en dos sitios: en tu caché DVC local y en MinIO."
explica "Si te llevas el repo a otra máquina, con 'dvc pull' lo recuperas."
run_cmd dvc push

echo ""
echo "    Abre http://localhost:9001 en el navegador (minio / minio12345),"
echo "    entra al bucket 'datasets' y verás el blob con su hash de nombre."
pausa

# ============================================================
# Paso 8 — Ejecutar el pipeline
# ============================================================
paso "Paso 8 · Ejecutar el pipeline DVC (dvc repro)"
explica "El fichero dvc.yaml declara las stages: validar + preprocesar."
explica "DVC ejecuta solo las que tengan dependencias cambiadas."

if [ ! -f dvc.yaml ]; then
  cat > dvc.yaml <<'YAML'
stages:
  validate:
    cmd: python src/ge_validate.py data/raw/adult.csv
    deps:
      - data/raw/adult.csv
      - src/ge_validate.py
  preprocess:
    cmd: python src/preprocess.py
    deps:
      - data/raw/adult.csv
      - src/preprocess.py
      - params.yaml
    outs:
      - data/processed/train.parquet
      - data/processed/test.parquet
YAML
  echo "    Acabo de crear dvc.yaml. Si quieres mirarlo: cat dvc.yaml"
fi

if [ ! -f params.yaml ]; then
  cat > params.yaml <<'YAML'
preprocess:
  test_size: 0.2
  random_state: 42
  drop_columns: ["fnlwgt", "education"]
YAML
fi

run_cmd dvc repro

echo ""
echo "    Mira lo que se creó en data/processed/:"
ls -lh data/processed/
pausa

# ============================================================
# Paso 9 — Reproducir cuando NADA cambió
# ============================================================
paso "Paso 9 · Volver a ejecutar dvc repro"
explica "Esta vez DVC debe decir 'didn't change, skipping'."
explica "Es la caché por dependencias: ahorra horas en proyectos grandes."
run_cmd dvc repro
pausa

# ============================================================
# Paso 10 — Romper el dato a propósito
# ============================================================
paso "Paso 10 · Romper el dato a propósito (¡importante!)"
explica "Vamos a meter un valor inválido (age=200) en el CSV y ver"
explica "que la validación detecta el problema antes de procesar nada."

python3 -c "
with open('data/raw/adult.csv', 'r') as f:
    lines = f.readlines()
parts = lines[4].split(',')
parts[0] = '200'
lines[4] = ','.join(parts)
with open('data/raw/adult.csv', 'w') as f:
    f.writelines(lines)
print('    Línea 5 modificada: age=200')
"

echo ""
echo "    Ejecuto SOLO el validador (sin dvc repro) para ver el fallo:"
echo "    ${C_YELLOW}\$ python src/ge_validate.py data/raw/adult.csv${C_RESET}"
echo ""
set +e
python src/ge_validate.py data/raw/adult.csv
RC=$?
set -e
if [ $RC -ne 0 ]; then
  echo ""
  echo "    ${C_GREEN}✓ Esperado: el validador detectó el age fuera de rango.${C_RESET}"
  echo "    ${C_GREEN}  En un pipeline de CI esto pararía toda la promoción.${C_RESET}"
else
  echo ""
  echo "    ${C_YELLOW}!${C_RESET} El validador NO falló. Algo raro pasa."
fi
pausa

# ============================================================
# Paso 11 — Recuperar el dato bueno
# ============================================================
paso "Paso 11 · Recuperar el dato bueno"
explica "En un equipo real recuperaríamos del remoto (dvc pull) o del backup."
explica "Aquí, para que sea reproducible siempre, lo volvemos a copiar de"
explica "la fuente original y re-trackeamos con DVC."

run_cmd cp ../../datasets/adult/adult.csv data/raw/adult.csv
run_cmd dvc add data/raw/adult.csv
git add data/raw/adult.csv.dvc 2>/dev/null
git commit -q -m "restaura dataset original" 2>/dev/null || true

echo ""
echo "    Ahora dvc repro debe volver a pasar limpio:"
run_cmd dvc repro
pausa

# ============================================================
# Cierre
# ============================================================
banner "LAB 1 COMPLETO"
echo ""
echo "  ${C_GREEN}Has hecho:${C_RESET}"
echo "    ✓ Git + DVC inicializados"
echo "    ✓ Dataset trackeado por DVC y subido a MinIO"
echo "    ✓ Pipeline declarativo (validar + preprocesar)"
echo "    ✓ Vivido en directo qué pasa cuando los datos van mal"
echo ""
echo "  ${C_BOLD}Comprobaciones para tu cuenta:${C_RESET}"
echo "    - git log --oneline   → varios commits, ningún CSV pesado dentro"
echo "    - dvc status          → todo limpio"
echo "    - ls data/processed/  → train.parquet y test.parquet existen"
echo "    - http://localhost:9001 → el bucket 'datasets' tiene el blob"
echo ""
echo "  Cuando estés listo, ve al Lab 2:"
echo "    ${C_BOLD}cd ../lab2_mlflow_dvc && ./run.sh${C_RESET}"
echo ""
