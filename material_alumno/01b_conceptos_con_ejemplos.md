# Conceptos clave con ejemplos

Antes de empezar con los labs conviene tener una imagen clara de **qué hace cada herramienta y por qué la usamos**. Esta sección recorre uno a uno los protagonistas del curso (DVC, Great Expectations, MLflow, FastAPI, Docker, GitHub Actions, Evidently…) con un ejemplo concreto y una analogía. Cuando llegues al lab correspondiente sabrás no solo el comando, sino lo que está pasando por debajo.

> Léelo de corrido si tienes 30 minutos antes de la primera sesión. Vuelve aquí cuando un comando no te haga clic.

---

## 1 · DVC — versionado de datos

### El problema

Tienes un proyecto con un dataset de 2 GB. Si lo metes en Git:

- Cada clon descarga 2 GB.
- Cambias una fila → Git guarda los 2 GB enteros otra vez (no sabe hacer diff de un CSV).
- GitHub te bloquea: el límite por archivo son 100 MB.
- Te das cuenta de que tu modelo cambia los resultados según la versión del CSV, pero no puedes saber **con qué versión exacta** entrenaste un modelo de hace un mes.

### Lo que hace DVC

DVC versiona los datos **fuera** de Git, dejando en Git solo un puntero (un archivo `.dvc` de 100 bytes) con el hash MD5 del archivo real.

> Analogía: imagina que Git es tu agenda. En lugar de pegar el documento entero (datos), pegas una pegatina con su número de archivador. El documento real está en el archivador (MinIO/S3). Si alguien quiere consultarlo, lee la pegatina y va al archivador.

### Ejemplo en 4 comandos

Partimos de un repo Git con un CSV de 2 GB:

```bash
git init
dvc init                          # crea .dvc/ con configuración
dvc add data/big.csv              # genera data/big.csv.dvc (el "puntero")
git add data/big.csv.dvc .gitignore
git commit -m "track big.csv with dvc"
```

Lo que pasa por dentro:

1. DVC calcula `md5("contenido del CSV") = 8e7c41…`.
2. Mueve el CSV a `.dvc/cache/8e/7c41…` (un cache local indexado por hash).
3. Crea un enlace duro a esa cache desde `data/big.csv`.
4. Escribe `data/big.csv.dvc` con el hash → eso es lo único que va a Git.

Para compartirlo con tu equipo necesitas un **remote** (S3, MinIO, GCS…):

```bash
dvc remote add -d minio s3://datasets/mi-proyecto
dvc remote modify minio endpointurl http://localhost:9000
dvc push                          # sube el blob real al remote
```

Tu compañero:

```bash
git clone <repo>
dvc pull                          # baja los blobs reales según los .dvc
```

### Por qué versionar también el pipeline

`dvc.yaml` describe cómo se generan los datos derivados:

```yaml
stages:
  preprocess:
    cmd: python src/preprocess.py
    deps:
      - data/raw/adult.csv
      - src/preprocess.py
    outs:
      - data/processed/train.parquet
```

Cuando ejecutas `dvc repro`:

- DVC compara hashes de las dependencias con la última vez.
- Si no han cambiado, **no ejecuta nada** (cache hit).
- Si han cambiado, ejecuta `cmd` y regenera los `outs`.

Resultado: **reproducibilidad exacta** y velocidad. Cambias el código del preprocesado y solo se regenera lo afectado, igual que `make` pero para pipelines de datos.

---

## 2 · Great Expectations — calidad de datos como código

### El problema

Llega un nuevo lote de datos. Una columna que solía tener edades entre 17 y 90 ahora trae alguna fila con `age = -5` (bug en el sistema upstream). El pipeline entrena, no falla, y publicas un modelo que va a dar predicciones absurdas. Lo descubres dos semanas después.

### Lo que hace Great Expectations

Te permite escribir "expectativas" (asserts inteligentes) sobre tu dataset:

```python
import great_expectations as ge

df = ge.from_pandas(pd.read_csv("data/raw/adult.csv"))
df.expect_column_values_to_be_between("age", 17, 90)
df.expect_column_values_to_not_be_null("income")
df.expect_column_values_to_be_in_set("workclass", ["Private", "Self-emp", "Gov"])
```

