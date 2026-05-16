# Syllabus detallado — MLOps / DataOps (ANBAN)

> Cada bloque incluye: **Objetivos**, **Contenido teórico**, **Demo/lab**, **Material**, **Tiempos**.

---

## DÍA 1 — DataOps y fundamentos de MLOps (240 min)

### Módulo 1 — Introducción MLOps & DataOps (45 min)

**Objetivos:** posicionar las disciplinas, comprender por qué fracasan los proyectos ML en producción, identificar niveles de madurez.

**Teoría (30 min):**
- ¿Por qué nace MLOps? El "deuda técnica oculta" en sistemas ML (Sculley et al., 2015 — *Hidden Technical Debt in ML Systems*).
- Diferencias entre **DevOps**, **DataOps**, **MLOps**, **AIOps**, **LLMOps**.
- El triángulo: **Code – Data – Model**. Por qué versionar código no basta.
- Ciclo de vida CRISP-DM vs CRISP-ML(Q).
- Niveles de madurez Google: **L0 manual / L1 ML pipeline automatizado / L2 CI/CD pipelines completo**.
- Roles: Data Engineer, ML Engineer, MLOps Engineer, Data Scientist, SRE/ML.

**Práctica guiada (15 min):**
- Diagnóstico de madurez sobre 3 escenarios reales (notebook compartido en VSCode + diagrama en pizarra).

**Material:** slides 1–18 del PPTX Día 1.

---

### Módulo 2 — DataOps: pipelines, versionado, calidad (75 min)

**Objetivos:** construir y validar un pipeline de datos reproducible.

**Teoría (25 min):**
- Principios DataOps (manifiesto): orquestación, observabilidad, automatización, versionado.
- **Versionado de datos**: ¿por qué Git no sirve para datasets grandes? Soluciones: DVC, LakeFS, Delta Lake.
- **Calidad de datos**: dimensiones (completitud, validez, unicidad, consistencia, freshness). Frameworks: Great Expectations, Soda, Pandera.
- **Orquestación**: Airflow, Prefect, Dagster — cuándo usar cada uno.
- **Lineage** y catálogo: OpenLineage, DataHub, Amundsen.

**Lab 1 (50 min):** `labs/lab1_dataops`
- Inicializar DVC en un repo git con un dataset de ~50MB.
- Crear `dvc.yaml` con stages: `ingest → validate → preprocess`.
- Validar el dataset con Great Expectations (4 expectativas: schema, no nulos, rango, unicidad).
- Romper a propósito el dato y observar el fallo.
- Reproducir con `dvc repro`.

**Material:** slides 19–32, `labs/lab1_dataops/README.md`.

---

### Módulo 3 — Experiment tracking con MLflow (75 min)

**Objetivos:** experimentar de forma reproducible y registrar modelos versionados.

**Teoría (25 min):**
- ¿Por qué experiment tracking? Reproducibilidad, comparación, auditoría.
- Anatomía de **MLflow**: Tracking, Projects, Models, Model Registry.
- Conceptos: `experiment`, `run`, `artifact`, `parameter`, `metric`, `tag`.
- Alternativas: Weights & Biases, Neptune, Comet, Aim.
- **Reproducibilidad**: seeds, entorno, hash de datos.

**Lab 2 (50 min):** `labs/lab2_mlflow_dvc`
- Levantar MLflow Tracking Server + MinIO + Postgres con docker-compose.
- Entrenar un `RandomForestClassifier` y un `XGBoost` sobre el dataset del Lab 1.
- Loggear params, métricas, model signature, input example.
- Comparar runs en la UI.
- Promocionar el mejor modelo a `Staging` en el Model Registry.

**Material:** slides 33–46, `labs/lab2_mlflow_dvc/`.

---

### Cierre Día 1 (15 min)

- Recap visual del flujo: dato versionado → validado → modelo trackeado → registrado.
- Reto opcional para casa: añadir un tercer modelo y promocionarlo.

---

## DÍA 2 — MLOps en producción (240 min)

