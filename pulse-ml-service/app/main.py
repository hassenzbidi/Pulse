"""Point d'entree FastAPI du microservice ML de Pulse."""
import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings  # importe et charge le .env avant tout le reste
from app.auth import verify_api_key
from app.inference import load_model, predict_weeks_remaining, recommend
from app.schemas import PredictWeightRequest, PredictWeightResponse, RecommendResponse

logging.basicConfig(level=logging.INFO)


@asynccontextmanager
async def lifespan(app: FastAPI):
    load_model()
    yield


app = FastAPI(title="Pulse ML Service", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post(
    "/predict-weight",
    response_model=PredictWeightResponse,
    dependencies=[Depends(verify_api_key)],
)
async def predict_weight(payload: PredictWeightRequest):
    weeks_remaining, weekly_loss_kg, method = predict_weeks_remaining(
        payload.profile, payload.recent
    )
    return PredictWeightResponse(
        weeks_remaining=round(weeks_remaining, 2),
        weekly_loss_kg=round(weekly_loss_kg, 3),
        method=method,
    )


@app.post(
    "/recommend",
    response_model=RecommendResponse,
    dependencies=[Depends(verify_api_key)],
)
async def recommend_endpoint(payload: PredictWeightRequest):
    target_calories, recommendations = recommend(payload.profile, payload.recent)
    return RecommendResponse(
        target_calories=round(target_calories, 0),
        recommendations=recommendations,
    )
