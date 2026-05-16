# Lab 3 — FastAPI + Docker para servir el modelo

> Tiempo estimado: **40 min**

## Objetivo

Exponer el modelo `heart-failure-clf@Staging` como una API REST en contenedor con
endpoints documentados, validación de input y benchmarking básico.

## Arquitectura

```
[ cliente ]  →  [ FastAPI :8000 ]  →  carga modelo desde MLflow Registry
                       │
                       ├── /predict   (POST)
                       ├── /health    (GET)
                       ├── /version   (GET)
                       └── /metrics   (GET, prometheus)
```

## Ejecución local (sin Docker)

```bash
export MLFLOW_TRACKING_URI=http://localhost:5000
export MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=minio
export AWS_SECRET_ACCESS_KEY=minio12345
export MODEL_URI=models:/heart-failure-clf/Staging

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Abre [http://localhost:8000/docs](http://localhost:8000/docs) → Swagger interactivo.

## Probar la API

```bash
curl -s http://localhost:8000/health | jq

curl -s -X POST http://localhost:8000/predict \
  -H 'content-type: application/json' \
  -d '{
    "age": 39,
    "anaemia": 0, "creatinine_phosphokinase": 582,
    "education_num": 13,
    "marital_status": "Never-married",
    "occupation": "Adm-clerical",
    "relationship": "Not-in-family",
    "race": "White",
    "sex": "Male",
    "high_blood_pressure": 1, "platelets": 265000,
    "capital_loss": 0,
    "hours_per_week": 40,
    "native_country": "United-States"
  }' | jq
```

## Construir la imagen

```bash
docker build -t anban/income-api:0.1 -f Dockerfile .
docker run --rm -p 8000:8000 \
  -e MLFLOW_TRACKING_URI=http://host.docker.internal:5000 \
  -e MODEL_URI=models:/heart-failure-clf/Staging \
  anban/income-api:0.1
```

> En Linux puro reemplaza `host.docker.internal` por la IP del host
> o usa la red `host` de Docker.

## Stress test con Locust

```bash
locust -f tests/locustfile.py --host http://localhost:8000 \
       --users 50 --spawn-rate 10 --run-time 1m --headless
```

Aprobamos si:
- p95 latency < 100ms
- 0 fallos
- RPS sostenido > 200

## Comprobaciones de cierre

- [ ] `/health` responde en < 50ms.
- [ ] `/version` devuelve `model_uri`, `run_id` y `signature`.
- [ ] `/predict` valida input (Pydantic) y devuelve `label` + `proba`.
- [ ] Imagen final < 350MB (`docker images`).
- [ ] Locust cumple SLA.

## Reto opcional

Añade `/predict/batch` que acepte una lista de hasta 1000 registros y
hace un único `model.predict_batch`.
