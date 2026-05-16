#!/usr/bin/env bash
# Genera los PDFs del material del alumno a partir de los .md.
# Requiere: pandoc + weasyprint.

set -euo pipefail

cd "$(dirname "$0")"

CSS="assets/pdf.css"
OUTDIR="pdf"
mkdir -p "$OUTDIR"

MD_FILES=(
  "00_hoja_de_ruta.md"
  "00_instalacion_plataformas.md"
  "01_introduccion_mlops.md"
  "02_dataops_dvc_ge.md"
  "03_mlflow_tracking.md"
  "04_serving_fastapi.md"
  "05_cicd_drift.md"
  "06_governance_e2e.md"
  "cheatsheet_comandos.md"
)

build_one() {
  local src="$1"
  local out="$OUTDIR/${src%.md}.pdf"
  echo "  -> $src"
  pandoc "$src" \
    --from markdown \
    --to html5 \
    --standalone \
    --css "$CSS" \
    --metadata lang=es \
    --highlight-style tango \
    --pdf-engine=weasyprint \
    -o "$out"
}

echo "Compilando módulos individuales..."
for f in "${MD_FILES[@]}"; do
  build_one "$f"
done

echo "Compilando cuadernillo completo..."
pandoc \
  00_hoja_de_ruta.md \
  00_instalacion_plataformas.md \
  01_introduccion_mlops.md \
  02_dataops_dvc_ge.md \
  03_mlflow_tracking.md \
  04_serving_fastapi.md \
  05_cicd_drift.md \
  06_governance_e2e.md \
  cheatsheet_comandos.md \
  --from markdown \
  --to html5 \
  --standalone \
  --css "$CSS" \
  --metadata lang=es \
  --metadata title="Curso MLOps / DataOps" \
  --metadata subtitle="Manual completo del alumno · ANBAN" \
  --metadata author="José Picón" \
  --metadata date="2026" \
  --highlight-style tango \
  --toc --toc-depth=2 \
  --pdf-engine=weasyprint \
  -o "$OUTDIR/cuadernillo_completo.pdf"

echo ""
echo "Listo. PDFs generados en $OUTDIR/:"
ls -lh "$OUTDIR/"
