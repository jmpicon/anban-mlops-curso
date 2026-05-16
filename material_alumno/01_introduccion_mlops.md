---
title: "Módulo 1. Introducción a MLOps y DataOps"
subtitle: "Curso MLOps/DataOps · ANBAN"
author: "José Picón"
date: "2026"
---

# 1. La pregunta con la que empieza todo

Llevas seis meses entrenando un modelo. Lo entregas a producción en
diciembre. Pasan tres meses. Alguien te pregunta:

- ¿Con qué versión exacta del dataset se entrenó este modelo?
- ¿Qué hiperparámetros tenía?
- ¿Cuántas predicciones ha hecho desde entonces?
- Si lo necesitamos reentrenar hoy con los mismos datos, ¿podemos?

Si no tienes respuestas claras a estas cuatro preguntas, tu sistema
ML sufre **deuda técnica oculta**. Es el problema que describieron
Sculley y otros en el famoso paper *Hidden Technical Debt in Machine
Learning Systems* (Google, 2015). El paper muestra con un esquema
muy gráfico que el código del modelo es una fracción minúscula del
sistema real, rodeado de servicios de validación de datos,
configuración, monitorización, serving, ingestión, etc.

> El código del modelo es el 5 % del sistema. El otro 95 % es
> plomería. MLOps es la disciplina que se ocupa de esa plomería.

\newpage

# 2. Cuatro disciplinas que se confunden

Mucha gente usa estos términos como sinónimos. No lo son. Tener clara
la diferencia te ahorra debates innecesarios.

| Disciplina | Qué versiona | Qué automatiza |
|------------|--------------|----------------|
| DevOps | Código | Build, test, deploy |
| DataOps | Datos y transformaciones | Pipelines de ingesta, validación, lineage |
| MLOps | Código, datos y modelo | Reentrenamiento, despliegue, monitorización del modelo |
| AIOps | Logs y métricas de infraestructura | Detección de anomalías en sistemas |
| LLMOps | Prompts, modelos, embeddings y RAG | Evaluación, guardrails, versionado de prompts |

DataOps y MLOps son **complementarios**: DataOps termina cuando hay
un dataset limpio y reproducible. MLOps empieza ahí. Sin DataOps,
MLOps es un castillo de naipes.

\newpage

# 3. El triángulo Código-Datos-Modelo

Los tres vértices de cualquier sistema ML están acoplados:

```
        Código
        /    \
       /      \
    Datos ---- Modelo
```

Si cambias uno y no tocas los otros, el sistema deja de ser
coherente:

- Cambias el código sin reentrenar: el modelo está desactualizado
  respecto a lo que el código espera.
- Cambias el dato sin re-evaluar: puede haber degradación silenciosa
  (drift, ver Módulo 5).
- Cambias el modelo sin versionar el dato: no puedes reproducirlo
  en el futuro.

Por eso necesitamos versionar los tres. Git resuelve el código. DVC,
LakeFS o Delta Lake resuelven los datos. MLflow, Weights & Biases o
similares resuelven el modelo y los experimentos.

\newpage

# 4. Ciclo de vida: CRISP-DM y CRISP-ML(Q)

CRISP-DM es el ciclo clásico de minería de datos (propuesto en 1996,
sigue vigente):

1. Entendimiento del negocio.
2. Entendimiento de los datos.
3. Preparación de los datos.
4. Modelado.
5. Evaluación.
6. Despliegue.

CRISP-ML(Q) es una revisión moderna (Studer et al., 2021) que añade
explícitamente:

- **Calidad de datos** como fase propia y continua.
- **Monitorización** posterior al despliegue.
- **Mantenimiento**: drift, retraining, retirada del modelo.

En la práctica, MLOps implementa CRISP-ML(Q) con herramientas
concretas. En este curso vas a ver cada herramienta para cada fase.

\newpage

# 5. Niveles de madurez MLOps (modelo de Google)

Google publicó un whitepaper muy conocido (*MLOps: Continuous
delivery and automation pipelines in machine learning*) con tres
niveles de madurez. Es la forma más extendida de diagnosticar dónde
está una organización.

## 5.1 Nivel 0 — Proceso manual

- El data scientist trabaja en un notebook.
- Entrega un fichero `.pkl` o despliega manualmente al servidor.
- No hay tests automáticos del modelo.
- No hay tracking de experimentos.
- Si algo falla, se rehace a mano.

La mayoría de organizaciones está aquí, aunque alguna no lo admita.

## 5.2 Nivel 1 — Pipeline ML automatizado

- El entrenamiento es un pipeline reproducible, no un notebook.
- Hay validación de datos automática.
- Hay un registry de modelos.
- El despliegue está automatizado.
- Existe monitorización básica.

Llegar aquí ya supone un cambio cultural y técnico importante. Al
final de este curso podrás reconocer todas las piezas de un Nivel 1
y reproducirlas.

