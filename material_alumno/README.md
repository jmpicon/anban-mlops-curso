# Material del alumno · Curso MLOps/DataOps ANBAN

Este directorio contiene los manuales del alumno en Markdown y los PDFs
ya compilados para repartir.

## Estructura

```
material_alumno/
├── 01_introduccion_mlops.md         # Día 1, módulo 1
├── 02_dataops_dvc_ge.md             # Día 1, módulo 2 (lab 1)
├── 03_mlflow_tracking.md            # Día 1, módulo 3 (lab 2)
├── 04_serving_fastapi.md            # Día 2, módulo 4 (lab 3)
├── 05_cicd_drift.md                 # Día 2, módulo 5 (lab 4)
├── 06_governance_e2e.md             # Día 2, módulo 6 (lab 5)
├── cheatsheet_comandos.md           # Chuleta para los dos días
├── build_pdfs.sh                    # Script para regenerar PDFs
├── assets/
│   └── pdf.css                      # Hoja de estilos del PDF
└── pdf/                             # PDFs generados
    ├── 01_introduccion_mlops.pdf
    ├── 02_dataops_dvc_ge.pdf
    ├── 03_mlflow_tracking.pdf
    ├── 04_serving_fastapi.pdf
    ├── 05_cicd_drift.pdf
    ├── 06_governance_e2e.pdf
    ├── cheatsheet_comandos.pdf
    └── cuadernillo_completo.pdf     # Todo en uno
```

## Regenerar los PDFs

```bash
cd material_alumno
./build_pdfs.sh
```

Requiere `pandoc` y `weasyprint` instalados.

## Filosofía del material

- **Teoría justa, práctica abundante.** Cada módulo es un 30% de lectura
  y un 70% de ejercicio.
- **Reproducible.** Cualquier alumno puede repetir los labs en casa, en
  su portátil, sin más infraestructura que Docker.
- **Castellano natural.** Sin jergas innecesarias, sin formalismos.

## Para entregar

Yo reparto los PDFs el día del módulo correspondiente, no antes:

- **Día 1, inicio:** PDF módulos 1, 2 y 3 + cheatsheet.
- **Día 2, inicio:** PDF módulos 4, 5 y 6.
- **Al final del curso:** entrego el `cuadernillo_completo.pdf` por si
  quieren tenerlo todo junto.
