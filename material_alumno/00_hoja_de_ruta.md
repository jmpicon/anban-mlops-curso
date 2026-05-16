---
title: "Hoja de ruta del curso"
subtitle: "Curso MLOps/DataOps · ANBAN"
author: "José Picón"
date: "2026"
---

# La hoja de ruta del curso, en 8 comandos

Esta es la única hoja que necesitas tener a mano. Imprime esta página
si quieres. Todo lo que vas a teclear durante los dos días está aquí.

## Los 8 comandos

```bash
# (1) Sólo la primera vez del día: arrancar el laboratorio
./setup.sh

# (2) DÍA 1 · mañana — DataOps con DVC
cd labs/lab1_dataops && ./run.sh

# (3) DÍA 1 · tarde — Tracking con MLflow
cd ../lab2_mlflow_dvc && ./run.sh

# (4) DÍA 2 · mañana — Servir el modelo (FastAPI + Docker)
cd ../lab3_serving && ./run.sh

# (5) DÍA 2 · tarde — CI/CD y detección de drift
cd ../lab4_cicd_monitoring && ./run.sh

# (6) CIERRE — caso end-to-end y Model Card
cd ../lab5_e2e && ./run.sh

# (7) Al terminar la sesión, parar Docker
cd ../.. && ./shutdown.sh

# (8) Al día siguiente, volver a empezar
./setup.sh
```

Si **algo se rompe** en cualquier momento:

```bash
./doctor.sh
```

> En Windows nativo (sin WSL), reemplaza `./setup.sh` por `.\setup.ps1`
> y `./run.sh` por `.\run.ps1`. En todo lo demás, igual.

\newpage

# Qué hace cada lab

Cada lab tiene un script `run.sh` (o `run.ps1` en Windows nativo) que
te va guiando paso a paso. Tú solo pulsas Enter y lees lo que sale en
pantalla.

| Lab | Tiempo | Qué aprendes |
|-----|--------|--------------|
| Lab 1 — DataOps con DVC | 40-50 min | Versionar datasets, pipeline reproducible, detectar datos rotos |
| Lab 2 — MLflow Tracking | 50 min | Entrenar 3 modelos, comparar y promocionar el mejor |
| Lab 3 — Serving | 40 min | Empaquetar el modelo como API REST con Docker |
| Lab 4 — CI/CD + Drift | 50 min | Promoción condicional y detección de drift en producción |
| Lab 5 — End-to-end | 45 min | Recorrido completo y generación de Model Card |

# Tres URLs que deben funcionar tras `./setup.sh`

Si abres estos tres enlaces en el navegador y los tres responden,
estás dentro del curso:

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| Jupyter | http://localhost:8888 | token: `anban` |
| MLflow | http://localhost:5050 | — |
| MinIO (consola) | http://localhost:9001 | `minio` / `minio12345` |

Si alguno no responde:

1. Espera 30 segundos y prueba de nuevo (a veces tarda en arrancar).
2. Si sigue sin ir, ejecuta `./doctor.sh`.
3. Comparte la salida con tu profesor si no entiendes el mensaje.

# Reglas de oro para no atascarse

1. **No te saltes el orden.** Cada lab depende del anterior. Lab 2
   necesita los parquet del Lab 1. Lab 3 necesita el modelo del Lab 2.
   Etc.
2. **Lee lo que sale en pantalla.** No es ruido: cada bloque explica
   qué está pasando y por qué importa.
3. **Si te atascas, `./doctor.sh`.** Está hecho exactamente para esto.
4. **Al terminar la sesión, `./shutdown.sh`.** Si dejas Docker abierto
   sin necesidad, te come batería y RAM.

# Dónde buscar más detalle de cada paso

Si quieres entender la teoría o el porqué de cada comando que ejecutas
con `./run.sh`:

- **Lab 1:** `material_alumno/02_dataops_dvc_ge.pdf`
- **Lab 2:** `material_alumno/03_mlflow_tracking.pdf`
- **Lab 3:** `material_alumno/04_serving_fastapi.pdf`
- **Lab 4:** `material_alumno/05_cicd_drift.pdf`
- **Lab 5:** `material_alumno/06_governance_e2e.pdf`

Y para la chuleta de comandos, `material_alumno/cheatsheet_comandos.pdf`.
