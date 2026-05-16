# Guía paso a paso de los labs con explicaciones

En cada lab vas a teclear varios comandos. Esta guía acompaña cada uno de esos comandos con **qué hace, por qué lo necesitamos y qué deberías ver**. Léela en paralelo al README del lab cuando te pierdas. No sustituye al README; lo complementa.

---

## Lab 1 — DataOps con DVC + Great Expectations

**Pregunta que respondemos:** ¿cómo garantizo que el dato que entra al modelo de hoy es el mismo que entró ayer (o uno mejor, controlado)?

### Fase 0 · Levantar el entorno

```bash
docker compose -f docker/docker-compose.yml up -d
```

- **Qué hace:** arranca los cinco contenedores del curso. En el Lab 1 nos importan MinIO (donde DVC dejará el dataset) y Postgres (aunque no lo usemos directamente aquí).
- **Por qué:** sin MinIO funcionando no hay sitio donde subir el dataset versionado.
- **Comprueba:** `docker compose ps`. MinIO y Postgres deben estar `Up (healthy)`.

### Fase 1 · Inicializar DVC

```bash
git init                  # solo si el repo no tiene git ya
dvc init
```

- **Qué hace `dvc init`:** crea el directorio `.dvc/` con la configuración del proyecto. A partir de ese momento DVC sabe que esta carpeta es un proyecto de versionado de datos.
- **Por qué:** DVC vive sobre Git. Necesita un repo Git inicializado para colocar sus archivos puntero (`.dvc`).
- **Comprueba:** debe aparecer la carpeta `.dvc/` con `config`, `.gitignore` y `cache/` (vacía).

### Fase 2 · Configurar el remote (MinIO)

```bash
dvc remote add -d minio s3://datasets/lab1
dvc remote modify minio endpointurl http://localhost:9000
dvc remote modify --local minio access_key_id minio
dvc remote modify --local minio secret_access_key minio12345
```

- **Línea 1:** registra un *remote* llamado `minio` que apunta al bucket `datasets`, ruta `lab1`. `-d` lo marca como default (para que `dvc push` sin argumentos lo use).
- **Línea 2:** el endpoint S3 (binario, **9000**, **no 9001** que es la consola).
- **Líneas 3 y 4:** credenciales. El `--local` guarda en `.dvc/config.local`, que **no** se commitea (está en `.gitignore`) para que tus secretos no acaben en GitHub.
- **Comprueba:** `cat .dvc/config` y `cat .dvc/config.local` deben mostrar lo que acabas de configurar.

### Fase 3 · Descargar el dataset

```bash
mkdir -p data/raw
curl -L https://archive.ics.uci.edu/ml/machine-learning-databases/adult/adult.data \
  -o data/raw/adult.csv
```

- **Qué hace:** baja el dataset **UCI Adult Income** (~3.9 MB), un clásico didáctico: predice si un adulto gana más o menos de 50k al año según edad, educación, horas trabajadas, etc.
- **Por qué:** necesitamos un dato real para versionar. Si la red de la sala va mal, ya tienes una copia en `datasets/adult/adult.csv`.

### Fase 4 · Versionar el dataset con DVC

```bash
dvc add data/raw/adult.csv
git add data/raw/adult.csv.dvc data/raw/.gitignore
git commit -m "track dataset with dvc"
dvc push
```

- **`dvc add`:** calcula el hash MD5 del CSV, mueve el archivo al cache de DVC y crea `adult.csv.dvc` con el hash. También añade `adult.csv` al `.gitignore` para que **el CSV pesado no se commitee**.
- **`git add` + `git commit`:** versionamos el *puntero*, no el archivo real.
- **`dvc push`:** sube el blob real (el CSV) a MinIO.
- **Comprueba:** abre la consola de MinIO (`http://localhost:9001`) y navega a `datasets/lab1/files/md5/...`. Debe haber un archivo con un nombre que es el hash.

> **Concepto clave:** Git versiona código y punteros. DVC versiona blobs en almacenamiento externo. Juntos te dan reproducibilidad sin saturar Git.

### Fase 5 · Validar el dataset con Great Expectations

```bash
python src/ge_validate.py data/raw/adult.csv
```

- **Qué hace `ge_validate.py`:** carga el CSV en un DataFrame y ejecuta cuatro expectations: schema, rango de edades, dominio de `workclass`, no-nulos en `income`.
- **Por qué:** queremos detectar datos malos **antes** de que el modelo entrene con ellos. Es un *fail-fast*.
- **Comprueba:** salida `ALL EXPECTATIONS PASSED`. Si alguna falla, el script termina con código distinto de 0 y el pipeline se para (lo verás en la fase 7).

