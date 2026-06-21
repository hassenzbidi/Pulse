"""Chargement du modele et logique de prediction / recommandation."""
import logging
import os
from typing import List, Tuple

import joblib
import numpy as np

from app.config import settings
from app.schemas import Profile, RecentStats

logger = logging.getLogger(__name__)

ACTIVITY = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "very_active": 1.9,
}

WISHNOFSKY_KCAL_PER_KG = 7700
MIN_WEEKLY_LOSS_KG = 0.1
MAX_WEEKLY_LOSS_KG = 1.2
MIN_DAYS_FOR_MODEL = 14
MIN_TARGET_CALORIES = 1200.0

_model_bundle = None


def load_model():
    """Charge le modele depuis settings.model_path. Appele au demarrage de l'app."""
    global _model_bundle
    if not os.path.exists(settings.model_path):
        logger.warning(
            "Modele introuvable a %s, le service utilisera uniquement les regles de secours.",
            settings.model_path,
        )
        _model_bundle = None
        return None
    _model_bundle = joblib.load(settings.model_path)
    logger.info("Modele charge depuis %s", settings.model_path)
    return _model_bundle


def get_model_bundle():
    return _model_bundle


def bmr_mifflin(age: float, sex: str, height: float, weight: float) -> float:
    base = 10 * weight + 6.25 * height - 5 * age
    return base + 5 if sex == "M" else base - 161


def _build_features(profile: Profile, recent: RecentStats, features: List[str]) -> np.ndarray:
    activity_factor = ACTIVITY[profile.activity]
    bmr = bmr_mifflin(profile.age, profile.sex, profile.height, profile.weight)
    tdee = bmr * activity_factor
    real_deficit_mean = tdee - recent.cal_in_mean_7d
    # cal_in_std_7d n'est pas fourni par l'app mobile : on l'estime a partir de
    # l'adherence (faible adherence => apports plus irreguliers => std plus haute).
    cal_in_std_7d = max(50.0, 300.0 * (1 - recent.adherence_rate))

    values = {
        "age": profile.age,
        "sex_M": 1 if profile.sex == "M" else 0,
        "height": profile.height,
        "weight": profile.weight,
        "target_weight": profile.target_weight,
        "bmr": bmr,
        "tdee": tdee,
        "activity_factor": activity_factor,
        "cal_in_mean_7d": recent.cal_in_mean_7d,
        "cal_in_std_7d": cal_in_std_7d,
        "real_deficit_mean": real_deficit_mean,
        "protein_g_mean": recent.protein_g_mean,
        "carbs_g_mean": recent.carbs_g_mean,
        "fat_g_mean": recent.fat_g_mean,
        "adherence_rate": recent.adherence_rate,
        "discipline_score_mean": recent.discipline_score_mean,
        "weight_slope_14d": recent.weight_slope_14d,
    }
    return np.array([[values[f] for f in features]])


def _rule_based_weekly_loss(profile: Profile, recent: RecentStats) -> float:
    real_deficit = profile.calorie_deficit * recent.adherence_rate
    weekly_loss = real_deficit * 7 / WISHNOFSKY_KCAL_PER_KG
    return float(np.clip(weekly_loss, MIN_WEEKLY_LOSS_KG, MAX_WEEKLY_LOSS_KG))


def predict_weeks_remaining(profile: Profile, recent: RecentStats) -> Tuple[float, float, str]:
    weight_to_lose = profile.weight - profile.target_weight

    if recent.n_days_logged < MIN_DAYS_FOR_MODEL or _model_bundle is None:
        weekly_loss_kg = _rule_based_weekly_loss(profile, recent)
        method = "rule_based"
    else:
        model = _model_bundle["model"]
        features = _model_bundle["features"]
        X = _build_features(profile, recent, features)
        raw_pred = float(model.predict(X)[0])
        weekly_loss_kg = float(np.clip(raw_pred, MIN_WEEKLY_LOSS_KG, MAX_WEEKLY_LOSS_KG))
        method = "xgboost"

    weeks_remaining = 0.0 if weight_to_lose <= 0 else weight_to_lose / weekly_loss_kg
    return weeks_remaining, weekly_loss_kg, method


def recommend(profile: Profile, recent: RecentStats) -> Tuple[float, List[str]]:
    activity_factor = ACTIVITY[profile.activity]
    bmr = bmr_mifflin(profile.age, profile.sex, profile.height, profile.weight)
    tdee = bmr * activity_factor
    target_calories = max(MIN_TARGET_CALORIES, tdee - profile.calorie_deficit)

    recommendations: List[str] = []

    diff = recent.cal_in_mean_7d - target_calories
    if diff > 150:
        recommendations.append(
            f"Apport calorique moyen ({recent.cal_in_mean_7d:.0f} kcal) superieur a "
            f"l'objectif ({target_calories:.0f} kcal). Reduire l'apport d'environ {diff:.0f} kcal/jour."
        )
    elif diff < -300:
        recommendations.append(
            f"Apport calorique moyen ({recent.cal_in_mean_7d:.0f} kcal) trop bas par rapport a "
            f"l'objectif ({target_calories:.0f} kcal). Risque de fonte musculaire ou d'effet rebond."
        )
    else:
        recommendations.append("Apport calorique conforme a l'objectif, continuer ainsi.")

    min_protein_g = 1.2 * profile.weight
    if recent.protein_g_mean < min_protein_g:
        recommendations.append(
            f"Apport en proteines insuffisant ({recent.protein_g_mean:.0f} g vs "
            f"{min_protein_g:.0f} g minimum recommande). Augmenter les sources de proteines."
        )

    if recent.adherence_rate < 0.6:
        recommendations.append(
            f"Adherence faible ({recent.adherence_rate * 100:.0f} %). "
            "Simplifier le plan ou revoir les objectifs pour ameliorer la regularite."
        )
    elif recent.adherence_rate >= 0.85:
        recommendations.append("Excellente adherence, maintenir les habitudes actuelles.")

    return target_calories, recommendations
