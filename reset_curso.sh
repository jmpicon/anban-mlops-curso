#!/usr/bin/env bash
# reset_curso.sh — Limpia artefactos generados por los labs y empaqueta
# todo el curso en un único ZIP listo para repartir.
#
# Uso:
#   ./reset_curso.sh           # limpieza + ZIP (no toca Docker)
#   ./reset_curso.sh --docker  # además recrea los volúmenes Docker
#   ./reset_curso.sh --skip-pdf  # no regenera PDFs (más rápido)

set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

RESET_DOCKER=0
SKIP_PDF=0
for arg in "$@"; do
  case "$arg" in
    --docker|--all) RESET_DOCKER=1 ;;
    --skip-pdf)     SKIP_PDF=1 ;;
  esac
done

echo "==> Curso ANBAN — reset"
echo "    Carpeta raíz: $ROOT"
echo ""

# ---------------------------------------------------------------------------
# 1) Limpiar artefactos generados en cada lab
# ---------------------------------------------------------------------------
echo "[1/4] Limpiando artefactos de labs..."
for lab in labs/lab1_dataops labs/lab2_mlflow_dvc labs/lab3_serving labs/lab4_cicd_monitoring labs/lab5_e2e; do
  [ -d "$lab" ] || continue
  echo "      · $lab"
  rm -rf "$lab/.dvc" "$lab/.git" "$lab/.venv" "$lab/venv" 2>/dev/null || true
  rm -rf "$lab/data" "$lab/dvc.lock" "$lab/dvc.yaml" "$lab/.dvcignore" 2>/dev/null || true
  rm -rf "$lab/reports" 2>/dev/null || true
  find "$lab" -name '*.dvc' -delete 2>/dev/null || true
  find "$lab" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
  find "$lab" -name '*.pyc' -delete 2>/dev/null || true
done
rm -f labs/lab5_e2e/MODEL_CARD.md 2>/dev/null || true

# ---------------------------------------------------------------------------
# 2) Reset opcional de Docker
# ---------------------------------------------------------------------------
if [ "$RESET_DOCKER" = "1" ]; then
  echo ""
  echo "[2/4] Recreando contenedores Docker y volúmenes (pierdes BD y buckets)..."
  (cd docker && docker compose down -v && docker compose up -d)
else
  echo ""
  echo "[2/4] Saltado (sin --docker). Los volúmenes Docker se conservan."
fi

# ---------------------------------------------------------------------------
# 3) Regenerar PDFs (alumno y profesor)
# ---------------------------------------------------------------------------
if [ "$SKIP_PDF" = "0" ]; then
  echo ""
  echo "[3/4] Regenerando PDFs..."
  if [ -x material_alumno/build_pdfs.sh ]; then
    echo "      · material_alumno..."
    (cd material_alumno && ./build_pdfs.sh > /dev/null 2>&1) \
      || echo "      ! material_alumno PDF: revisa pandoc/weasyprint"
  fi
  if [ -x guion_profesor/build_pdfs.sh ]; then
    echo "      · guion_profesor..."
    (cd guion_profesor && ./build_pdfs.sh > /dev/null 2>&1) \
      || echo "      ! guion_profesor PDF: revisa pandoc/weasyprint"
  fi
else
  echo ""
  echo "[3/4] Saltado (--skip-pdf). Los PDFs existentes se conservan."
fi

# ---------------------------------------------------------------------------
# 4) Empaquetar el ZIP de la carpeta entera
# ---------------------------------------------------------------------------
echo ""
echo "[4/4] Empaquetando ZIP..."
CURSO_DIR="$(basename "$ROOT")"
CURSO_ZIP="$(dirname "$ROOT")/${CURSO_DIR}.zip"

rm -f "$CURSO_ZIP"
# Excluimos guion_profesor/ del ZIP de los alumnos.
# La carpeta sigue en Anbam-curso/ para el docente.
(cd "$(dirname "$ROOT")" && zip -rq "${CURSO_DIR}.zip" "$CURSO_DIR" \
  -x "*/.DS_Store" \
     "*/__pycache__/*" \
     "*/.ipynb_checkpoints/*" \
     "*/.venv/*" "*/venv/*" \
     "*/.git/*" \
     "*/.dvc/cache/*" \
     "*/guion_profesor/*" \
     "*/guion_profesor" \
     "*/Anbam-curso.zip")

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
echo ""
echo "=== Listo ==="
[ -f "$CURSO_ZIP" ] && echo "  ZIP: $CURSO_ZIP ($(du -h "$CURSO_ZIP" | cut -f1))"
echo ""
echo "Para repartir a los alumnos:"
echo "  1) Manda $CURSO_ZIP (correo, Drive, USB...)"
echo "  2) El alumno lo descomprime y lee EMPIEZA_AQUI.md"
echo ""
if [ "$RESET_DOCKER" = "1" ]; then
  echo "Docker: recreado con volúmenes vacíos."
else
  echo "Docker: intacto. Para resetear buckets/BD: $0 --docker"
fi
