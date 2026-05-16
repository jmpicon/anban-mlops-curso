"""
Preprocesa UCI Adult: limpia, codifica y particiona en train/test.
Lee parámetros de ``params.yaml`` para que DVC los considere dependencia.
"""
from __future__ import annotations

from pathlib import Path

import pandas as pd
import yaml
from sklearn.model_selection import train_test_split

from ge_validate import EXPECTED_COLUMNS  # reuso

PARAMS = yaml.safe_load(Path("params.yaml").read_text())["preprocess"]
SRC = Path("data/raw/adult.csv")
OUT = Path("data/processed")
OUT.mkdir(parents=True, exist_ok=True)


def main() -> None:
    df = pd.read_csv(
        SRC,
        header=None,
        names=EXPECTED_COLUMNS,
        skipinitialspace=True,
        na_values="?",
    )
    df = df.dropna(subset=["workclass", "occupation", "native_country"])
    df = df.drop(columns=PARAMS["drop_columns"])

    df["income"] = (df["income"].str.strip() == ">50K").astype(int)

    cat_cols = df.select_dtypes(include="object").columns.tolist()
    df = pd.get_dummies(df, columns=cat_cols, drop_first=True)

    X = df.drop(columns=["income"])
    y = df["income"]

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


if __name__ == "__main__":
    main()
