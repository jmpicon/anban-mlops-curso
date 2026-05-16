"""
Validador de calidad para el dataset Heart Failure Clinical Records.

Cinco comprobaciones rápidas. Termina con código 0 si pasan todas, o 1
si falla alguna (eso permite usarlo como gate en DVC o en CI).

Las comprobaciones cubren:
  - schema: columnas esperadas presentes.
  - completitud: no hay nulos.
  - rangos clínicos: valores plausibles para cada feature numérica.
  - dominio binario: las columnas que deben ser 0/1 lo son.
  - target: balance razonable de DEATH_EVENT.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pandas as pd

EXPECTED_COLUMNS = [
    "age",
    "anaemia",
    "creatinine_phosphokinase",
    "diabetes",
    "ejection_fraction",
    "high_blood_pressure",
    "platelets",
    "serum_creatinine",
    "serum_sodium",
    "sex",
    "smoking",
    "time",
    "DEATH_EVENT",
]

# Columnas que deben ser 0 o 1.
BINARY_COLUMNS = [
    "anaemia",
    "diabetes",
    "high_blood_pressure",
    "sex",
    "smoking",
    "DEATH_EVENT",
]

# Rangos clínicos plausibles (con margen). Si tu dato cae fuera, el
# validador para el pipeline y te avisa antes de entrenar modelos malos.
NUMERIC_RANGES = {
    "age": (18, 110),
    "creatinine_phosphokinase": (1, 12000),
    "ejection_fraction": (5, 90),        # porcentaje
    "platelets": (10000, 1000000),       # plaquetas/mL
    "serum_creatinine": (0.1, 20.0),     # mg/dL
    "serum_sodium": (100, 160),          # mEq/L
    "time": (1, 365),                    # días de seguimiento
}


def load(path: Path) -> pd.DataFrame:
    """Lee el CSV. El fichero tiene cabecera, no hace falta names="""
    return pd.read_csv(path)


def expect_columns(df: pd.DataFrame) -> None:
    missing = set(EXPECTED_COLUMNS) - set(df.columns)
    assert not missing, f"faltan columnas: {missing}"
    print("[OK] schema (las 13 columnas esperadas están presentes)")


def expect_no_nulls(df: pd.DataFrame) -> None:
    nulls = df.isna().sum()
    bad = nulls[nulls > 0]
    assert bad.empty, f"hay nulos: {bad.to_dict()}"
    print("[OK] sin valores nulos en ninguna columna")


def expect_numeric_ranges(df: pd.DataFrame) -> None:
    for col, (lo, hi) in NUMERIC_RANGES.items():
        bad = df[(df[col] < lo) | (df[col] > hi)]
        assert bad.empty, (
            f"{len(bad)} filas con {col} fuera de [{lo}, {hi}]; "
            f"ejemplos: {bad[col].head(3).tolist()}"
        )
    print(f"[OK] rangos clínicos plausibles en {len(NUMERIC_RANGES)} columnas")


def expect_binary_domain(df: pd.DataFrame) -> None:
    for col in BINARY_COLUMNS:
        unique_vals = set(df[col].dropna().unique())
        extras = unique_vals - {0, 1}
        assert not extras, f"{col} tiene valores fuera de {{0,1}}: {extras}"
    print(f"[OK] dominio binario correcto en {len(BINARY_COLUMNS)} columnas")


def expect_target_balance(df: pd.DataFrame) -> None:
    positives = df["DEATH_EVENT"].mean()
    assert 0.05 < positives < 0.95, (
        f"DEATH_EVENT demasiado desbalanceado: positives={positives:.3f}"
    )
    print(f"[OK] target balanceado razonablemente (positives={positives:.1%})")


def main(path: str) -> int:
    df = load(Path(path))
    expect_columns(df)
    expect_no_nulls(df)
    expect_numeric_ranges(df)
    expect_binary_domain(df)
    expect_target_balance(df)
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
