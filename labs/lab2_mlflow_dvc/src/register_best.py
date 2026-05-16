"""
Selecciona el mejor run de un experimento por una métrica y lo registra.
"""
from __future__ import annotations

import argparse
import os

import mlflow
from mlflow.tracking import MlflowClient


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--experiment", required=True)
    p.add_argument("--metric", default="f1")
    p.add_argument("--name", required=True, help="nombre en el Registry")
    args = p.parse_args()

    mlflow.set_tracking_uri(os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000"))
    client = MlflowClient()

    exp = client.get_experiment_by_name(args.experiment)
    assert exp, f"experiment {args.experiment} no existe"

    runs = client.search_runs(
        [exp.experiment_id],
        order_by=[f"metrics.{args.metric} DESC"],
        max_results=1,
    )
    assert runs, "no hay runs"
    best = runs[0]
    score = best.data.metrics[args.metric]

    print(f"best run: {best.info.run_id}  ({args.metric}={score:.4f})")

    model_uri = f"runs:/{best.info.run_id}/model"
    mv = mlflow.register_model(model_uri, args.name)
    print(f"registered: {args.name} v{mv.version}")


if __name__ == "__main__":
    main()
