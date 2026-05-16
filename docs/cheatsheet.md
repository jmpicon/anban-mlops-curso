# Cheatsheet · MLOps/DataOps · ANBAN

## Docker compose

```bash
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml ps
docker compose -f docker/docker-compose.yml logs -f mlflow
docker compose -f docker/docker-compose.yml down -v   # ⚠ borra volúmenes
```

## DVC

```bash
dvc init
dvc remote add -d minio s3://datasets
dvc remote modify minio endpointurl http://localhost:9000
dvc remote modify --local minio access_key_id minio
dvc remote modify --local minio secret_access_key minio12345

dvc add data/raw/file.csv          # crea .dvc, mueve a cache
dvc push                           # sube blobs al remote
dvc pull                           # baja blobs
dvc repro                          # ejecuta dvc.yaml
dvc dag                            # muestra grafo de stages
dvc status                         # qué falta de regenerar
dvc checkout                       # restaura ficheros desde cache
dvc metrics show                   # métricas trackeadas
dvc params diff                    # diff de params
```

## MLflow

```bash
# servidor local
mlflow server \
  --backend-store-uri postgresql://mlflow:mlflow@localhost:5432/mlflow \
  --default-artifact-root s3://mlflow/ \
  --host 0.0.0.0 --port 5000

# CLI
mlflow experiments list
mlflow runs list -e <experiment_id>
mlflow models serve -m models:/income-clf/Staging -p 5001
```

```python
import mlflow
mlflow.set_tracking_uri("http://localhost:5000")
mlflow.set_experiment("income-classifier")

with mlflow.start_run(run_name="rf-baseline"):
    mlflow.log_params({"n": 200})
    mlflow.log_metric("f1", 0.71)
    mlflow.set_tag("owner", "jpicon")
    mlflow.sklearn.log_model(model, name="model",
                             signature=sig, input_example=X.head(3))
```

## Great Expectations (rápido)

```python
import great_expectations as gx
ctx = gx.get_context()
ds = ctx.data_sources.add_pandas("local")
asset = ds.add_dataframe_asset("adult", dataframe=df)
batch = asset.build_batch_request()
suite = ctx.suites.add(gx.ExpectationSuite(name="adult-suite"))
# ... añadir expectations
ctx.run_validation(...)
```

## FastAPI

```python
from fastapi import FastAPI
from pydantic import BaseModel, Field

class Features(BaseModel):
    age: int = Field(ge=0, le=120)

app = FastAPI()

@app.post("/predict")
def predict(f: Features):
    return {"label": 1}
```

```bash
uvicorn app.main:app --reload --port 8000
curl localhost:8000/docs   # Swagger
```

## Locust

```bash
locust -f locustfile.py --host http://localhost:8000 \
       --users 50 --spawn-rate 10 --run-time 1m --headless
```

## Evidently

```python
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset
r = Report(metrics=[DataDriftPreset()])
r.run(reference_data=ref, current_data=cur)
r.save_html("drift.html")
```

## GitHub Actions (esqueleto)

```yaml
on: [push, pull_request, workflow_dispatch]
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - run: pip install -r requirements.txt
      - run: pytest -v
```

## Tests estadísticos de drift (pandas/scipy)

```python
from scipy.stats import ks_2samp, chi2_contingency
ks_2samp(ref, cur)                       # numérico
chi2_contingency(contingency_table)      # categórico
```

## Comandos útiles MinIO

```bash
mc alias set local http://localhost:9000 minio minio12345
mc ls local/
mc mb local/datasets
mc cp file.csv local/datasets/
```

## Atajos de teclado MLflow UI

- `c` — comparar runs seleccionados
- `r` — refresh
- `/` — buscar
- click en métrica → ordenar
