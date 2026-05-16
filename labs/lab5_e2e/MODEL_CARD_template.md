# Model Card — `heart-failure-clf`

> Adapta este template al modelo que hayas puesto en producción. Inspirado en
> Mitchell et al. (2019) *"Model Cards for Model Reporting"*.

## 1. Detalles del modelo

- **Nombre y versión:** heart-failure-clf v1
- **Tipo:** Clasificador binario (income > 50K)
- **Algoritmo:** Random Forest / XGBoost
- **Owner:** José Picón <jose.bobal@gmail.com>
- **Última actualización:** 2026-05-09
- **Repositorio:** `anbam/labs/lab2_mlflow_dvc`
- **Run ID MLflow:** `<run_id>`
- **Commit Git:** `<sha>`

## 2. Uso previsto

- Caso de uso pedagógico (ANBAN MLOps course).
- **No usar** para decisiones reales sobre personas físicas.

## 3. Datos de entrenamiento

- **Fuente:** UCI Adult Income (1994).
- **Tamaño:** ~32k filas tras limpieza.
- **Sesgos conocidos:** datos antiguos, EE.UU., distribución demográfica desigual.
- **Versión:** lab1-v1 (dvc hash `<hash>`).

## 4. Métricas

| Métrica   | Valor (test) |
|-----------|--------------|
| Accuracy  | 0.86         |
| F1        | 0.71         |
| ROC AUC   | 0.92         |
| Recall    | 0.62         |
| Precision | 0.83         |

### Métricas por subgrupo

| Subgrupo  | F1   |
|-----------|------|
| Male      | 0.74 |
| Female    | 0.59 |
| White     | 0.72 |
| Black     | 0.66 |
| ...       | ...  |

> **Hallazgo:** disparidad sexo/raza. Documentar y mitigar antes de
> cualquier uso real.

## 5. Limitaciones y riesgos

- Dataset histórico → no representativo del 2026.
- Variable de output basada en una umbral arbitrario (50K).
- Posible sesgo discriminatorio.
- Sin guardrails: el output binario debe interpretarlo un humano.

## 6. Reproducibilidad

```
git checkout <sha>
dvc pull
python labs/lab2_mlflow_dvc/src/train.py --model rf
```

## 7. Aprobaciones

| Rol            | Persona   | Fecha       | Comentario      |
|----------------|-----------|-------------|-----------------|
| Data Owner     |           |             |                 |
| ML Engineer    |           |             |                 |
| Product Owner  |           |             |                 |
| Compliance/DPO |           |             |                 |
