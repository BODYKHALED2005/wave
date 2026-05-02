import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    model_path: str = "../wave/wheeze_model.h5"
    db_url: str = "sqlite:///./wavemed.db"
    firebase_verify: bool = False
    save_audio_samples: bool = True
    audio_samples_dir: str = "./debug_audio_samples"

    class Config:
        env_file = ".env"

def get_settings() -> Settings:
    return Settings()
