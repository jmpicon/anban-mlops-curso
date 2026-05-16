# Lab 1 — DataOps con DVC

Tiempo estimado: 40-50 minutos.

## Qué vas a aprender

A versionar datasets con DVC y a montar un pipeline reproducible que valide y preprocese los datos. Al acabar tendrás:

- Un repositorio git con un dataset trackeado FUERA de git.
- Un pipeline declarativo en `dvc.yaml`.
- Train y test en parquet, generados por el pipeline.
- El dataset replicado en MinIO.

---

## Cómo ejecutar el lab

Hay dos formas. La primera es la **recomendada en clase**.

### Opción A — Modo asistido (recomendado)

Un solo comando. El script te va explicando lo que hace.

```bash
./run.sh
```

Tienes que pulsar Enter entre paso y paso. Lee lo que sale en pantalla, está pensado para que entiendas qué pasa.

### Opción B — Modo manual

Sigue los pasos del PDF del módulo 2 tecleando los comandos tú mismo. Es lo que harías en tu trabajo real.

---

## Antes de empezar

Tiene que estar levantado el stack:

```bash
# desde la raíz del repo:
./setup.sh
```

Comprueba abriendo http://localhost:9001 que ves la consola de MinIO.

---

## Si algo falla

Ejecuta desde la raíz del repo:

```bash
./doctor.sh
```

Y comparte la salida con el profesor.

---

## Estructura de este lab

```
lab1_dataops/
├── README.md             ← esto que lees
├── run.sh                ← script asistido (Opción A)
├── src/
│   ├── ge_validate.py    ← validaciones del dataset
│   └── preprocess.py     ← split en train/test
├── params.yaml           ← parámetros del preprocesado
└── dvc.yaml              ← se genera durante el lab
```

La carpeta `data/` se crea durante la ejecución. Los CSV grandes NUNCA viven dentro de Git, viven en MinIO via DVC.

---

## Tras completar el lab

Comprobaciones que debes poder marcar:

- [ ] `git log --oneline` muestra varios commits y ningún CSV pesado dentro.
- [ ] `dvc status` dice que todo está limpio.
- [ ] Existen `data/processed/train.parquet` y `data/processed/test.parquet`.
- [ ] En MinIO (http://localhost:9001 → bucket `datasets`) hay un blob con el hash del CSV.
- [ ] Entiendes qué pasó cuando ejecutamos `dvc repro` con el dato roto.

Cuando lo tengas, salta al lab siguiente:

```bash
cd ../lab2_mlflow_dvc && ./run.sh
```