### Fase 6 · Definir y ejecutar el pipeline

```bash
dvc repro
```

- **Qué hace:** lee `dvc.yaml`, calcula el grafo de stages (`validate → preprocess`), compara hashes de entradas con la última ejecución, y solo re-ejecuta lo que ha cambiado.
- **Por qué:** así no entrenas con datos sin validar, y no preprocesas dos veces lo mismo.
- **Comprueba:** aparecen `data/processed/train.parquet` y `test.parquet`. `dvc.lock` se actualiza con los hashes de los outputs.

### Fase 7 · Romper el dato a propósito

```bash
sed -i '5s/.*/16, "??"/' data/raw/adult.csv
dvc repro
```

- **Qué hace:** mete una fila con `age = 16` (fuera del rango 17–90 que validamos).
- **Resultado esperado:** `validate` falla, `preprocess` no se ejecuta. Eso es lo que queremos: la validación **es un gate**.

Recupera:

```bash
dvc checkout data/raw/adult.csv     # restaura desde el cache
dvc repro
```

### Fase 8 · Cambia el código

Edita `src/preprocess.py` y cambia `test_size=0.2` a `0.3`. Ejecuta:

```bash
dvc repro
```

- **Qué pasa:** `validate` no se reejecuta (sus inputs no han cambiado), `preprocess` sí (cambió su código).
- **Por qué importa:** DVC entiende qué dependencia cambió y rehace solo lo afectado. En un pipeline grande eso significa minutos en lugar de horas.

---

## Lab 2 — MLflow Tracking + Model Registry

**Pregunta que respondemos:** ¿cómo registro cada entrenamiento de forma reproducible y promociono el mejor modelo de forma controlada?

### Fase 1 · Comprobar el servidor MLflow

```bash
curl -s http://localhost:5050/ -o /dev/null -w "%{http_code}\n"
```

- Debe devolver `200`. Si no, mira logs: `docker logs anban-mlflow --tail=30`.
- **Por qué:** todo el lab se apoya en el servidor de tracking. Si no responde, los `mlflow.log_*` fallarán o se irán a una carpeta local (lo último que quieres).

### Fase 2 · Configurar el cliente en el notebook

```python
import os, mlflow
os.environ["MLFLOW_TRACKING_URI"] = "http://localhost:5050"
os.environ["MLFLOW_S3_ENDPOINT_URL"] = "http://localhost:9000"
os.environ["AWS_ACCESS_KEY_ID"] = "minio"
os.environ["AWS_SECRET_ACCESS_KEY"] = "minio12345"

mlflow.set_tracking_uri("http://localhost:5050")
mlflow.set_experiment("adult-income")
```

- **Por qué tantas variables:** MLflow registra los metadatos en Postgres (a través del servidor) y los artefactos (modelo, gráficas) en MinIO. Sin las credenciales de MinIO no puede subir el modelo.
- **Comprueba:** en la UI de MLflow aparece el experimento "adult-income" (al principio vacío).

### Fase 3 · Primer run

```python
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import f1_score
import mlflow, mlflow.sklearn

with mlflow.start_run(run_name="rf-baseline"):
    mlflow.log_param("n_estimators", 100)
    mlflow.log_param("max_depth", 5)

    model = RandomForestClassifier(n_estimators=100, max_depth=5, random_state=42)
    model.fit(X_train, y_train)
    pred = model.predict(X_test)
    f1 = f1_score(y_test, pred)

    mlflow.log_metric("f1", f1)
    mlflow.sklearn.log_model(model, "model", input_example=X_train.iloc[:3])
```

Qué hace cada línea:

- `start_run`: abre un run nuevo. Todo lo que loggees dentro queda asociado a ese run.
- `log_param`: parámetros que decidiste tú (hiperparámetros, configuración).
- `log_metric`: métricas medibles del experimento. Pueden ser varias y MLflow las trackea como serie temporal.
- `log_model`: serializa el modelo y lo sube al artifact store (MinIO). El `input_example` ayuda a futuros usuarios a saber qué forma de input espera.

**Comprueba:** ve a la UI de MLflow. Tu run aparece con sus params, su F1 y un directorio `model/` con el `.pkl`, `MLmodel` (descriptor) y `conda.yaml` (entorno).

### Fase 4 · Comparar runs

Lanza el mismo notebook con `n_estimators=300, max_depth=12`. Vuelve a la UI:

