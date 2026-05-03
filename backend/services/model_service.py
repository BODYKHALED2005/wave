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
        self._wheeze_threshold = settings.wheeze_alert_threshold
        self._audio_min_rms = settings.audio_min_rms
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
            # Repeat short captures (e.g. 2s fallback) instead of zero-padding.
            if len(audio) == 0:
                audio = np.zeros(target_length, dtype=np.float32)
            else:
                repeats = int(np.ceil(target_length / len(audio)))
                audio = np.tile(audio, repeats)[:target_length]
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

    def _preprocess_audio(self, audio: np.ndarray) -> np.ndarray:
        # Remove DC offset and avoid clipping.
        audio = audio - float(np.mean(audio))
        peak = float(np.max(np.abs(audio))) if audio.size else 0.0
        if peak > 1e-8:
            audio = np.clip(audio / peak * 0.95, -1.0, 1.0)
        return audio.astype(np.float32)

    def _predict_confidence(self, audio: np.ndarray) -> float:
        mel_spec = self.extract_mel_spectrogram(audio, SAMPLE_RATE)
        mel_spec = np.expand_dims(mel_spec, axis=-1)
        mel_spec = np.expand_dims(mel_spec, axis=0)
        prediction = self.model.predict(mel_spec, verbose=0)
        return float(prediction[0][0])

    def _robust_score(self, confidences: list[float]) -> float:
        """Combine peak and consistency to better catch short wheeze events."""
        if not confidences:
            return 0.0
        vals = sorted(confidences, reverse=True)
        max_c = vals[0]
        top2_mean = float(np.mean(vals[:2])) if len(vals) >= 2 else max_c
        mean_c = float(np.mean(vals))
        # Weighted score: prioritize peaks but keep consistency signal.
        return (0.55 * max_c) + (0.30 * top2_mean) + (0.15 * mean_c)

    def predict(self, audio_base64: str, sample_rate: int = 16000, duration_sec: float = 5.0):
        thr = self._wheeze_threshold

        if self.model is None:
            # Conservative mock: avoid false positives when weights are missing.
            return {
                "confidence": 0.0,
                "is_wheeze": False,
                "label": "normal",
                "threshold": thr,
            }

        try:
            # Firmware may send WAV bytes or raw PCM16 samples.
            audio, sr = self._decode_audio(audio_base64, sample_rate)
            
            # Resample if needed
            if sr != SAMPLE_RATE:
                audio = librosa.resample(audio, orig_sr=sr, target_sr=SAMPLE_RATE)

            # Gate silence/noise before normalization.
            rms = float(np.sqrt(np.mean(np.square(audio))))
            if rms < self._audio_min_rms:
                return {
                    "confidence": 0.0,
                    "is_wheeze": False,
                    "label": "normal",
                    "threshold": thr,
                }

            # ESP32 PCM can vary heavily in amplitude; normalize per scan.
            audio = self._preprocess_audio(audio)
            
            target_len = int(DURATION * SAMPLE_RATE)
            confidences = [self._predict_confidence(audio)]

            # Improve wheeze sensitivity: evaluate multiple windows and keep max score.
            # Wheeze can appear in only part of the captured segment.
            if len(audio) > target_len:
                mid = len(audio) // 2
                half = target_len // 2
                start_mid = max(0, min(len(audio) - target_len, mid - half))
                window_mid = audio[start_mid : start_mid + target_len]
                window_end = audio[-target_len:]
                confidences.append(self._predict_confidence(window_mid))
                confidences.append(self._predict_confidence(window_end))

            max_confidence = max(confidences)
            confidence = self._robust_score(confidences)

            return {
                "confidence": confidence,
                "is_wheeze": confidence >= thr,
                "label": "wheeze" if confidence >= thr else "normal",
                "threshold": thr,
                "rms": rms,
                "duration_sec": duration_sec,
                "window_confidences": confidences,
                "peak_confidence": max_confidence,
            }
        except Exception as e:
            print(f"Error in prediction: {e}")
            return {
                "confidence": 0.0,
                "is_wheeze": False,
                "label": "normal",
                "threshold": thr,
            }

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
