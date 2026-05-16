#!/usr/bin/env bash
# Compila el manual completo del curso en un único PDF:
# portada + día 1 (módulos 1-3 + labs 1-2) + día 2 (módulos 4-6 + labs 3-5) + cheatsheet.
#
# Requiere: pandoc + weasyprint.

set -euo pipefail

cd "$(dirname "$0")"

CSS="assets/pdf.css"
OUTDIR="pdf"
mkdir -p "$OUTDIR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LABS="../labs"

strip_yaml() {
  # Elimina el primer bloque YAML front matter (--- ... ---) de un .md.
  awk 'BEGIN{drop=0} NR==1 && /^---$/ {drop=1; next} drop==1 && /^---$/ {drop=0; next} drop==0 {print}' "$1"
}

{
  # Portada (con YAML front matter — lo usaremos como metadatos globales).
  cat cover.md
  printf "\n\n"

  # Instalación por sistema operativo
  cat 00_instalacion_plataformas.md
  printf "\n\n"

  # Conceptos con ejemplos (lectura previa recomendable)
  cat 01b_conceptos_con_ejemplos.md
  printf "\n\n"

  # DÍA 1
  cat dia1_intro.md
  printf "\n\n"
  strip_yaml 01_introduccion_mlops.md
  printf "\n\n"
  strip_yaml 02_dataops_dvc_ge.md
  printf "\n\n"
  cat "$LABS/lab1_dataops/README.md"
  printf "\n\n"
  strip_yaml 03_mlflow_tracking.md
  printf "\n\n"
  cat "$LABS/lab2_mlflow_dvc/README.md"
  printf "\n\n"

  # DÍA 2
  cat dia2_intro.md
  printf "\n\n"
  strip_yaml 04_serving_fastapi.md
  printf "\n\n"
  cat "$LABS/lab3_serving/README.md"
  printf "\n\n"
  strip_yaml 05_cicd_drift.md
  printf "\n\n"
  cat "$LABS/lab4_cicd_monitoring/README.md"
  printf "\n\n"
  strip_yaml 06_governance_e2e.md
  printf "\n\n"
  cat "$LABS/lab5_e2e/README.md"
  printf "\n\n"

  # Guía paso a paso con explicaciones (acompaña a los labs)
  cat 03b_guia_paso_a_paso_labs.md
  printf "\n\n"

  # Cheatsheet
  strip_yaml cheatsheet_comandos.md
  printf "\n\n"

  # Troubleshooting
  cat 99_troubleshooting.md

} > "$TMP/curso_completo.md"

echo "Compilando curso completo..."
pandoc "$TMP/curso_completo.md" \
  --from markdown \
  --to html5 \
  --standalone \
  --css "$CSS" \
  --metadata lang=es \
  --highlight-style tango \
  --toc --toc-depth=2 \
  --pdf-engine=weasyprint \
  -o "$OUTDIR/curso_completo_dias.pdf"

echo ""
echo "Listo. PDF generado:"
ls -lh "$OUTDIR/curso_completo_dias.pdf"
