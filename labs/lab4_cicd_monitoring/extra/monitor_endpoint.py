"""
Parche didáctico del Lab 4 sobre la API del Lab 3.
Añade un endpoint /monitor que calcula PSI sobre los inputs recibidos en
una ventana en memoria. NO usar como diseño de producción real.
"""
from __future__ import annotations

import datetime as dt
from collections import deque

import pandas as pd
from fastapi import FastAPI

REFERENCE_PATH = "/data/test.parquet"
WINDOW = 200  # últimas N requests

ring: deque[dict] = deque(maxlen=WINDOW)
_reference = pd.read_parquet(REFERENCE_PATH)


def attach_monitor(app: FastAPI) -> None:
    @app.middleware("http")
    async def capture(request, call_next):
        if request.url.path == "/predict":
            try:
                payload = await request.json()
                ring.append(payload)
            except Exception:
                pass
        return await call_next(request)

    @app.get("/monitor")
    def monitor() -> dict:
        if len(ring) < 30:
            return {"status": "warming-up", "samples": len(ring)}
        cur = pd.DataFrame(list(ring))
        from src.drift_report import psi  # type: ignore
        scores = {}
        for col in cur.columns:
            if col in _reference.columns:
                scores[col] = round(psi(_reference[col], cur[col]), 4)
        drifted = [k for k, v in scores.items() if v > 0.25]
        return {
            "drift_score_overall": round(sum(scores.values()) / max(len(scores), 1), 4),
            "drifted_features": drifted,
            "per_feature": scores,
            "samples": len(ring),
            "computed_at": dt.datetime.utcnow().isoformat() + "Z",
        }