## 5.3 Nivel 2 — CI/CD completo

- Cada commit puede disparar entrenamiento, evaluación, promoción y
  despliegue.
- Reentrenamiento automático ante drift.
- Despliegues canary o blue-green.
- Observabilidad completa con alerting.
- Rollback automático.

Pocas organizaciones tienen este nivel completo, y casi siempre solo
para sus modelos críticos.

\newpage

# 6. Roles en un equipo MLOps

| Rol | Responsabilidad principal |
|-----|---------------------------|
| Data Engineer | Pipelines de datos, calidad, almacenamiento |
| Data Scientist | Modelado, experimentación, feature engineering |
| ML Engineer | Productivización del modelo, código de calidad |
| MLOps Engineer | Plataforma, automatización, observabilidad |
| SRE / ML Platform | Infraestructura, escalado, fiabilidad |

En equipos pequeños, una sola persona cubre varios roles. En equipos
grandes hay especialización clara. Lo importante es que **alguien**
se haga cargo de cada función.

\newpage

# 7. Ejercicio: diagnóstico de madurez

> **Objetivo del ejercicio:** poner en práctica el modelo de madurez
> de Google sobre tres escenarios reales. No necesitas ordenador, lo
> haces a mano o en grupo.

Lee cada escenario y decide en qué nivel está. Argumenta tu
respuesta. Después contrasta con la solución sugerida al final.

## Escenario A

Una startup de logística entrena cada semana un modelo de previsión
de demanda. El data scientist tiene un notebook, lo ejecuta los
lunes, exporta a `.pkl`, lo sube por SFTP al servidor de la API. La
API recarga el modelo al reiniciarse. Hay un README de cinco líneas.
No hay tests.

**Tu diagnóstico:** ___________

## Escenario B

Un banco tiene un modelo de scoring de crédito. Cada commit a `main`
dispara un workflow de GitHub Actions que entrena, evalúa contra un
dataset golden, registra en MLflow y, si supera al actual, lo
promociona a Staging para QA manual. Producción se aprueba por pull
request.

**Tu diagnóstico:** ___________

## Escenario C

Un retailer entrena un modelo de recomendación cada noche con
Airflow, tiene un model registry, monitoring con Evidently,
retraining automático si el drift supera un umbral, despliegue canary
del 5 %, y un dashboard que su SRE mira a las 9 de la mañana. Si
algo falla, rollback automático.

**Tu diagnóstico:** ___________

\newpage

## Solución sugerida

**Escenario A:** Nivel 0. Es el clásico ML en notebook con despliegue
manual. Sin tests, sin tracking, sin reproducibilidad. La mayoría de
proyectos al empezar están aquí.

**Escenario B:** Nivel 1 alto, casi Nivel 2. Tiene CI/CD, registry,
evaluación automática y promoción condicional. Le falta CT
(continuous training) automático y monitoring de drift para llegar a
Nivel 2 completo.

**Escenario C:** Nivel 2. Tiene los tres bucles (CI, CD, CT),
observabilidad completa, estrategia de despliegue gradual y
rollback automático.

**¿Y tu organización?** Si hay otros alumnos en clase, comentadlo en
voz alta. Casi siempre la respuesta sincera es "estamos en Nivel 0".
Eso está bien: este curso te enseña a moverte hacia Nivel 1.

\newpage

# 8. Vocabulario mínimo

| Término | Significado |
|---------|-------------|
| Reproducibilidad | Capacidad de obtener exactamente el mismo modelo dadas las mismas entradas |
| Experiment | Conjunto de ejecuciones de entrenamiento para un mismo problema |
| Run | Una ejecución concreta dentro de un experiment |
| Model Registry | Almacén versionado de modelos con stages (Staging, Production, Archived) |
| Pipeline | Grafo de pasos automatizado (DVC, Airflow, Prefect, Dagster) |
| Drift | Cambio en la distribución de inputs (data drift) o de la relación input-output (concept drift) |
| Feature Store | Almacén compartido de features para entrenamiento y servicio |
| Model Card | Documento estandarizado que describe propósito, datos y limitaciones de un modelo |
| Audit trail | Registro completo y trazable de qué predicciones hizo cada modelo, cuándo y con qué inputs |

\newpage

# 9. Para profundizar

Si quieres ir más allá:

- Sculley et al., *Hidden Technical Debt in Machine Learning
  Systems* (NeurIPS 2015). Es el paper fundacional.
- Studer et al., *Towards CRISP-ML(Q)* (2021). Para entender el
  ciclo de vida moderno.
- Google Cloud, *MLOps: Continuous delivery and automation pipelines
  in machine learning* (whitepaper). Es donde se define el modelo de
  madurez.
- **ml-ops.org**. Hoja de ruta de la comunidad MLOps.
- **Made With ML** (https://madewithml.com). Tutoriales gratuitos
  excelentes.