Cada `expect_*` te devuelve un resultado con `success: true/false`. Las metes en el pipeline como gate: si una falla, el pipeline se para y suena la alarma.

> Analogía: es el **control de calidad** de una fábrica. Antes de que la pieza pase a la siguiente máquina, la inspeccionas con un calibre. Si no pasa, paras la línea.

### Las 5 dimensiones que vamos a validar

1. **Schema**: las columnas que esperas siguen ahí.
2. **Rango**: valores numéricos dentro de límites razonables.
3. **Dominio cerrado**: categorías dentro de un conjunto conocido.
4. **No-nulos**: las columnas críticas no traen huecos.
5. **Unicidad**: el identificador no se repite.

En el Lab 1 escribirás las cuatro primeras y romperás el CSV a propósito para ver cómo el pipeline falla seguro.

---

## 3 · MLflow — experiment tracking

### El problema

Pasas tres días probando combinaciones: `n_estimators=100`, `n_estimators=200`, otro modelo, otro dataset, otro preprocesado. Al final tienes:

- 17 archivos `model_v2_final_FINAL_realFINAL.pkl`.
- Un Excel donde anotaste a mano algunas accuracies.
- Cero certeza sobre qué hiperparámetros usó el modelo bueno.

### Lo que hace MLflow

MLflow registra cada **run** (entrenamiento) con: parámetros, métricas, código, modelo serializado y firma. Después puedes filtrar, comparar y promocionar.

### Ejemplo mínimo

```python
import mlflow
from sklearn.ensemble import RandomForestClassifier

mlflow.set_tracking_uri("http://localhost:5050")     # tu servidor MLflow
mlflow.set_experiment("adult-income")

with mlflow.start_run():
    mlflow.log_param("n_estimators", 100)
    mlflow.log_param("max_depth", 5)
    model = RandomForestClassifier(n_estimators=100, max_depth=5).fit(X_train, y_train)
    acc = model.score(X_test, y_test)
    mlflow.log_metric("accuracy", acc)
    mlflow.sklearn.log_model(model, "model")
```

Tras ejecutarlo, abres `http://localhost:5050` y ves:

- El run que acabas de crear.
- Sus parámetros y métricas.
- El modelo `model/` adjunto, descargable.

Ejecuta el mismo script con `n_estimators=200`. Ahora tienes dos runs y puedes compararlos lado a lado en la UI.

> Analogía: un **cuaderno de laboratorio digital**. Cada experimento se firma, se fecha, queda registro de la receta exacta y de los resultados. Si seis meses después alguien dice "¿con qué entrenamos esto?", la respuesta está en el cuaderno.

### Anatomía MLflow

| Concepto       | Qué es                                                |
|----------------|-------------------------------------------------------|
| **Tracking**   | El servidor donde se registran los runs.              |
| **Experiment** | Carpeta de runs relacionados (ej. "adult-income").    |
| **Run**        | Una ejecución concreta con sus params y métricas.     |
| **Artifact**   | Cualquier archivo asociado al run (modelo, gráfica).  |
| **Registry**   | Catálogo central de modelos con etapas (None → Staging → Production → Archived). |

### Por qué Postgres + MinIO

MLflow necesita dos backends:

- **Postgres** (backend store): guarda metadatos — params, métricas, tags, runs.
- **MinIO** (artifact store): guarda los blobs grandes — modelos, gráficas, datos de muestra.

En el `docker-compose.yml` ya los tienes los dos cableados.

---

## 4 · FastAPI + Docker — servir el modelo

### El problema

Tu modelo entrenado vive en `model.pkl` en tu portátil. La gente del producto pregunta: "¿cómo lo consume el resto del equipo? ¿desde móvil? ¿desde la web?". Si la respuesta es "cárgalo en Python", no tienes un sistema, tienes un script.

### Lo que hace FastAPI

Convierte tu modelo en un **endpoint HTTP** al que cualquiera puede llamar:

```python
from fastapi import FastAPI
from pydantic import BaseModel
import mlflow.pyfunc

app = FastAPI()
model = mlflow.pyfunc.load_model("models:/clf/Staging")

class Input(BaseModel):
    age: int
    workclass: str
    hours_per_week: int

@app.post("/predict")
def predict(payload: Input):
    pred = model.predict([[payload.age, payload.workclass, payload.hours_per_week]])
    return {"prediction": pred.tolist()}
```

