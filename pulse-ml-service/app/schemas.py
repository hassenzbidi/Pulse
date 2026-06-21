"""Modeles Pydantic pour le microservice ML de Pulse."""
from typing import List, Literal

from pydantic import BaseModel, Field

Sex = Literal["M", "F"]
Activity = Literal["sedentary", "light", "moderate", "active", "very_active"]


class Profile(BaseModel):
    age: int = Field(..., ge=10, le=100)
    sex: Sex
    height: float = Field(..., gt=0, description="Taille en cm")
    weight: float = Field(..., gt=0, description="Poids actuel en kg")
    target_weight: float = Field(..., gt=0, description="Poids cible en kg")
    activity: Activity
    calorie_deficit: float = Field(..., description="Deficit calorique quotidien vise (kcal)")


class RecentStats(BaseModel):
    cal_in_mean_7d: float = Field(..., description="Apport calorique moyen sur 7 jours")
    protein_g_mean: float = Field(..., ge=0)
    carbs_g_mean: float = Field(..., ge=0)
    fat_g_mean: float = Field(..., ge=0)
    adherence_rate: float = Field(..., ge=0, le=1)
    discipline_score_mean: float = Field(..., ge=0, le=100)
    weight_slope_14d: float = Field(..., description="Pente du poids sur 14 jours (kg/jour)")
    n_days_logged: int = Field(..., ge=0)


class PredictWeightRequest(BaseModel):
    profile: Profile
    recent: RecentStats


class PredictWeightResponse(BaseModel):
    weeks_remaining: float
    weekly_loss_kg: float
    method: Literal["rule_based", "xgboost"]


class RecommendResponse(BaseModel):
    target_calories: float
    recommendations: List[str]