- Marca los dos runs y pulsa **Compare**.
- Verás una tabla con sus params, métricas y un gráfico de paralelas para ver visualmente qué configuración fue mejor.

> **Concepto:** un *experiment* es la pregunta ("¿qué configuración predice mejor el income?"). Cada *run* es una respuesta concreta. Comparar runs es el día a día del data scientist.

### Fase 5 · Registrar el modelo

En la UI, abre el run ganador, despliega `model` y pulsa **Register Model**. Le pones nombre `adult-income-clf`.

Equivalente programático:

```python
result = mlflow.register_model(
    f"runs:/{run_id}/model",
    "adult-income-clf"
)
```

Eso crea la versión 1 del modelo en el **Registry**.

### Fase 6 · Promocionar a Staging

En la pestaña **Models** del Registry, sobre la versión 1, cambias el stage a `Staging`.

- **Por qué:** el Lab 3 cargará el modelo desde `models:/adult-income-clf/Staging`. Así desacoplas el **identificador del modelo** del **identificador del run**. Si mañana entrenas un modelo mejor, basta con promocionar la nueva versión a Staging y el Lab 3 lo recoge sin cambiar una línea.

> **Concepto:** Registry es el catálogo central. Los stages (`None`, `Staging`, `Production`, `Archived`) son el ciclo de vida controlado del modelo, equivalente al ciclo de releases del software.

---

## Lab 3 — Servir el modelo con FastAPI + Docker

**Pregunta que respondemos:** ¿cómo convierto el modelo registrado en algo que cualquier sistema pueda consumir por HTTP, empaquetado para que funcione en cualquier máquina?

### Fase 1 · Esqueleto FastAPI

```python
from fastapi import FastAPI
from pydantic import BaseModel
import mlflow.pyfunc, os

os.environ["MLFLOW_TRACKING_URI"] = "http://mlflow:5000"
os.environ["MLFLOW_S3_ENDPOINT_URL"] = "http://minio:9000"
os.environ["AWS_ACCESS_KEY_ID"] = "minio"
os.environ["AWS_SECRET_ACCESS_KEY"] = "minio12345"

app = FastAPI(title="Adult Income API")
model = mlflow.pyfunc.load_model("models:/adult-income-clf/Staging")

class Input(BaseModel):
    age: int
    workclass: str
    education_num: int
    hours_per_week: int

@app.get("/health")
def health(): return {"status": "ok"}

@app.get("/version")
def version(): return {"model": "adult-income-clf", "stage": "Staging"}

@app.post("/predict")
def predict(payload: Input):
    pred = model.predict([payload.dict()])
    return {"prediction": int(pred[0])}
```

Qué hace cada bloque:

- **Variables de entorno:** decirle al cliente MLflow dónde está el tracking server y el bucket. Importante: usamos los nombres de servicio Docker (`mlflow`, `minio`), no `localhost` — la API correrá dentro de la red Docker.
- **`load_model("models:/.../Staging")`:** descarga la versión actualmente en Staging. Si mañana promocionas otra versión, basta con reiniciar el contenedor para recogerla.
- **`/health`:** endpoint que devuelve 200 si el servicio está vivo. Lo usan orquestadores (Kubernetes, Docker) para detectar contenedores rotos.
- **`/version`:** debugging humano y trazabilidad. Si dos servicios devuelven predicciones distintas, primero consultas `/version` para ver si están sirviendo el mismo modelo.
- **`/predict`:** el endpoint principal. Pydantic valida el payload **antes** de invocar al modelo.

### Fase 2 · Probar en local sin Docker

```bash
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
curl -X POST http://localhost:8000/predict -H "Content-Type: application/json" \
  -d '{"age":39,"workclass":"Private","education_num":13,"hours_per_week":40}'
```

- **Por qué probarlo así antes:** Docker añade complejidad (red, build, paths). Si la app funciona ya en local, sabemos que el problema en Docker (si surge) está en el empaquetado, no en el código.

### Fase 3 · Dockerfile multi-stage

```dockerfile
FROM python:3.11-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
COPY app.py .
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

- **Multi-stage:** la primera etapa instala dependencias en `/root/.local`. La segunda etapa parte de una imagen limpia y copia solo los paquetes — sin caches de pip, sin código de build. Resultado: imagen final mucho más pequeña.
- **Por qué importa el tamaño:** una imagen de 3 GB tarda en bajar a cada nodo del cluster. Una de 200 MB se despliega en segundos.
- **Comprueba:** `docker images mi-api` debe mostrar un tamaño razonable (~300 MB para esta API).

### Fase 4 · Construir y ejecutar

```bash
docker build -t adult-income-api:0.1 .
docker run --rm -p 8000:8000 --network anban_default adult-income-api:0.1
```

- **`--network anban_default`:** conectamos el contenedor a la red de Docker que ya creó el `docker-compose`. Así puede ver a `mlflow` y `minio` por nombre.
- **Comprueba:** `curl http://localhost:8000/health` devuelve `{"status":"ok"}`.