Lanzas el servidor:

```bash
uvicorn app:app --host 0.0.0.0 --port 8000
```

Y desde otro terminal:

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"age": 39, "workclass": "Private", "hours_per_week": 40}'
```

Respuesta: `{"prediction": [1]}`.

> Analogía: pasas de tener un **chef cocinando en su cocina** a un **restaurante con ventanilla**: cualquiera pide por la ventanilla (HTTP) y recibe su plato (predicción). Más estandarizado, escalable y monitorizable.

### Por qué dockerizar el servicio

Sin Docker, para correr tu API alguien necesita: Python 3.11, las versiones exactas de `scikit-learn`, `mlflow`, las variables de entorno, etc. Con Docker entregas **una imagen** que ya trae todo dentro. La ejecutas en cualquier máquina con Docker y funciona.

Dockerfile típico:

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
```

Construyes y ejecutas:

```bash
docker build -t mi-modelo:1.0 .
docker run -p 8000:8000 mi-modelo:1.0
```

### Pydantic: contrato fuerte en la entrada

`BaseModel` valida automáticamente cada petición. Si alguien manda `"age": "treinta y nueve"`, FastAPI rechaza con `422 Unprocessable Entity` antes de tocar el modelo. Eso convierte tu API en **autodefensiva**: no llegan datos sucios al modelo.

---

## 5 · GitHub Actions — CI/CD para ML

### El problema

Tu compañero sube un cambio al código del modelo. ¿Está roto? ¿Funcionan los tests? ¿El nuevo modelo es mejor que el de producción? Si la respuesta a cualquiera de esas es "no me he enterado", tienes un problema serio.

### Lo que hace GitHub Actions

Define **pipelines** que se ejecutan automáticamente cuando ocurren eventos (push, pull request, cron). Cada paso se ejecuta en un contenedor limpio.

### Ejemplo: pipeline ML típico

```yaml
# .github/workflows/ml.yml
on: [push, pull_request]

jobs:
  test-and-train:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.11' }
      - run: pip install -r requirements.txt
      - run: pytest                                     # tests
      - run: python src/train.py                        # entrena
      - run: python src/evaluate.py                     # compara con baseline
      - run: python src/promote.py                      # promociona si mejora
```

Cuando alguien hace `git push`, GitHub Actions:

1. Levanta un Ubuntu limpio.
2. Hace `git checkout` del código.
3. Instala dependencias.
4. Ejecuta los pasos en orden.
5. Marca el commit con ✅ o ❌ en la web de GitHub.

### CI vs CD vs CT

- **CI** (Continuous Integration): cada cambio se valida automáticamente (tests, lint).
- **CD** (Continuous Deployment): si valida, se despliega.
- **CT** (Continuous Training): periódicamente se reentrena con datos nuevos.

ML necesita los tres bucles. CI y CD son los mismos de software; CT es exclusivo de ML porque el modelo **se desgasta con el tiempo** aunque el código no cambie (los datos del mundo cambian).

---

## 6 · Evidently — detección de drift

### El problema

Entrenaste el modelo en datos de 2024. En 2026 las distribuciones han cambiado: la gente teletrabaja más, el rango de edades se desplaza, ciertas categorías aparecen que antes no existían. Tu modelo sigue funcionando técnicamente — devuelve un número — pero sus predicciones cada vez son más malas. Y no te das cuenta hasta que un cliente se queja.

### Lo que hace Evidently

Compara dos datasets (referencia vs nuevo lote) y te dice si **las distribuciones se han movido**. Genera un informe HTML con tests estadísticos y visualizaciones.

### Ejemplo

```python
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset

reference = pd.read_csv("data/2024_q1.csv")
current   = pd.read_csv("data/2026_q1.csv")

report = Report(metrics=[DataDriftPreset()])
report.run(reference_data=reference, current_data=current)
report.save_html("drift_report.html")
```

Abres `drift_report.html` y ves columna a columna:

