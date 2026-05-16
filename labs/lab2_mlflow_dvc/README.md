# Lab 2 — MLflow Tracking + Model Registry

> Tiempo estimado: **50 min**

## Objetivo

Trackear 3 modelos comparables, registrar el mejor en MLflow Model Registry
y promocionarlo a `Staging` desde la API.

## Pre-requisitos

- Lab 1 completo (`data/processed/{train,test}.parquet` existen).
- Stack `docker compose up -d` levantado (`mlflow`, `minio`, `postgres`).

## Variables de entorno

```bash
export MLFLOW_TRACKING_URI=http://localhost:5000
export MLFLOW_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=minio
export AWS_SECRET_ACCESS_KEY=minio12345
```

## Paso 1 · Entrenar 3 modelos

```bash
python src/train.py --model logreg
python src/train.py --model rf
python src/train.py --model xgb
```

Cada ejecución crea un run dentro del experimento `income-classifier`.

## Paso 2 · Comparar runs

Abre [http://localhost:5000](http://localhost:5000):

- En el experimento `income-classifier`, marca los 3 runs y pulsa **Compare**.
- Examina el gráfico de coordenadas paralelas.
- Ordena por `f1` y elige el ganador.

## Paso 3 · Registrar el modelo ganador

Desde la UI de MLflow → run ganador → tab **Artifacts** → seleccionar
carpeta `model` → botón **Register Model**:

- Name: `income-clf`
- Version: 1 (auto)

O por CLI:

```bash
python src/register_best.py --experiment income-classifier --metric f1 --name income-clf
```

## Paso 4 · Promocionar a Staging

```bash
python src/promote.py --name income-clf --version 1 --stage Staging
```

## Paso 5 · Cargar el modelo desde el Registry

```python
import mlflow.pyfunc
m = mlflow.pyfunc.load_model("models:/income-clf/Staging")
print(m.metadata.signature)
```

## Comprobaciones de cierre

- [ ] Hay 3 runs con tags `dataset_version`, `git_commit` y `owner`.
- [ ] Cada run tiene `model` con signature.
- [ ] Existe un modelo `income-clf` en el Registry.
- [ ] Su versión 1 está en stage `Staging`.
- [ ] Puedes recargarlo y predecir.

## Reto opcional

Añade un cuarto modelo con `optuna` (búsqueda de hiperparámetros) y
sustituye al ganador.
