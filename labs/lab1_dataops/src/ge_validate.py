"""
Validador de calidad para el dataset UCI Adult.

Cuatro comprobaciones rápidas. Termina con código 0 si pasan todas, o 1
si falla alguna (eso permite usarlo como gate en DVC o en CI).
"""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

EXPECTED_COLUMNS = [
    "age", "workclass", "fnlwgt", "education", "education_num",
    "marital_status", "occupation", "relationship", "race", "sex",
    "capital_gain", "capital_loss", "hours_per_week", "native_country",
    "income",
]

WORKCLASS_DOMAIN = {
    "Private", "Self-emp-not-inc", "Self-emp-inc", "Federal-gov",
    "Local-gov", "State-gov", "Without-pay", "Never-worked",
}


def load(path: Path) -> pd.DataFrame:
    # El CSV original de UCI Adult NO tiene cabecera. Pasamos los nombres
    # nosotros y limpiamos los espacios iniciales de cada celda.
    return pd.read_csv(
        path,
        header=None,
        names=EXPECTED_COLUMNS,
        skipinitialspace=True,
        na_values=["?"],
    )


def expect_columns(df: pd.DataFrame) -> None:
    missing = set(EXPECTED_COLUMNS) - set(df.columns)
    assert not missing, f"faltan columnas: {missing}"
    print("[OK] schema (las 15 columnas esperadas están presentes)")


def expect_age_range(df: pd.DataFrame, lo: int = 17, hi: int = 90) -> None:
    bad = df[(df["age"] < lo) | (df["age"] > hi)]
    assert bad.empty, f"{len(bad)} filas con age fuera de [{lo}, {hi}]"
    print(f"[OK] age dentro de [{lo}, {hi}]")


def expect_workclass_in_domain(df: pd.DataFrame) -> None:
    vals = set(df["workclass"].dropna().unique())
    extras = vals - WORKCLASS_DOMAIN
    assert not extras, f"valores inesperados en workclass: {extras}"
    print("[OK] workclass dentro del dominio conocido")


def expect_income_not_null(df: pd.DataFrame) -> None:
    nulls = df["income"].isna().sum()
    assert nulls == 0, f"income tiene {nulls} nulos"
    print("[OK] income sin nulos")


def main(path: str) -> int:
    df = load(Path(path))
    expect_columns(df)
    expect_age_range(df)
    expect_workclass_in_domain(df)
    expect_income_not_null(df)
    print("\nTODAS LAS EXPECTATIVAS PASADAS")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("uso: ge_validate.py <ruta-csv>", file=sys.stderr)
        sys.exit(2)
    try:
        sys.exit(main(sys.argv[1]))
    except AssertionError as exc:
        print(f"\n[FALLO] {exc}", file=sys.stderr)
        sys.exit(1)
