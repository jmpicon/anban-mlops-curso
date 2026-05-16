# Glosario MLOps/DataOps

| Término | Definición breve |
|---|---|
| **Artifact** | Cualquier fichero asociado a un run (modelo, plot, métrica, dataset). |
| **Backbone** | Modelo base preentrenado sobre el que se hace fine-tuning. |
| **Backfill** | Re-procesar histórico cuando cambia un cálculo. |
| **Batch inference** | Predicciones masivas programadas (no en tiempo real). |
| **Blue/Green** | Despliegue con dos entornos; tráfico salta entero al nuevo. |
| **Canary** | Despliegue gradual: x% del tráfico recibe la nueva versión. |
| **Concept drift** | Cambia P(y\|X): la relación entrada/salida cambia. |
| **CT (Continuous Training)** | Reentrenamiento automático del modelo. |
| **Data contract** | Acuerdo entre productor y consumidor del dato (schema, SLAs). |
| **Data drift** | Cambia P(X): la distribución de los inputs varía. |
| **Data lineage** | Trazabilidad de origen y transformaciones del dato. |
| **Data quality** | Conjunto de propiedades medibles del dato (validez, freshness…). |
| **DSL** | Domain Specific Language (ej. dvc.yaml, dbt model). |
| **DVC** | Data Version Control: git + storage para datasets. |
| **Experiment tracking** | Registro estructurado de runs de entrenamiento. |
| **Feature store** | Servicio centralizado de features (online + offline). |
| **Flavor (MLflow)** | Formato concreto en que se serializa un modelo (sklearn, tf, etc.). |
| **Inference** | Aplicar el modelo a inputs para producir predicciones. |
| **Label drift** | Cambia P(y): la distribución del target varía. |
| **Lineage** | Ver *data lineage*. |
| **Model card** | Ficha del modelo: propósito, datos, métricas, sesgos. |
| **Model registry** | Catálogo central de modelos con versiones y stages. |
| **MLOps** | DevOps + Data + Modelo: llevar ML a producción de forma sostenible. |
| **Online inference** | Predicciones síncronas con baja latencia. |
| **Promote** | Mover un modelo entre stages (Staging→Production). |
| **PSI** | Population Stability Index, métrica común de drift. |
| **Pyfunc** | Wrapper estándar de MLflow para servir modelos. |
| **Reproducibilidad** | Mismo input + código + entorno → mismo output. |
| **Run** | Una ejecución concreta de entrenamiento (params + metrics + artifacts). |
| **Schema drift** | El esquema del dato cambia (campos nuevos/cambian de tipo). |
| **Serving** | Exponer el modelo para que produzca predicciones. |
| **Shadow deployment** | El nuevo modelo recibe tráfico pero no responde al cliente. |
| **Signature (modelo)** | Contrato de inputs/outputs del modelo. |
| **Skew (train/serve)** | Diferencia entre cómo se procesa en train vs serve. |
| **Staging** | Stage del Registry: candidato listo para QA antes de Production. |
| **Tag** | Etiqueta clave-valor en un run, útil para filtrar. |
| **Triton** | Servidor NVIDIA para inferencia GPU/CPU multi-modelo. |
| **Versioning (datos)** | Capacidad de identificar y recuperar una versión exacta de un dataset. |
