---
title: "Curso MLOps / DataOps"
subtitle: "Manual del alumno · 2 días · paso a paso"
author: "José Picón · ANBAN"
date: "2026"
lang: es
---

# Cómo usar este manual

Este cuadernillo recoge **todo el curso en un único PDF** organizado por días. Cada día encadena teoría, demos y laboratorios en el orden exacto en el que se imparten en el aula. La idea es que puedas seguir la sesión sin perderte y, después de clase, repasar o reproducir cualquier paso por tu cuenta.

## Estructura

- **Instalación del entorno por sistema operativo** (Windows, macOS, Linux).
- **Conceptos clave con ejemplos** — qué hace DVC, MLflow, FastAPI, Evidently y los demás, con un ejemplo concreto y una analogía. Lectura previa muy recomendable.
- **Día 1 — DataOps y fundamentos de MLOps** (Módulos 1–3 + Labs 1–2).
- **Día 2 — MLOps en producción** (Módulos 4–6 + Labs 3–5).
- **Guía paso a paso de los labs con explicaciones** — cada fase de cada lab explicada en prosa: qué hace el comando, por qué lo necesitas, qué deberías ver.
- **Cheatsheet de comandos** — referencia rápida para los labs.
- **Errores frecuentes y soluciones** — diez secciones cubriendo los problemas que aparecen casi en cada edición.

## Cómo seguir la clase con este manual

1. Empieza por la introducción del día (`DÍA 1` o `DÍA 2`) para ver la hoja de ruta de las 4 horas.
2. Cada **módulo** se compone de:
   - Objetivos al inicio.
   - Teoría con apoyo de slides (referencia al rango de slides del PPTX).
   - Discusión y preguntas guía.
3. Cada **lab** trae:
   - Prerrequisitos.
   - Pasos numerados que reproducen lo que el profesor hace en pantalla.
   - Comprobaciones (`Comprueba que…`) para validar tu progreso.
   - Reto opcional al final.

## Antes de empezar: comprobaciones

Asegúrate de tener el entorno listo:

```bash
cd docker
docker compose up -d
docker compose ps
```

Los cinco servicios deben aparecer `Up` (Jupyter, MLflow, MinIO, Postgres, minio-init).

Accesos:

| Servicio        | URL                          | Credenciales              |
|-----------------|------------------------------|---------------------------|
| Jupyter         | http://localhost:8888        | token `anban`             |
| MLflow          | http://localhost:5050        | —                         |
| MinIO console   | http://localhost:9001        | `minio` / `minio12345`    |
| PostgreSQL      | localhost:5432               | `mlflow` / `mlflow` (db `mlflow`) |

Si algún puerto está ocupado, edita el lado izquierdo del `:` en `docker/docker-compose.yml`.

## Convenciones tipográficas

- `código entre comillas`: comando que escribirás en terminal o en una celda de Jupyter.
- **Negrita**: concepto clave que se va a desarrollar.
- > Bloque citado: tip, advertencia o referencia rápida.
- *Cursiva*: término técnico en inglés, librería o producto.

Si tu entorno aún no está montado, empieza por **Instalación del entorno por sistema operativo**. Si ya tienes Docker y los servicios arriba, salta directo al **Día 1**. Si algo falla durante el curso, ve al apartado **Errores frecuentes y soluciones** del final.
