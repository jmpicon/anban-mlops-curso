"""
Preprocesa el dataset Heart Failure Clinical Records:
- Quita la columna `time` (es leakage: representa el tiempo hasta el
  evento y no estará disponible en producción cuando hagamos la
  predicción para un paciente nuevo).
- Quita otras columnas según params.yaml si las añades.
- Divide en train/test con estratificación por DEATH_EVENT.

No hace falta one-hot encoding: todas las features son numéricas o
binarias.

Los parámetros viven en params.yaml para que DVC los detecte como
dependencia y reejecute solo lo necesario.
"""
from __future__ import annotations

from pathlib import Path

import pandas as pd
import yaml
from sklearn.model_selection import train_test_split

PARAMS = yaml.safe_load(Path("params.yaml").read_text())["preprocess"]
SRC = Path("data/raw/heart_failure.csv")
OUT = Path("data/processed")
OUT.mkdir(parents=True, exist_ok=True)

TARGET = "DEATH_EVENT"


def main() -> None:
    df = pd.read_csv(SRC)

    # Quitamos columnas que NO se deben usar para entrenar.
    drop_cols = PARAMS.get("drop_columns", [])
    df = df.drop(columns=[c for c in drop_cols if c in df.columns])

    X = df.drop(columns=[TARGET])
    y = df[TARGET]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y,
        test_size=PARAMS["test_size"],
        random_state=PARAMS["random_state"],
        stratify=y,
    )

    pd.concat([X_train, y_train], axis=1).to_parquet(OUT / "train.parquet", index=False)
    pd.concat([X_test, y_test], axis=1).to_parquet(OUT / "test.parquet", index=False)

    print(f"train: {X_train.shape} | test: {X_test.shape}")
    print(f"positives: train={y_train.mean():.3f} test={y_test.mean():.3f}")
    print(f"columnas usadas: {list(X_train.columns)}")


if __name__ == "__main__":
    main()