### Fase 5 · Benchmark con Locust

```python
# locustfile.py
from locust import HttpUser, task

class APIUser(HttpUser):
    @task
    def predict(self):
        self.client.post("/predict", json={
            "age": 39, "workclass": "Private",
            "education_num": 13, "hours_per_week": 40
        })
```

```bash
locust -f locustfile.py --headless -u 50 -r 5 -t 1m --host http://localhost:8000
```

- **Qué mide:** 50 usuarios simultáneos durante 1 minuto, ramping up a 5 usuarios/segundo.
- **Métricas que importan:**
  - **p50:** la mitad de las peticiones tardan menos que esto.
  - **p95 / p99:** las "colas" de la distribución. Una p99 alta significa que algunos usuarios sufren picos de latencia.
  - **Requests/s (throughput):** capacidad del servicio.
- **Objetivo del lab:** p95 < 100 ms. Si lo superas, mira:
  1. ¿El modelo está cargado **una vez al iniciar** o se carga en cada petición? Si es lo segundo, mátalo: muévelo fuera del handler.
  2. ¿Tienes suficientes workers? `uvicorn --workers 4`.

---

## Lab 4 — CI/CD con GitHub Actions + Monitoring con Evidently

**Pregunta que respondemos:** ¿cómo automatizo el ciclo entrenar-evaluar-promover y cómo detecto que el modelo se está desgastando?

### Fase 1 · Workflow base

Crea `.github/workflows/ml.yml`:

```yaml
name: ml-pipeline
on: [push, pull_request]

jobs:
  pipeline:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env: { POSTGRES_USER: mlflow, POSTGRES_PASSWORD: mlflow, POSTGRES_DB: mlflow }
        ports: ["5432:5432"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.11' }
      - run: pip install -r requirements.txt
      - run: pip install pytest ruff
      - run: ruff check src/                           # lint
      - run: pytest -q                                 # tests
      - run: python src/train.py                       # entrena
      - run: python src/evaluate.py --baseline-stage Production  # compara
      - run: python src/promote.py                     # promociona si mejora
```

Qué hace cada paso:

- **`ruff`:** linter Python ultra-rápido. Detecta código mal indentado, imports no usados, errores tipográficos típicos.
- **`pytest`:** ejecuta tests unitarios. Si un test falla, el pipeline se corta — no entrenamos sobre código roto.
- **`train.py`:** entrena un nuevo modelo. Loggea params/métricas en MLflow (idealmente apuntando a un servidor de tracking real, no al efímero del CI).
- **`evaluate.py`:** carga el modelo actual en `Production` y compara F1. Si el nuevo no mejora, **exit 1**.
- **`promote.py`:** si pasó evaluate, registra y promociona la nueva versión.

> **Concepto:** los pasos están en orden de coste. Lo barato (lint, tests) va primero porque si rompen te enteras pronto y no gastas minutos entrenando.

### Fase 2 · Estrategia de despliegue

| Estrategia    | Cómo funciona                                          | Cuándo usarla                          |
|---------------|--------------------------------------------------------|----------------------------------------|
| **Blue-green**| Levantas la versión nueva (green) al lado de la vieja (blue). Cambias el router de golpe.    | Cambios importantes. Rollback instantáneo. |
| **Canary**    | La versión nueva recibe el 5 % del tráfico al principio; vas subiendo.    | Quieres detectar problemas con tráfico real sin arriesgar todos los usuarios. |
| **Shadow**    | La versión nueva recibe el 100 % del tráfico **en paralelo** pero sus respuestas no se devuelven. Comparas predicciones.    | Validación previa sin riesgo cero. |

### Fase 3 · Informe Evidently

```python
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, ClassificationPreset

ref     = pd.read_csv("data/train_reference.csv")   # el que usaste para entrenar
current = pd.read_csv("data/last_week_inference.csv")  # un lote reciente

report = Report(metrics=[DataDriftPreset(), ClassificationPreset()])
report.run(reference_data=ref, current_data=current)
report.save_html("monitoring/drift_report.html")
report.save_json("monitoring/drift_report.json")
```

