"""
Mueve una versión del modelo a un stage del Registry (Staging|Production|Archived).
Compatible con el flujo clásico de Stages (deprecated en MLflow 3 pero útil
para didáctica). En 3.x se prefieren *Aliases*; lo mostramos al final.
"""
from __future__ import annotations

import argparse
import os

import mlflow
from mlflow.tracking import MlflowClient


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--name", required=True)
    p.add_argument("--version", required=True)
    p.add_argument("--stage", choices=["None", "Staging", "Production", "Archived"], default="Staging")
    p.add_argument("--archive-existing", action="store_true",
                   help="archivar versiones previas en ese stage")
    args = p.parse_args()

    mlflow.set_tracking_uri(os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000"))
    client = MlflowClient()

    client.transition_model_version_stage(
        name=args.name,
        version=args.version,
        stage=args.stage,
        archive_existing_versions=args.archive_existing,
    )
    # alias equivalente (MLflow 2.9+)
    alias = args.stage.lower()
    if alias != "none":
        try:
            client.set_registered_model_alias(args.name, alias, args.version)
            print(f"alias {alias}@{args.name} -> v{args.version}")
        except Exception as exc:  # noqa: BLE001
            print(f"warning: alias no aplicado ({exc})")

    print(f"OK · {args.name} v{args.version} -> {args.stage}")


if __name__ == "__main__":
    main()
