# DÍA 2 — MLOps en producción

**Duración:** 4 h (240 min) · **Carga:** teoría 50 % · práctica 50 %

## Hoja de ruta del día

| Hora aprox.    | Bloque                                          | Tipo    |
|----------------|-------------------------------------------------|---------|
| 00:00 – 00:35  | **Módulo 4** — Empaquetado y serving (FastAPI)  | Teoría  |
| 00:35 – 01:15  | **Lab 3** — FastAPI + Docker                    | Práctica|
| 01:15 – 02:05  | **Módulo 5** — CI/CD + Monitoring + Drift       | Teoría  |
| 02:05 – 02:55  | **Lab 4** — GitHub Actions + Evidently          | Práctica|
| 02:55 – 03:05  | Pausa                                           | —       |
| 03:05 – 03:55  | **Módulo 6** — Caso integrador + Governance     | Mixto   |
| 03:55 – 04:00  | Cierre, Q&A y hoja de ruta                      | —       |

## Prerrequisitos del Día 2

- Tienes el modelo del Día 2 promocionado en MLflow a `Staging` (Lab 2).
- El stack docker está arriba: `docker compose ps` muestra los cinco servicios `Up`.
- Si reiniciaste el equipo: `docker compose start` (no `up`) para conservar los runs.

Si te falta algo de lo anterior, repasa el Lab 2 antes de continuar — los labs del Día 2 dependen del modelo registrado.

## Lo que debes lograr al final del Día 2

- Servir el modelo registrado como API REST con FastAPI dentro de un contenedor Docker.
- Tener un pipeline CI/CD que entrena, evalúa, promociona y construye la imagen automáticamente.
- Detectar *data drift* con Evidently y razonar qué falta para llevar el sistema a producción real.