### Módulo 4 — Empaquetado y serving (60 min)

**Objetivos:** llevar el modelo del Model Registry a una API en contenedor.

**Teoría (20 min):**
- Patrones de serving: **batch**, **online (REST/gRPC)**, **streaming**, **edge**.
- Empaquetado: pickle, ONNX, MLflow flavor, BentoML, TorchServe, TF Serving.
- Diseño de la API: contrato, validación con Pydantic, versionado de endpoints.
- Performance: latencia p50/p95/p99, throughput, batching dinámico.
- Trade-offs: latencia vs frescura, monolítico vs microservicios.

**Lab 3 (40 min):** `labs/lab3_serving`
- Cargar modelo desde MLflow Registry (`models:/clf/Staging`).
- Servirlo con **FastAPI** (`/predict`, `/health`, `/version`) con validación Pydantic.
- Dockerizar (multi-stage, imagen <300MB).
- Probar con `curl` + benchmark con `locust` (50 usuarios, p95 < 100ms).

**Material:** slides 47–60, `labs/lab3_serving/`.

---

### Módulo 5 — CI/CD + Monitoring + Drift (75 min)

**Objetivos:** automatizar el flujo de release y detectar degradación en producción.

**Teoría (25 min):**
- CI vs CD vs CT (**Continuous Training**). El triple bucle ML.
- Pipelines típicos en GitHub Actions: `test → train → evaluate → register → build → deploy`.
- Estrategias de despliegue: blue-green, canary, shadow.
- **Monitoring** de modelos: métricas de servicio (latencia, RPS, errores) vs métricas de modelo (accuracy proxy, distribución de outputs).
- **Drift**:
  - *Data drift* (covariate shift): cambia P(X).
  - *Concept drift*: cambia P(y|X).
  - *Label drift*: cambia P(y).
  - Tests: PSI, KS, Chi², Wasserstein.
- Herramientas: Evidently, WhyLabs, Arize, NannyML.

**Lab 4 (50 min):** `labs/lab4_cicd_monitoring`
- Configurar `.github/workflows/ml.yml` con jobs `lint → test → train → evaluate`.
- Si el modelo nuevo bate al de Production en F1 ≥ 1%, promocionar.
- Generar informe Evidently comparando dataset de referencia vs nuevo lote (con drift inyectado).
- Endpoint `/monitor` que devuelve resumen JSON.

**Material:** slides 61–76, `labs/lab4_cicd_monitoring/`.

---

### Módulo 6 — Caso integrador end-to-end + Governance (75 min)

**Objetivos:** cerrar el ciclo y comprender qué falta más allá del MVP.

**Teoría (25 min):**
- **Feature Store**: por qué (consistencia train/serve, reuso). Feast, Tecton, Hopsworks.
- **Model Governance**: model cards, audit trail, RGPD/AI Act, sesgo y fairness.
- **Reproducibilidad estricta**: hash de datos + código + entorno.
- **Cost & FinOps en ML**: GPUs, batch vs online, autoscaling.
- **LLMOps en una slide**: prompt versioning, eval, guardrails, RAG.

**Lab 5 (45 min):** `labs/lab5_e2e`
- Recorrer el repositorio completo: `dvc pull` → `pytest` → `train.py` → MLflow → API → Docker.
- Discusión guiada: ¿qué falta para producción real? (alertas, rollback, secrets, HPA, observabilidad…).

**Cierre (15 min):**
- Hoja de ruta de aprendizaje (junior → senior MLOps).
- Bibliografía y comunidades (MLOps Community, ML-Ops.org).
- Q&A.

**Material:** slides 77–90, `labs/lab5_e2e/`.

---

## Métricas de evaluación del curso

- ✔ El alumno consigue completar Lab 1 y Lab 2 en clase.
- ✔ El alumno entiende qué slide del PPTX se corresponde con qué fase del ciclo.
- ✔ El alumno sabe diagnosticar el nivel de madurez MLOps de su organización.
