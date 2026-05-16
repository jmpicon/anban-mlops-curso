"""
Entrena un clasificador, lo loggea en MLflow con metadatos completos.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import warnings
from pathlib import Path

# Silenciamos warnings cosméticos de MLflow que asustan al alumno
# (todos son avisos informativos, no errores):
#   - "Inferred schema contains integer column(s)" — solo aplica si los
#     datos de inference tienen NaN, no es nuestro caso.
#   - "n_jobs has no effect since 1.8" — el modelo logreg lo pasa por
#     compatibilidad pero sklearn lo deprecia.
warnings.filterwarnings("ignore", message=".*Inferred schema contains integer column.*")
warnings.filterwarnings("ignore", message=".*n_jobs.*has no effect.*")

import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

try:
    from xgboost import XGBClassifier
    HAVE_XGB = True
except ImportError:
    HAVE_XGB = False

DATA_DIR = Path("../lab1_dataops/data/processed")
EXPERIMENT = "heart-failure-classifier"


def git_commit() -> str:
    # Silenciamos stderr para no mostrar "fatal: not a git repository"
    # cuando el alumno ejecuta el lab sin haber hecho git init.
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return "unknown"


def build_model(name: str):
    if name == "logreg":
        return Pipeline([("sc", StandardScaler(with_mean=False)),
                         ("clf", LogisticRegression(max_iter=2000, n_jobs=-1))]), {
            "model": "logreg", "max_iter": 2000,
        }
    if name == "rf":
        m = RandomForestClassifier(n_estimators=300, max_depth=12, n_jobs=-1, random_state=42)
        return m, {"model": "random_forest", "n_estimators": 300, "max_depth": 12}
    if name == "xgb":
        if not HAVE_XGB:
            raise RuntimeError("xgboost no instalado")
        m = XGBClassifier(
            n_estimators=400, max_depth=6, learning_rate=0.1,
            n_jobs=-1, eval_metric="logloss", random_state=42,
        )
        return m, {"model": "xgboost", "n_estimators": 400, "max_depth": 6, "lr": 0.1}
    raise ValueError(name)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--model", choices=["logreg", "rf", "xgb"], required=True)
    p.add_argument("--data-dir", default=str(DATA_DIR))
    p.add_argument("--owner", default=os.environ.get("USER", "unknown"))
    args = p.parse_args()

    train = pd.read_parquet(Path(args.data_dir) / "train.parquet")
    test  = pd.read_parquet(Path(args.data_dir) / "test.parquet")
    TARGET = "DEATH_EVENT"
    X_tr, y_tr = train.drop(columns=TARGET), train[TARGET]
    X_te, y_te = test.drop(columns=TARGET),  test[TARGET]

    model, params = build_model(args.model)

    mlflow.set_tracking_uri(os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000"))
    mlflow.set_experiment(EXPERIMENT)

    with mlflow.start_run(run_name=args.model):
        mlflow.log_params(params)
        mlflow.set_tags({
            "git_commit": git_commit(),
            "dataset_version": "lab1-v1",
            "owner": args.owner,
            "framework": type(model).__name__,
        })

        model.fit(X_tr, y_tr)
        y_pred = model.predict(X_te)
        y_proba = model.predict_proba(X_te)[:, 1]

        metrics = {
            "accuracy":  accuracy_score(y_te, y_pred),
            "f1":        f1_score(y_te, y_pred),
            "precision": precision_score(y_te, y_pred),
            "recall":    recall_score(y_te, y_pred),
            "roc_auc":   roc_auc_score(y_te, y_proba),
        }
        mlflow.log_metrics(metrics)

        sig = mlflow.models.infer_signature(X_tr, y_pred)
        # Pasamos pip_requirements explícitas para no depender de que
        # MLflow detecte las versiones del entorno (que falla con conda).
        import sklearn
        pip_reqs = [
            f"scikit-learn=={sklearn.__version__}",
            f"pandas=={pd.__version__}",
            "numpy",
        ]
        if HAVE_XGB and args.model == "xgb":
            import xgboost as xgb
            pip_reqs.append(f"xgboost=={xgb.__version__}")
        mlflow.sklearn.log_model(
            sk_model=model,
            artifact_path="model",
            signature=sig,
            input_example=X_tr.head(3),
            pip_requirements=pip_reqs,
        )

        print(f"== {args.model:>8} ==  " +
              "  ".join(f"{k}={v:.4f}" for k, v in metrics.items()))


if __name__ == "__main__":
    main()
