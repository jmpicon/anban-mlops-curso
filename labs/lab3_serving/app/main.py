"""
API de inferencia para el modelo heart-failure-clf.

Carga el modelo desde MLflow Model Registry (Staging por defecto) y lo
expone via FastAPI con validación Pydantic y endpoints de
health/version/predict/metrics.
"""
from __future__ import annotations

import os
import time
import uuid
from contextlib import asynccontextmanager
from typing import Any

import mlflow
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse, PlainTextResponse
from pydantic import BaseModel, Field

MODEL_URI = os.environ.get("MODEL_URI", "models:/heart-failure-clf/Staging")
MLFLOW_URI = os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000")

state: dict[str, Any] = {
    "model": None,
    "run_id": None,
    "signature": None,
    "loaded_at": None,
    "predictions": 0,
    "errors": 0,
    "latency_sum_ms": 0.0,
}


class Features(BaseModel):
    """Features clínicas que necesita el modelo de insuficiencia
    cardíaca. NO incluimos 'time' porque es leakage (tiempo hasta el
    evento, no disponible al predecir).
    """
    age: float = Field(ge=18, le=110, description="Edad en años")
    anaemia: int = Field(ge=0, le=1, description="1 si hay anemia")
    creatinine_phosphokinase: int = Field(ge=1, le=12000,
        description="CPK en suero (U/L)")
    diabetes: int = Field(ge=0, le=1, description="1 si es diabético")
    ejection_fraction: int = Field(ge=5, le=90,
        description="Fracción de eyección ventricular (%)")
    high_blood_pressure: int = Field(ge=0, le=1,
        description="1 si hay hipertensión")
    platelets: float = Field(ge=10000, le=1000000,
        description="Plaquetas (kiloplaquetas/mL)")
    serum_creatinine: float = Field(ge=0.1, le=20.0,
        description="Creatinina sérica (mg/dL)")
    serum_sodium: int = Field(ge=100, le=160,
        description="Sodio en suero (mEq/L)")
    sex: int = Field(ge=0, le=1, description="0=mujer, 1=hombre")
    smoking: int = Field(ge=0, le=1, description="1 si fuma")


class Prediction(BaseModel):
    label: int
    proba: float
    model_uri: str
    request_id: str
    latency_ms: float


def _expected_columns() -> list[str]:
    sig = state["signature"]
    if sig is None or sig.inputs is None:
        return []
    return [c.name for c in sig.inputs.inputs]


def _to_frame(payload: Features) -> pd.DataFrame:
    """Convierte el payload Pydantic a DataFrame con los tipos que
    espera el modelo según su signature."""
    df = pd.DataFrame([payload.model_dump()])

    sig = state["signature"]
    type_by_col: dict[str, str] = {}
    if sig is not None and sig.inputs is not None:
        for c in sig.inputs.inputs:
            # c.type es un Enum (DataType.long, DataType.double, ...).
            # Usamos .name para quedarnos con "long", "double", etc.
            type_by_col[c.name] = getattr(c.type, "name", str(c.type))

    # Alinear con las columnas esperadas (por si el modelo tiene un
    # orden distinto al del payload).
    expected = _expected_columns()
    if expected:
        for c in expected:
            if c not in df.columns:
                df[c] = 0
        df = df[expected]

    # Forzar dtypes coherentes con la signature del modelo.
    for col, t in type_by_col.items():
        if col not in df.columns:
            continue
        if t == "boolean":
            df[col] = df[col].astype(bool)
        elif t == "long":
            df[col] = df[col].astype("int64")
        elif t in ("double", "float"):
            df[col] = df[col].astype("float64")
    return df


@asynccontextmanager
async def lifespan(app: FastAPI):
    mlflow.set_tracking_uri(MLFLOW_URI)
    print(f"loading model from {MODEL_URI}")
    state["model"] = mlflow.pyfunc.load_model(MODEL_URI)
    md = state["model"].metadata
    state["run_id"] = md.run_id if md else None
    state["signature"] = md.signature if md else None
    state["loaded_at"] = time.time()
    print(f"model loaded · run_id={state['run_id']}")
    yield


app = FastAPI(
    title="Heart Failure Risk API",
    version="0.1.0",
    description=(
        "Predice el riesgo de muerte tras un evento de insuficiencia "
        "cardíaca. Modelo entrenado con el dataset Heart Failure "
        "Clinical Records (UCI, 2020). Uso docente. NO usar para "
        "decisiones clínicas reales."
    ),
    lifespan=lifespan,
)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok" if state["model"] is not None else "loading",
        "uptime_s": int(time.time() - (state["loaded_at"] or time.time())),
    }


@app.get("/version")
def version() -> dict[str, Any]:
    sig = state["signature"]
    return {
        "model_uri": MODEL_URI,
        "run_id": state["run_id"],
        "signature": str(sig) if sig else None,
        "predictions_served": state["predictions"],
    }


@app.post("/predict", response_model=Prediction)
def predict(payload: Features) -> Prediction:
    if state["model"] is None:
        raise HTTPException(503, "model not ready")
    rid = uuid.uuid4().hex[:12]
    t0 = time.perf_counter()
    try:
        X = _to_frame(payload)
        proba = float(state["model"].predict(X)[0])
        # Si el modelo devuelve la clase (0/1) en lugar de la
        # probabilidad, esto castea correctamente.
        label = int(proba >= 0.5)
    except Exception as exc:  # noqa: BLE001
        state["errors"] += 1
        raise HTTPException(500, f"inference failed: {exc}") from exc
    dt = (time.perf_counter() - t0) * 1000
    state["predictions"] += 1
    state["latency_sum_ms"] += dt
    return Prediction(
        label=label, proba=proba, model_uri=MODEL_URI,
        request_id=rid, latency_ms=round(dt, 2),
    )


@app.get("/metrics", response_class=PlainTextResponse)
def metrics() -> str:
    n = max(state["predictions"], 1)
    avg = state["latency_sum_ms"] / n
    return (
        f"# HELP api_predictions_total total predictions served\n"
        f"# TYPE api_predictions_total counter\n"
        f"api_predictions_total {state['predictions']}\n"
        f"# HELP api_errors_total total errors\n"
        f"# TYPE api_errors_total counter\n"
        f"api_errors_total {state['errors']}\n"
        f"# HELP api_latency_avg_ms average inference latency\n"
        f"# TYPE api_latency_avg_ms gauge\n"
        f"api_latency_avg_ms {avg:.2f}\n"
    )


@app.exception_handler(Exception)
def fallback_handler(_request, exc):
    return JSONResponse(status_code=500, content={"error": str(exc)})
