# DÍA 1 — DataOps y fundamentos de MLOps

**Duración:** 4 h (240 min) · **Carga:** teoría 50 % · práctica 50 %

## Hoja de ruta del día

| Hora aprox.    | Bloque                                       | Tipo    |
|----------------|----------------------------------------------|---------|
| 00:00 – 00:45  | **Módulo 1** — Introducción MLOps / DataOps  | Teoría  |
| 00:45 – 01:35  | **Módulo 2** — DataOps (versionado, calidad) | Teoría  |
| 01:35 – 02:25  | **Lab 1** — DVC + Great Expectations         | Práctica|
| 02:25 – 02:35  | Pausa                                        | —       |
| 02:35 – 03:25  | **Módulo 3** — Experiment tracking (MLflow)  | Teoría  |
| 03:25 – 04:00  | **Lab 2** — MLflow Tracking + Model Registry | Práctica|

## Cómo seguir el día

1. **Entorno arriba antes de empezar.** En la carpeta `docker/` ejecuta:
   ```bash
   docker compose up -d
   ```
   Comprueba con `docker compose ps` que los cinco servicios están `Up`.
2. **Material a mano.** Abre este PDF en una mitad de la pantalla y Jupyter (`http://localhost:8888`, token `anban`) en la otra.
3. **Anota dudas en el cuadernillo.** Cada módulo tiene preguntas guía al final que se discuten en pausa.
4. **Si te pierdes en un lab.** No bloquees al grupo: salta al siguiente módulo y retoma el lab en la pausa o en casa con el README correspondiente.

## Lo que debes lograr al final del Día 1

- Diagnosticar el nivel de madurez MLOps de un sistema ML real.
- Versionar un dataset con DVC y validarlo con Great Expectations.
- Trackear experimentos con MLflow y promocionar el mejor modelo a *Staging*.
