"""
Inyecta drift sintético sobre el test set del Lab 1 (Heart Failure).

Simula tres cambios clínicos plausibles que podrían ocurrir en
producción real:

  1. Población más mayor: shift positivo en age (la base de pacientes
     envejece con el tiempo).
  2. Más casos de hipertensión: aumento de prevalencia en
     high_blood_pressure (cambio de criterio diagnóstico, por ej).
  3. Distribución de creatinine_phosphokinase desplazada: cambio en
     el laboratorio que mide o en la población de referencia.
  4. Leve cambio de prevalencia del target DEATH_EVENT.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

SRC = Path("../lab1_dataops/data/processed/test.parquet")
OUT = Path("data/processed/drifted.parquet")


def main() -> None:
    df = pd.read_parquet(SRC).copy()

    rng = np.random.default_rng(42)

    # 1) shift en age: la población es +8 años de media
    if "age" in df.columns:
        df["age"] = (df["age"] + 8).clip(upper=110)

    # 2) más prevalencia de high_blood_pressure (10% más casos)
    if "high_blood_pressure" in df.columns:
        zero_idx = df.index[df["high_blood_pressure"] == 0]
        n_flip = max(1, int(len(zero_idx) * 0.10))
        flip = rng.choice(zero_idx, size=n_flip, replace=False)
        df.loc[flip, "high_blood_pressure"] = 1

    # 3) shift en creatinine_phosphokinase (cambio de laboratorio o método)
    if "creatinine_phosphokinase" in df.columns:
        df["creatinine_phosphokinase"] = (
            df["creatinine_phosphokinase"] * 1.5 + rng.normal(100, 50, len(df))
        ).clip(lower=1).astype(int)

    # 4) leve cambio de prevalencia del target (4% de etiquetas cambian)
    if "DEATH_EVENT" in df.columns:
        rng2 = np.random.default_rng(7)
        flip_idx = rng2.choice(df.index, size=max(1, len(df) // 25), replace=False)
        df.loc[flip_idx, "DEATH_EVENT"] = 1 - df.loc[flip_idx, "DEATH_EVENT"]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(OUT, index=False)
    print(f"OK · {OUT} ({len(df)} filas con drift inyectado)")


if __name__ == "__main__":
    main()
