"""
API de inferencia para income-clf.

Carga el modelo desde MLflow Model Registry (Staging por defecto) y lo
expone vía FastAPI con validación Pydantic y endpoints de health/version.
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

MODEL_URI = os.environ.get("MODEL_URI", "models:/income-clf/Staging")
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
    age: int = Field(ge=17, le=90)
    workclass: str
    education_num: int = Field(ge=0, le=20)
    marital_status: str
    occupation: str
    relationship: str
    race: str
    sex: str
    capital_gain: int = Field(ge=0)
    capital_loss: int = Field(ge=0)
    hours_per_week: int = Field(ge=0, le=99)
    native_country: str


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
    df = pd.DataFrame([payload.model_dump()])
    df = pd.get_dummies(df)
    expected = _expected_columns()
    sig = state["signature"]
    type_by_col: dict[str, str] = {}
    if sig is not None and sig.inputs is not None:
        for c in sig.inputs.inputs:
            # c.type es un Enum (DataType.long, DataType.boolean...).
            # Usamos .name para quedarnos con "long", "boolean", "double".
            type_by_col[c.name] = getattr(c.type, "name", str(c.type))

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
        elif t == "double" or t == "float":
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
    title="Income Classifier API",
    version="0.1.0",
    description="ANBAN MLOps course · Lab 3",
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
        # Si el modelo es un clasificador con predict_proba el wrapper puede
        # devolver la prob; si devuelve la clase, casteamos.
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
