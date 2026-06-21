"""Entraine le modele de prediction de perte de poids hebdomadaire pour Pulse."""
import os

import joblib
import numpy as np
import pandas as pd
import sklearn
import xgboost
from sklearn.model_selection import GroupKFold
from sklearn.metrics import mean_absolute_error
from xgboost import XGBRegressor

RANDOM_STATE = 42
N_PATIENTS = 2000
WISHNOFSKY_KCAL_PER_KG = 7700

ACTIVITY_FACTORS = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "very_active": 1.9,
}

FEATURES = [
    "age",
    "sex_M",
    "height",
    "weight",
    "target_weight",
    "bmr",
    "tdee",
    "activity_factor",
    "cal_in_mean_7d",
    "cal_in_std_7d",
    "real_deficit_mean",
    "protein_g_mean",
    "carbs_g_mean",
    "fat_g_mean",
    "adherence_rate",
    "discipline_score_mean",
    "weight_slope_14d",
]


def generate_dataset(n_patients, rng):
    sex = rng.choice(["M", "F"], size=n_patients)
    age = rng.integers(18, 66, size=n_patients).astype(float)

    height = np.where(
        sex == "M",
        rng.normal(175, 7, size=n_patients),
        rng.normal(162, 7, size=n_patients),
    )
    weight = np.where(
        sex == "M",
        rng.normal(85, 12, size=n_patients),
        rng.normal(72, 12, size=n_patients),
    )
    weight = np.clip(weight, 40, 180)
    height = np.clip(height, 140, 210)

    weight_loss_goal = rng.uniform(3, 20, size=n_patients)
    target_weight = weight - weight_loss_goal

    activity_level = rng.choice(
        list(ACTIVITY_FACTORS.keys()), size=n_patients
    )
    activity_factor = np.array([ACTIVITY_FACTORS[a] for a in activity_level])

    sex_M = (sex == "M").astype(int)
    bmr = np.where(
        sex == "M",
        10 * weight + 6.25 * height - 5 * age + 5,
        10 * weight + 6.25 * height - 5 * age - 161,
    )
    tdee = bmr * activity_factor

    adherence_rate = rng.uniform(0.4, 1.0, size=n_patients)

    planned_deficit = rng.uniform(200, 800, size=n_patients)
    real_deficit_mean = planned_deficit * adherence_rate

    cal_in_mean_7d = tdee - real_deficit_mean
    cal_in_std_7d = rng.uniform(50, 300, size=n_patients) * (1.5 - adherence_rate)

    protein_g_mean = rng.uniform(0.8, 2.2, size=n_patients) * weight
    fat_g_ratio = rng.uniform(0.2, 0.35, size=n_patients)
    fat_g_mean = (cal_in_mean_7d * fat_g_ratio) / 9
    protein_kcal = protein_g_mean * 4
    fat_kcal = fat_g_mean * 9
    carbs_kcal = np.clip(cal_in_mean_7d - protein_kcal - fat_kcal, 0, None)
    carbs_g_mean = carbs_kcal / 4

    discipline_score_mean = np.clip(
        adherence_rate * 100 + rng.normal(0, 5, size=n_patients), 0, 100
    )

    weekly_loss_kg = real_deficit_mean * 7 / WISHNOFSKY_KCAL_PER_KG
    noise = rng.normal(0, 0.15, size=n_patients)
    weekly_loss_kg = weekly_loss_kg + noise

    weight_slope_14d = -(weekly_loss_kg / 7) * 14 + rng.normal(
        0, 0.1, size=n_patients
    )

    df = pd.DataFrame(
        {
            "patient_id": np.arange(n_patients),
            "age": age,
            "sex_M": sex_M,
            "height": height,
            "weight": weight,
            "target_weight": target_weight,
            "bmr": bmr,
            "tdee": tdee,
            "activity_factor": activity_factor,
            "cal_in_mean_7d": cal_in_mean_7d,
            "cal_in_std_7d": cal_in_std_7d,
            "real_deficit_mean": real_deficit_mean,
            "protein_g_mean": protein_g_mean,
            "carbs_g_mean": carbs_g_mean,
            "fat_g_mean": fat_g_mean,
            "adherence_rate": adherence_rate,
            "discipline_score_mean": discipline_score_mean,
            "weight_slope_14d": weight_slope_14d,
            "weekly_loss_kg": weekly_loss_kg,
        }
    )
    return df


def main():
    rng = np.random.default_rng(RANDOM_STATE)
    df = generate_dataset(N_PATIENTS, rng)

    X = df[FEATURES]
    y = df["weekly_loss_kg"]
    groups = df["patient_id"]

    gkf = GroupKFold(n_splits=5)
    fold_maes = []

    for fold, (train_idx, val_idx) in enumerate(gkf.split(X, y, groups), start=1):
        X_train, X_val = X.iloc[train_idx], X.iloc[val_idx]
        y_train, y_val = y.iloc[train_idx], y.iloc[val_idx]

        model = XGBRegressor(
            n_estimators=400,
            max_depth=4,
            learning_rate=0.05,
            subsample=0.8,
            colsample_bytree=0.8,
            reg_lambda=1.0,
            reg_alpha=0.1,
            random_state=RANDOM_STATE,
        )
        model.fit(X_train, y_train)
        preds = model.predict(X_val)
        mae = mean_absolute_error(y_val, preds)
        fold_maes.append(mae)
        print(f"Fold {fold}: MAE = {mae:.4f} kg/semaine")

    fold_maes = np.array(fold_maes)
    print(
        f"\nMAE moyen (GroupKFold 5 splits) : "
        f"{fold_maes.mean():.4f} +/- {fold_maes.std():.4f} kg/semaine"
    )

    final_model = XGBRegressor(
        n_estimators=400,
        max_depth=4,
        learning_rate=0.05,
        subsample=0.8,
        colsample_bytree=0.8,
        reg_lambda=1.0,
        reg_alpha=0.1,
        random_state=RANDOM_STATE,
    )
    final_model.fit(X, y)

    models_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
    os.makedirs(models_dir, exist_ok=True)
    model_path = os.path.join(models_dir, "weight_model.joblib")
    joblib.dump({"model": final_model, "features": FEATURES}, model_path)
    print(f"\nModele sauvegarde dans : {model_path}")

    print(f"\nxgboost version       : {xgboost.__version__}")
    print(f"scikit-learn version   : {sklearn.__version__}")

    requirements_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "requirements.txt"
    )
    with open(requirements_path, "w") as f:
        f.write(f"xgboost=={xgboost.__version__}\n")
        f.write(f"scikit-learn=={sklearn.__version__}\n")
        f.write(f"pandas=={pd.__version__}\n")
        f.write(f"numpy=={np.__version__}\n")
        f.write(f"joblib=={joblib.__version__}\n")
    print(f"requirements.txt genere dans : {requirements_path}")


if __name__ == "__main__":
    main()
