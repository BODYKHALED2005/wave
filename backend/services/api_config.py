import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    model_path: str = "../wave/wheeze_model.h5"
    db_url: str = "sqlite:///./wavemed.db"
    firebase_verify: bool = False
    save_audio_samples: bool = True
    audio_samples_dir: str = "./debug_audio_samples"
    # Tuned threshold for ESP32 live captures after robust multi-window scoring.
    wheeze_alert_threshold: float = 0.31
    # Skip ML only when signal is near-silent.
    audio_min_rms: float = 0.0025

    class Config:
        env_file = ".env"

def get_settings() -> Settings:
    return Settings()
