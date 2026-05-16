# Curso MLOps / DataOps — ANBAN

Material completo del curso. La carpeta `guion_profesor/` es de uso
docente y **NO se incluye en el ZIP** que se reparte a los alumnos
(el script `reset_curso.sh` la excluye automáticamente). El resto es
exactamente lo que el alumno recibe.

## Por dónde empezar

**Si es tu primera vez:** lee `EMPIEZA_AQUI.md`. Te lleva de la mano
hasta tener el laboratorio levantado en 5 minutos.

## Estructura

```
Anbam-curso/
├── EMPIEZA_AQUI.md          ← lee esto primero
├── setup.sh / setup.ps1     ← arranca el laboratorio (1 comando)
├── doctor.sh / doctor.ps1   ← si algo falla, diagnóstico automático
├── shutdown.sh              ← parar el laboratorio sin perder datos
├── reset_curso.sh           ← regenerar el ZIP para repartir
│
├── docker/                  ← docker-compose del stack
├── datasets/adult/          ← dataset semilla del curso
│
├── slides/                  ← PPTX de las dos sesiones (Día 1, Día 2)
├── guion_profesor/          ← uso docente, NO se reparte (excluido del ZIP)
├── material_alumno/         ← manuales por módulo (.md + PDF)
│
├── labs/
│   ├── lab1_dataops/        ← DVC + validación
│   ├── lab2_mlflow_dvc/     ← Tracking + Model Registry
│   ├── lab3_serving/        ← FastAPI + Docker
│   ├── lab4_cicd_monitoring/← CI/CD + Drift
│   └── lab5_e2e/            ← caso end-to-end + Model Card
│
└── docs/                    ← cheatsheet y glosario
```

Cada lab tiene un **`run.sh`** (Linux/macOS/WSL) y un **`run.ps1`**
(Windows nativo) que lo ejecutan paso a paso explicando lo que hacen.

## El flujo del curso

### Día 1 (4 horas)

| Bloque | Material |
|--------|----------|
| Introducción a MLOps/DataOps | slides 1-18 + `guion_profesor/01_modulo1_intro.md` |
| DataOps con DVC | slides 19-32 + `labs/lab1_dataops/run.sh` |
| Tracking con MLflow | slides 33-46 + `labs/lab2_mlflow_dvc/run.sh` |

### Día 2 (4 horas)

| Bloque | Material |
|--------|----------|
| Serving con FastAPI + Docker | slides 47-60 + `labs/lab3_serving/run.sh` |
| CI/CD + Drift | slides 61-76 + `labs/lab4_cicd_monitoring/run.sh` |
| Caso end-to-end + Model Card | slides 77-90 + `labs/lab5_e2e/run.sh` |

## Servicios del laboratorio

Tras `./setup.sh`:

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| Jupyter | http://localhost:8888 | token `anban` |
| MLflow | http://localhost:5050 | — |
| MinIO (consola) | http://localhost:9001 | `minio` / `minio12345` |
| MinIO (S3) | http://localhost:9000 | — |
| PostgreSQL | localhost:5432 | `mlflow` / `mlflow` |

## Regenerar el ZIP para repartir

Cuando edites el material:

```bash
./reset_curso.sh
```

Genera `Anbam-curso.zip` junto a la carpeta. Es el fichero que repartes
a los alumnos.

## Buenas prácticas en clase

1. **Antes de empezar la clase:** ejecuta `./setup.sh` la noche anterior
   y deja la ballena de Docker fija. Llega 30 minutos antes para
   comprobar que sigue arriba.

2. **Si un alumno se atasca:** lo primero, `./doctor.sh`. Detecta el
   90% de los problemas comunes.

3. **Si pierdes el estado del Registry o de DVC:** `./reset_curso.sh
   --docker` recrea los volúmenes Docker desde cero.

4. **Para la siguiente edición del curso:** edita el `guion_profesor/`
   con lo que aprendas en aula y vuelve a generar los PDFs con
   `cd guion_profesor && ./build_pdfs.sh`.

## Licencia

Material docente. José Picón · ANBAN.