- ¿Ha cambiado la media de `age`?
- ¿Ha aparecido un nuevo valor en `workclass`?
- Tests: PSI, Kolmogorov-Smirnov, Wasserstein → cada uno con su umbral.

### Tres tipos de drift que vamos a vigilar

| Tipo               | Qué cambia            | Ejemplo                                            |
|--------------------|-----------------------|----------------------------------------------------|
| **Data drift**     | P(X)                  | La edad media de los usuarios sube 5 años.         |
| **Concept drift**  | P(y \| X)             | Mismas features dan otro resultado. Pandemia, regulación. |
| **Label drift**    | P(y)                  | El porcentaje de clase positiva pasa del 20 % al 45 %. |

Los tres degradan el modelo, pero por mecanismos distintos. Cada uno se mide de forma distinta.

> Analogía: tu modelo es un **traje hecho a medida** del cliente medio de 2024. En 2026 los cuerpos han cambiado un poco (data drift), el estilo que pide la gente es otro (concept drift) y la proporción de tallas que se vende ya no es la misma (label drift). El traje sigue siendo el mismo; el mundo no.

---

## 7 · Feature Store y governance (visión panorámica)

### Feature Store: por qué

Imagina que dos equipos usan la feature `customer_lifetime_value`. Uno la calcula en el entrenamiento con SQL en Snowflake. El otro la calcula en producción con Python sobre el último mes. Pequeñas diferencias en la definición → **el modelo entrenado no es el que ejecuta en producción** → predicciones malas.

Una **Feature Store** (Feast, Tecton, Hopsworks) centraliza definiciones de features con dos modos:

- **Offline store** (BigQuery, Snowflake, Parquet) para entrenamiento.
- **Online store** (Redis, DynamoDB) para serving con baja latencia.

Misma definición, dos materializaciones consistentes.

### Governance: lo que pasa cuando ML se toma en serio

Cuando un modelo decide quién accede a un crédito o quién es priorizado en una lista de espera médica, ya no basta con "tiene buena accuracy":

- **Model card**: documento que explica para qué sirve el modelo, sus límites, sus métricas por subgrupo (¿funciona igual para mayores que para jóvenes?).
- **Audit trail**: registro inmutable de qué datos y qué código produjeron qué modelo. MLflow + DVC + Git te lo dan.
- **AI Act / RGPD**: el modelo debe ser auditable. Si una persona pide explicación de una decisión, tienes que poder darla.
- **Fairness**: medir disparidad de error entre grupos protegidos.

En el Lab 5 cerraremos el ciclo y discutiremos qué falta para llevar todo esto a producción real.

---

## 8 · Cómo encaja todo: el ciclo completo

```
   ┌───────────────────────────────────────────────────────────┐
   │                                                           │
   │   DATOS                MODELO              SERVICIO       │
   │                                                           │
   │   ┌──────┐ DVC      ┌─────────┐ MLflow   ┌──────────┐    │
   │   │ Raw  │────────▶│ Train   │─────────▶│ FastAPI  │    │
   │   │ CSV  │ versión │ Compare │ registry │ + Docker │    │
   │   └──────┘         └─────────┘          └──────────┘    │
   │      │                                        │          │
   │      │ Great Expectations              Evidently         │
   │      │ (validar)                       (monitorizar)     │
   │      ▼                                        ▼          │
   │   ❌ Si falla, para el pipeline       ❌ Si drift, alerta│
   │                                                           │
   │   Todo orquestado por GitHub Actions (CI/CD/CT)          │
   │                                                           │
   └───────────────────────────────────────────────────────────┘
```

Resumen de qué herramienta tapa cada agujero:

- **Datos sin control** → DVC (versionado) + Great Expectations (validación).
- **Experimentos sin registro** → MLflow (tracking + registry).
- **Modelo aislado en un portátil** → FastAPI + Docker (servirlo como API).
- **Cambios sin validar y modelo que se desgasta** → GitHub Actions (CI/CD/CT) + Evidently (drift).
- **Caja negra ante auditoría** → Model card + audit trail + métricas por subgrupo.

Cuando avances por los labs, pregúntate en cada paso: **"¿qué agujero estoy tapando con este comando?"**. Esa pregunta es la que separa "ejecutar un tutorial" de "entender MLOps".
