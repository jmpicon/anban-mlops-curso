# Lab 4 — CI/CD con GitHub Actions + Monitoring con Evidently

> Tiempo estimado: **50 min**

## Objetivo

1. Pipeline GitHub Actions que entrene, evalúe y promocione el modelo si
   bate al de Production.
2. Reporte Evidently comparando dataset de referencia vs uno con drift.
3. Endpoint `/monitor` en la API que devuelva métricas de drift.

## Estructura

```
.github/workflows/ml.yml     # workflow principal
src/promote_if_better.py     # promueve solo si supera al actual
src/drift_report.py          # genera HTML + JSON con Evidently
synthetic/make_drift.py      # crea un dataset 'drifted'
```

## Paso 1 · Workflow GitHub Actions

Ya está en `.github/workflows/ml.yml`. Stages:

1. **lint+test** — ruff + pytest
2. **train** — `python src/train.py --model rf` con MLflow apuntando a un
   tracking server temporal (en CI usamos un tracking local en SQLite +
   artifacts en `./mlruns` que subimos como artifact del job)
3. **evaluate-and-promote** — compara F1 con la versión Production y
   transiciona si `f1_new ≥ f1_prod * 1.01`

Para que funcione el job necesitas estos secrets en el repo:

- `MLFLOW_TRACKING_URI` (o usa el local en CI)
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` (si MinIO/S3 remoto)

## Paso 2 · Probar el promote local

```bash
python src/promote_if_better.py \
    --name income-clf \
    --candidate-version 2 \
    --metric f1 \
    --min-improvement 0.01
```

Sale 0 si promociona, 1 si rechaza.

## Paso 3 · Generar drift sintético y reporte

```bash
python synthetic/make_drift.py     # crea data/processed/drifted.parquet
python src/drift_report.py \
    --reference ../lab1_dataops/data/processed/test.parquet \
    --current data/processed/drifted.parquet \
    --output reports/drift.html
```

Abrir `reports/drift.html` en el navegador.

## Paso 4 · Endpoint /monitor

Añade el endpoint del Lab 4 a la API del Lab 3 (parche en
`extra/monitor_endpoint.py`). Reinicia, llama:

```bash
curl -s http://localhost:8000/monitor | jq
```

Devuelve:

```json
{
  "drift_score_overall": 0.34,
  "drifted_features": ["hours_per_week", "capital_gain"],
  "computed_at": "2026-05-09T10:23:45Z"
}
```

## Comprobaciones de cierre

- [ ] El workflow corre en push y muestra el resultado.
- [ ] `promote_if_better.py` rechaza un modelo peor.
- [ ] `drift.html` se ha generado correctamente.
- [ ] `/monitor` responde con `drift_score_overall`.

## Reto opcional

Configura un **schedule** semanal en el workflow que haga reentrenamiento
automático si el `drift_score_overall` > 0.25.
