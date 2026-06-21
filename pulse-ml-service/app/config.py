"""Configuration du microservice ML, basee sur des variables d'environnement."""
from dotenv import load_dotenv

load_dotenv()

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


class Settings:
    def __init__(self):
        self.api_key = os.environ.get("PULSE_ML_API_KEY", "")
        self.database_url = os.environ.get("DATABASE_URL", "")
        self.model_path = os.environ.get(
            "PULSE_ML_MODEL_PATH", str(BASE_DIR / "models" / "weight_model.joblib")
        )
        self.cors_origins = [
            origin.strip()
            for origin in os.environ.get("PULSE_ML_CORS_ORIGINS", "*").split(",")
            if origin.strip()
        ]


settings = Settings()
