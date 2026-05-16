# Datasets del curso

## Heart Failure Clinical Records (UCI, 2020)

- **URL:** https://archive.ics.uci.edu/dataset/519/heart+failure+clinical+records
- **Citación:** Chicco, D., & Jurman, G. (2020). Machine learning can
  predict survival of patients with heart failure from serum creatinine
  and ejection fraction alone. *BMC Medical Informatics and Decision
  Making*, 20(1), 1-16.
- **Licencia:** CC BY 4.0.
- **Tamaño:** 299 filas, 13 columnas.
- **Target:** `DEATH_EVENT` (0/1) — el paciente falleció durante el
  periodo de seguimiento.
- **Origen real:** Faisalabad Institute of Cardiology y Allied Hospital
  (Faisalabad, Pakistán), abril-diciembre 2015. Pacientes con
  insuficiencia cardíaca con fracción de eyección reducida (HFrEF).

### Por qué se usa en este curso

- Datos clínicos reales y modernos (2020).
- Tamaño pequeño: entrenamientos rápidos en el aula.
- Mezcla de features numéricas y binarias.
- Todas las features son interpretables médicamente, lo que enriquece
  las discusiones de gobernanza (RGPD, AI Act, fairness en salud).
- Tiene una columna (`time`) que es **leakage** y se debe excluir, lo
  cual sirve como caso didáctico real de ingeniería de features.

### Estructura del CSV

| Columna | Tipo | Descripción |
|---------|------|-------------|
| age | float | Edad del paciente (años) |
| anaemia | int (0/1) | 1 si hay reducción de hemoglobina |
| creatinine_phosphokinase | int | Enzima CPK en sangre (U/L) |
| diabetes | int (0/1) | 1 si es diabético |
| ejection_fraction | int | Sangre que sale del corazón por latido (%) |
| high_blood_pressure | int (0/1) | 1 si hay hipertensión |
| platelets | float | Plaquetas (kiloplaquetas/mL) |
| serum_creatinine | float | Creatinina en suero (mg/dL) |
| serum_sodium | int | Sodio en suero (mEq/L) |
| sex | int (0/1) | 0 = mujer, 1 = hombre |
| smoking | int (0/1) | 1 si fuma |
| time | int | Días de seguimiento (LEAKAGE, no usar para entrenar) |
| DEATH_EVENT | int (0/1) | TARGET |

### Descarga

Si necesitas volver a bajarlo:

```bash
curl -fsSL -o datasets/heart_failure/heart_failure.csv \
  "https://archive.ics.uci.edu/ml/machine-learning-databases/00519/heart_failure_clinical_records_dataset.csv"
```
