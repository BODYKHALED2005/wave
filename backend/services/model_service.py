import os
import io
import base64
from pathlib import Path
import librosa
import numpy as np
from tensorflow.keras.models import load_model
from services.api_config import get_settings

SAMPLE_RATE = 16000
DURATION = 5.0
N_MELS = 128
HOP_LENGTH = 512
N_FFT = 2048

class ModelService:
    def __init__(self):
        settings = get_settings()
        self.model_path = settings.model_path
        self.model = None
        
        if os.path.exists(self.model_path):
            try:
                self.model = load_model(self.model_path)
                print(f"Loaded model from {self.model_path}")
            except Exception as e:
                print(f"Error loading model: {e}")
        else:
            print(f"Model not found at {self.model_path}, starting in Mock Mode.")

    def extract_mel_spectrogram(self, audio, sr=SAMPLE_RATE):
        target_length = int(DURATION * sr)

        if len(audio) < target_length:
            audio = np.pad(audio, (0, target_length - len(audio)), mode='constant')
        else:
            audio = audio[:target_length]

        mel_spec = librosa.feature.melspectrogram(
            y=audio, sr=sr,
            n_mels=N_MELS, n_fft=N_FFT, hop_length=HOP_LENGTH
        )

        mel_spec_db = librosa.power_to_db(mel_spec, ref=np.max)

        mel_min = mel_spec_db.min()
        mel_max = mel_spec_db.max()
        if mel_max - mel_min > 0:
            mel_spec_db = (mel_spec_db - mel_min) / (mel_max - mel_min)
        else:
            mel_spec_db = np.zeros_like(mel_spec_db)

        return mel_spec_db

    def predict(self, audio_base64: str, sample_rate: int = 16000):
        if self.model is None:
            # Mock mode
            return {"confidence": 0.5, "is_wheeze": True, "label": "wheeze"}
            
        try:
            # Firmware may send WAV bytes or raw PCM16 samples.
            audio, sr = self._decode_audio(audio_base64, sample_rate)
            
            # Resample if needed
            if sr != SAMPLE_RATE:
                audio = librosa.resample(audio, orig_sr=sr, target_sr=SAMPLE_RATE)
            
            mel_spec = self.extract_mel_spectrogram(audio, SAMPLE_RATE)
            # reshape for model: (1, 128, 157, 1)
            mel_spec = np.expand_dims(mel_spec, axis=-1)
            mel_spec = np.expand_dims(mel_spec, axis=0)
            
            prediction = self.model.predict(mel_spec)
            confidence = float(prediction[0][0])
            
            return {
                "confidence": confidence,
                "is_wheeze": confidence >= 0.30,
                "label": "wheeze" if confidence >= 0.30 else "normal"
            }
        except Exception as e:
            print(f"Error in prediction: {e}")
            return {"confidence": 0.0, "is_wheeze": False, "label": "normal"}

    def _decode_audio(self, audio_base64: str, sample_rate: int):
        audio_bytes = base64.b64decode(audio_base64)

        # Try WAV/encoded audio first.
        try:
            import soundfile as sf
            audio, sr = sf.read(io.BytesIO(audio_bytes))
            if isinstance(audio, np.ndarray) and audio.ndim > 1:
                audio = np.mean(audio, axis=1)
            return audio.astype(np.float32), int(sr)
        except Exception:
            # Fallback: ESP32 raw PCM16 little-endian.
            if len(audio_bytes) < 2:
                raise ValueError("Audio payload too small")
            pcm = np.frombuffer(audio_bytes, dtype="<i2")
            if pcm.size == 0:
                raise ValueError("Audio payload decode failed")
            audio = pcm.astype(np.float32) / 32768.0
            inferred_sr = int(sample_rate) if sample_rate else SAMPLE_RATE
            return audio, inferred_sr

    def save_audio_sample(self, scan_id: str, child_id: str, audio_base64: str, sample_rate: int = 16000):
        settings = get_settings()
        if not settings.save_audio_samples:
            return None

        audio, sr = self._decode_audio(audio_base64, sample_rate)
        out_dir = Path(settings.audio_samples_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        safe_child = "".join(ch if ch.isalnum() or ch in ("-", "_") else "_" for ch in child_id)
        output_path = out_dir / f"{scan_id}_{safe_child}_{sr}hz.wav"

        import soundfile as sf
        sf.write(str(output_path), audio, sr, subtype="PCM_16")
        return str(output_path)

model_service = ModelService()