- **`DataDriftPreset`:** detecta movimiento de las distribuciones de features.
- **`ClassificationPreset`:** mide degradación de las métricas del modelo en el nuevo lote (si tienes ground truth).
- **JSON + HTML:** el JSON va a un endpoint `/monitor` que sirve el resumen al equipo. El HTML va al equipo de producto para ver gráficas.

### Fase 4 · Inyectar drift y observarlo

```python
import numpy as np
current_drifted = current.copy()
current_drifted["age"] += np.random.randint(10, 20, size=len(current))  # envejecemos
current_drifted["hours_per_week"] *= 1.5
```

Vuelves a correr el informe. Ahora deberías ver:

- Tests PSI / KS sobre `age` y `hours_per_week` por encima del umbral.
- En la sección de drift, esas columnas marcadas en rojo.

> **Concepto:** los tests estadísticos (PSI, KS, Chi², Wasserstein) ponen un **número objetivo** sobre algo que de otra forma sería ojímetro. PSI > 0.2 es un umbral común para "esto se ha movido lo suficiente como para preocuparse".

---

## Lab 5 — Caso integrador end-to-end + Governance

**Pregunta que respondemos:** ¿qué pinta tiene el ciclo entero ejecutado de punta a punta, y qué falta para producción real?

### Fase 1 · Recorrer el pipeline completo

```bash
dvc pull                # baja datos del Lab 1
pytest                  # valida que nada se ha roto
python src/train.py     # entrena, loggea en MLflow
python src/evaluate.py  # compara contra Production
python src/promote.py   # promociona si mejora
docker build -t adult-income-api:$(git rev-parse --short HEAD) .
docker run -d -p 8000:8000 --network anban_default adult-income-api:$(git rev-parse --short HEAD)
curl http://localhost:8000/predict ...
```

Lo importante no es que **cada comando** funcione (ya los conoces) sino que **el orden** es el orden.

### Fase 2 · Model card

Crea `MODEL_CARD.md` con:

- **Intended use:** para qué sirve (predicción binaria de income > 50k).
- **Out of scope:** para qué **no** sirve (no es válido para tomar decisiones sobre crédito sin revisión humana; los datos son de EE.UU. de los 90, no extrapolan).
- **Datos de entrenamiento:** UCI Adult Income, ~30k filas, sesgo demográfico conocido.
- **Métricas globales y por subgrupo:** accuracy y F1 desglosados por `race`, `sex`, `native-country`. Importante: muchas veces el modelo funciona "bien" globalmente pero mucho peor para un subgrupo concreto.
- **Limitaciones conocidas:** clases desbalanceadas, label originalmente categórica.
- **Cambios entre versiones:** changelog.

### Fase 3 · Discusión guiada: qué falta para producción real

Lista para reflexionar (sin código):

1. **Secretos:** ¿dónde guardas las credenciales de MinIO/Postgres en producción? (Spoiler: no en `.env` commiteado. AWS Secrets Manager, Vault, Doppler).
2. **Observabilidad:** ¿quién se entera si tu API responde 500 ahora mismo? (Prometheus + Grafana, Sentry, Datadog).
3. **Rollback:** si el modelo nuevo da peores predicciones que el viejo, ¿cuánto tardas en volver atrás? (Idealmente: 30 segundos vía Registry).
4. **Autoscaling:** si llegan 10x peticiones, ¿se cae o escala? (Kubernetes HPA, ECS Auto Scaling).
5. **Alertas de drift:** ¿quién mira el informe Evidently? (Cron diario que postea en Slack si PSI > umbral).
6. **Reentrenamiento:** ¿cada cuánto reentrenas? ¿con qué datos? (CT — Continuous Training, igual de importante que CI/CD).
7. **Compliance:** si un usuario afectado por una predicción pide explicación, ¿puedes darla? (SHAP, LIME, audit logs).
8. **Costes:** ¿cuánto cuesta entrenar y servir? ¿se justifica? (FinOps en ML: GPUs son caras, batch suele ser 100x más barato que online).
9. **Versionado conjunto código-datos-modelo:** ¿puedes reconstruir el modelo de hace 6 meses bit a bit? Si no, falla auditoría.
10. **Fairness:** ¿el modelo discrimina sistemáticamente a un grupo? ¿cómo lo mides?

> **Lo que sí tienes ya:** versionado de datos, validación, tracking, registry, API empaquetada, CI/CD, monitoring de drift. Eso te coloca en **nivel 1–2 de madurez** de la escala de Google. La mayoría de empresas están en nivel 0. Has dado un salto enorme en 2 días.
