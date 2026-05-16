"""Locust scenario para benchmark de /predict."""
import random
from locust import HttpUser, task, between

WORKCLASSES = ["Private", "Self-emp-not-inc", "Federal-gov", "Local-gov", "State-gov"]
EDU_LEVELS = list(range(8, 16))
OCCUPATIONS = ["Adm-clerical", "Exec-managerial", "Tech-support", "Sales",
               "Craft-repair", "Other-service", "Prof-specialty"]


def sample_payload() -> dict:
    return {
        "age": random.randint(20, 65),
        "workclass": random.choice(WORKCLASSES),
        "education_num": random.choice(EDU_LEVELS),
        "marital_status": random.choice(["Never-married", "Married-civ-spouse", "Divorced"]),
        "occupation": random.choice(OCCUPATIONS),
        "relationship": random.choice(["Husband", "Not-in-family", "Own-child", "Wife"]),
        "race": random.choice(["White", "Black", "Asian-Pac-Islander", "Other"]),
        "sex": random.choice(["Male", "Female"]),
        "capital_gain": random.choice([0, 0, 0, 2174, 5178]),
        "capital_loss": 0,
        "hours_per_week": random.choice([20, 35, 40, 45, 50, 60]),
        "native_country": "United-States",
    }


class PredictUser(HttpUser):
    wait_time = between(0.05, 0.2)

    @task(10)
    def predict(self):
        self.client.post("/predict", json=sample_payload())

    @task(1)
    def health(self):
        self.client.get("/health")
