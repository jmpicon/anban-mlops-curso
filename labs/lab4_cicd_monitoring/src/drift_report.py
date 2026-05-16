"""
Genera un reporte HTML de drift entre dos datasets con Evidently.
Si Evidently no está disponible, calcula PSI a mano y emite un HTML mínimo.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd


def psi(reference: pd.Series, current: pd.Series, bins: int = 10) -> float:
    """Population Stability Index para una columna."""
    # boolean → tratar como categórica de dos valores
    is_bool = reference.dtype == bool or current.dtype == bool
    is_numeric = (reference.dtype.kind in "iuf"
                  and current.dtype.kind in "iuf"
                  and not is_bool)

    if is_numeric:
        # mete protección por si todo es constante (rompería el quantile)
        try:
            breaks = np.unique(np.quantile(reference.dropna().to_numpy(),
                                           np.linspace(0, 1, bins + 1)))
        except Exception:
            return 0.0
        if len(breaks) < 3:
            return 0.0
        ref_hist, _ = np.histogram(reference.dropna(), bins=breaks)
        cur_hist, _ = np.histogram(current.dropna(), bins=breaks)
    else:
        # categórica (incluye booleanas y strings)
        cats = sorted(set(reference.dropna().unique()) | set(current.dropna().unique()),
                       key=lambda x: str(x))
        ref_hist = np.array([(reference == c).sum() for c in cats])
        cur_hist = np.array([(current == c).sum() for c in cats])

    ref_pct = np.where(ref_hist == 0, 1e-6, ref_hist / max(ref_hist.sum(), 1))
    cur_pct = np.where(cur_hist == 0, 1e-6, cur_hist / max(cur_hist.sum(), 1))
    return float(np.sum((cur_pct - ref_pct) * np.log(cur_pct / ref_pct)))


def fallback_html(scores: dict[str, float], output: Path) -> None:
    rows = "".join(
        f"<tr><td>{k}</td><td>{v:.4f}</td>"
        f"<td>{'⚠ drift' if v > 0.25 else 'ok'}</td></tr>"
        for k, v in sorted(scores.items(), key=lambda x: -x[1])
    )
    html = f"""<!doctype html><meta charset=utf-8>
<title>Drift report</title>
<style>body{{font-family:sans-serif;max-width:800px;margin:2em auto}}
table{{border-collapse:collapse;width:100%}}
td,th{{padding:8px;border:1px solid #ccc;text-align:left}}
th{{background:#0B1F3A;color:#fff}}</style>
<h1>Drift report (PSI)</h1>
<p>Umbral típico: < 0.1 ok · 0.1-0.25 watch · > 0.25 drift</p>
<table><tr><th>feature</th><th>PSI</th><th>status</th></tr>{rows}</table>
"""
    # encoding utf-8 explicito: en Windows por defecto usa cp1252 y
    # peta con caracteres unicode (el simbolo de advertencia, etc.).
    output.write_text(html, encoding="utf-8")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--reference", required=True)
    p.add_argument("--current", required=True)
    p.add_argument("--output", required=True)
    args = p.parse_args()

    ref = pd.read_parquet(args.reference)
    cur = pd.read_parquet(args.current)

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    try:
        from evidently.report import Report
        from evidently.metric_preset import DataDriftPreset, DataQualityPreset

        report = Report(metrics=[DataDriftPreset(), DataQualityPreset()])
        report.run(reference_data=ref, current_data=cur)
        report.save_html(str(out))
        as_json = report.as_dict()
        out.with_suffix(".json").write_text(
            json.dumps(as_json, indent=2, default=str),
            encoding="utf-8",
        )
        print(f"OK · evidently report -> {out}")
    except Exception as exc:
        print(f"evidently no disponible ({exc}); usando fallback PSI")
        common = [c for c in ref.columns if c in cur.columns]
        scores = {c: psi(ref[c], cur[c]) for c in common}
        fallback_html(scores, out)
        out.with_suffix(".json").write_text(
            json.dumps(scores, indent=2),
            encoding="utf-8",
        )
        print(f"OK · fallback report -> {out}")


if __name__ == "__main__":
    main()
