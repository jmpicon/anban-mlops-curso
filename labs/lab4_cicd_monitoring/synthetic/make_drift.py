"""
Inyecta drift sintético en el dataset de test del Lab 1 para entrenar el ojo.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

SRC = Path("../lab1_dataops/data/processed/test.parquet")
OUT = Path("data/processed/drifted.parquet")


def main() -> None:
    df = pd.read_parquet(SRC).copy()

    # 1) shift en hours_per_week (gente trabaja menos)
    if "hours_per_week" in df.columns:
        df["hours_per_week"] = (df["hours_per_week"] * 0.85).astype(int)

    # 2) cambio en distribución de capital_gain (mucho ruido)
    if "capital_gain" in df.columns:
        rng = np.random.default_rng(42)
        df["capital_gain"] = df["capital_gain"] + rng.normal(2000, 1500, len(df))
        df["capital_gain"] = df["capital_gain"].clip(lower=0)

    # 3) leve cambio de prevalencia
    if "income" in df.columns:
        rng = np.random.default_rng(7)
        flip_idx = rng.choice(df.index, size=len(df) // 25, replace=False)
        df.loc[flip_idx, "income"] = 1 - df.loc[flip_idx, "income"]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(OUT, index=False)
    print(f"OK · {OUT} ({len(df)} filas con drift inyectado)")


if __name__ == "__main__":
    main()
