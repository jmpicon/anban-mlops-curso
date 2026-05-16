# Datasets del curso

## UCI Adult Income

- **URL:** https://archive.ics.uci.edu/dataset/2/adult
- **Año:** 1996 (datos de 1994)
- **Tarea:** clasificación binaria (income > 50K)
- **Tamaño:** ~32k filas, 14 features
- **Licencia:** CC BY 4.0 (UCI ML Repository)
- **Sesgos conocidos:** EE.UU. 1994, sub-representación demográfica

```bash
mkdir -p datasets/adult
curl -L https://archive.ics.uci.edu/ml/machine-learning-databases/adult/adult.data \
     -o datasets/adult/adult.csv
```

> Si la sala no tiene salida a Internet, lleva el CSV en USB y déjalo en
> `datasets/adult/adult.csv` antes de empezar.

## Por qué este dataset

- Pequeño (caben los pipelines en RAM y entrenan en segundos).
- Mezcla numérico + categórico → muestra encoding y schema.
- Tiene sesgos conocidos → excelente para discutir governance.
- No tiene texto libre → no necesitamos NLP en clase.
