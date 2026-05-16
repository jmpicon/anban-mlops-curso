"""
Promueve la última versión registrada del modelo si supera al actual de
Production por al menos `min-improvement`. Pensado para correr en CI.
"""
from __future__ import annotations

import argparse
import os
import sys

import mlflow
from mlflow.tracking import MlflowClient


def latest_version(client: MlflowClient, name: str) -> str | None:
    versions = client.search_model_versions(f"name='{name}'")
    if not versions:
        return None
    return max(versions, key=lambda v: int(v.version)).version


def metric_for_version(client: MlflowClient, name: str, version: str, metric: str) -> float | None:
    mv = client.get_model_version(name, version)
    run = client.get_run(mv.run_id)
    return run.data.metrics.get(metric)


def production_version(client: MlflowClient, name: str) -> str | None:
    for v in client.search_model_versions(f"name='{name}'"):
        if v.current_stage == "Production":
            return v.version
    # Si no hay Production, intenta alias
    try:
        mv = client.get_model_version_by_alias(name, "production")
        return mv.version
    except Exception:
        return None


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True)
    p.add_argument("--metric", default="f1")
    p.add_argument("--min-improvement", type=float, default=0.01)
    p.add_argument("--candidate-version")
    args = p.parse_args()

    mlflow.set_tracking_uri(os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000"))
    client = MlflowClient()

    cand = args.candidate_version or latest_version(client, args.name)
    if cand is None:
        print("no hay versiones registradas", file=sys.stderr)
        return 2
    cand_metric = metric_for_version(client, args.name, cand, args.metric)
    print(f"candidate v{cand}: {args.metric}={cand_metric}")

    prod = production_version(client, args.name)
    if prod is None:
        print("no hay Production aún · promovemos candidato a Staging")
        client.transition_model_version_stage(args.name, cand, "Staging",
                                              archive_existing_versions=True)
        return 0

    prod_metric = metric_for_version(client, args.name, prod, args.metric)
    print(f"production v{prod}: {args.metric}={prod_metric}")

    if cand_metric is None or prod_metric is None:
        print("no se puede comparar (métricas faltan)", file=sys.stderr)
        return 3

    threshold = prod_metric * (1 + args.min_improvement)
    if cand_metric >= threshold:
        print(f"PROMOTE · {cand_metric:.4f} >= {threshold:.4f}")
        client.transition_model_version_stage(args.name, cand, "Staging",
                                              archive_existing_versions=False)
        return 0
    print(f"REJECT · {cand_metric:.4f} < {threshold:.4f}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
