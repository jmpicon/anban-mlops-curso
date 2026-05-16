# Lab 5 — Caso end-to-end + Governance

> Tiempo estimado: **45 min** (30 min ejecución + 15 min discusión)

## Objetivo

Recorrer el ciclo completo en una sola sesión y dejar evidencia de cada
etapa. Luego, en grupo, identificar qué **falta** para una producción
"real" más allá de un MVP didáctico.

## El recorrido en 8 comandos

```bash
# 1. dependencias y entorno
docker compose -f docker/docker-compose.yml up -d
pip install -r requirements.txt

# 2. datos
cd labs/lab1_dataops
dvc pull
dvc repro

# 3. tests
cd ../..
pytest -q

# 4. entrenamiento + tracking
python labs/lab2_mlflow_dvc/src/train.py --model rf

# 5. promoción
python labs/lab2_mlflow_dvc/src/register_best.py \
    --experiment income-classifier --metric f1 --name income-clf
python labs/lab2_mlflow_dvc/src/promote.py \
    --name income-clf --version 1 --stage Staging

# 6. servir
docker build -t anban/income-api:0.1 -f labs/lab3_serving/Dockerfile labs/lab3_serving
docker run -d --network anbam_default -p 8000:8000 \
    -e MLFLOW_TRACKING_URI=http://mlflow:5000 \
    anban/income-api:0.1

# 7. drift
python labs/lab4_cicd_monitoring/synthetic/make_drift.py
python labs/lab4_cicd_monitoring/src/drift_report.py \
    --reference labs/lab1_dataops/data/processed/test.parquet \
    --current labs/lab4_cicd_monitoring/data/processed/drifted.parquet \
    --output reports/drift.html

# 8. ¿supera al actual?
python labs/lab4_cicd_monitoring/src/promote_if_better.py \
    --name income-clf --metric f1 --min-improvement 0.01
```

## Checklist de governance (rellenar en grupo)

Para el modelo `income-clf` que acabamos de poner en Staging:

- [ ] **Model Card** redactada: propósito, datos, métricas, sesgos, contraindicaciones.
- [ ] **Owner** asignado y on-call documentado.
- [ ] **Métricas por subgrupo**: F1 por sex, race; ¿hay disparidad?
- [ ] **Privacidad**: ¿qué campos son PII? ¿anonimización adecuada?
- [ ] **DPIA** si afecta a decisiones automatizadas (RGPD Art. 35).
- [ ] **Decisión humana** posible si el modelo se usa como input.
- [ ] **Audit log**: ¿se puede saber qué predijo este modelo el día X?
- [ ] **Rollback**: ¿qué versión vuelve si la actual rompe?
- [ ] **Disaster Recovery**: ¿qué pasa si MinIO se cae con todos los runs?
- [ ] **Costes**: ¿qué cuesta entrenar y qué cuesta servir al mes?

## Discusión guiada (15 min)

Preguntas para el grupo:

1. ¿Qué falta para que esto sea producción "real" según el sector del alumno?
2. ¿Cómo gestionas secrets en CI? (no commitear nunca, GitHub Encrypted Secrets, Vault)
3. ¿Dónde vive el modelo realmente? (Registry, S3, K8s, Edge?)
4. Si el modelo se equivoca y un cliente reclama, ¿cómo trazas la decisión?
5. ¿Cuál sería el primer paso en tu organización el lunes?

## Entregable del curso

Un PR a tu repo personal con:

- el pipeline de datos versionado,
- 3 experimentos comparados,
- el modelo en el Registry,
- la API funcionando,
- un workflow CI verde,
- la Model Card redactada en Markdown.
