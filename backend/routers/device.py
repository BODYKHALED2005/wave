from fastapi import APIRouter, Depends
from typing import Optional

from pydantic import BaseModel
from sqlalchemy.orm import Session
import datetime
from db.database import get_db, ScanEvent
from services.model_service import model_service
from services.alert_engine import process_scan_for_alerts
from routers.websocket import manager

router = APIRouter()


def _get_last_valid_vitals(db: Session, child_id: str):
    last_with_spo2 = (
        db.query(ScanEvent)
        .filter(ScanEvent.child_id == child_id, ScanEvent.spo2.isnot(None))
        .order_by(ScanEvent.captured_at.desc())
        .first()
    )
    last_with_bpm = (
        db.query(ScanEvent)
        .filter(ScanEvent.child_id == child_id, ScanEvent.bpm.isnot(None))
        .order_by(ScanEvent.captured_at.desc())
        .first()
    )
    return (
        last_with_spo2.spo2 if last_with_spo2 else None,
        last_with_bpm.bpm if last_with_bpm else None,
    )

class DeviceScan(BaseModel):
    device_id: str
    child_id: str
    captured_at: str
    spo2: Optional[int] = None
    bpm: Optional[int] = None
    temperature_c: float
    humidity: int
    battery: int
    audio_base64: str
    sample_rate: int = 16000
    duration_sec: float = 5.0
    aqi: int = 0

@router.post("/device-scan")
async def ingest_device_scan(scan_data: DeviceScan, db: Session = Depends(get_db)):
    scan_id = f"scan_{int(datetime.datetime.utcnow().timestamp())}"
    print(
        f"[device-scan] child={scan_data.child_id} sr={scan_data.sample_rate} "
        f"dur={scan_data.duration_sec}s b64_len={len(scan_data.audio_base64)}"
    )

    audio_sample_path = None
    try:
        audio_sample_path = model_service.save_audio_sample(
            scan_id=scan_id,
            child_id=scan_data.child_id,
            audio_base64=scan_data.audio_base64,
            sample_rate=scan_data.sample_rate,
        )
    except Exception as e:
        print(f"Audio sample save skipped: {e}")

    # 1. Run inference
    prediction = model_service.predict(
        scan_data.audio_base64,
        scan_data.sample_rate,
        scan_data.duration_sec,
    )
    
    # 2. Save scan event
    captured_time = datetime.datetime.fromisoformat(scan_data.captured_at.replace('Z', '+00:00')) if scan_data.captured_at else datetime.datetime.utcnow()
    
    fallback_spo2, fallback_bpm = _get_last_valid_vitals(db, scan_data.child_id)
    resolved_spo2 = scan_data.spo2 if scan_data.spo2 is not None else fallback_spo2
    resolved_bpm = scan_data.bpm if scan_data.bpm is not None else fallback_bpm

    scan_event = ScanEvent(
        id=scan_id,
        child_id=scan_data.child_id,
        device_id=scan_data.device_id,
        captured_at=captured_time,
        spo2=resolved_spo2,
        bpm=resolved_bpm,
        temperature_c=scan_data.temperature_c,
        battery=scan_data.battery,
        humidity=scan_data.humidity,
        aqi=scan_data.aqi,
        label=prediction["label"],
        confidence=prediction["confidence"],
        threshold=prediction.get("threshold") or 0.36,
    )
    
    db.add(scan_event)
    db.commit()
    db.refresh(scan_event)
    
    # 3. Process alerts
    alert = process_scan_for_alerts(db, scan_event)
    
    # 4. Broadcast via websocket
    ws_message = {
        "type": "scan_result",
        "child_id": scan_event.child_id,
        "device_id": scan_event.device_id,
        "captured_at": scan_event.captured_at.isoformat() + "Z",
        "status": scan_event.label,
        "confidence": scan_event.confidence,
        "threshold": scan_event.threshold if scan_event.threshold is not None else 0.36,
        "is_wheeze": scan_event.label == "wheeze",
        "spo2": scan_event.spo2,
        "bpm": scan_event.bpm,
        "temperature_c": scan_event.temperature_c,
        "battery": scan_event.battery,
        "humidity": scan_event.humidity,
        "aqi": scan_event.aqi,
        "waveform_preview": [], # we omit heavy waveform for now or generate dummy
        "audio_rms": prediction.get("rms"),
        "spo2_source": "live" if scan_data.spo2 is not None else "fallback",
        "bpm_source": "live" if scan_data.bpm is not None else "fallback",
    }
    
    await manager.broadcast_to_child(scan_event.child_id, ws_message)
    
    if alert:
        alert_msg = {
            "type": "alert",
            "id": alert.id,
            "child_id": alert.child_id,
            "title_en": alert.title_en,
            "title_ar": alert.title_ar,
            "body_en": alert.body_en,
            "body_ar": alert.body_ar,
            "severity": alert.severity,
            "occurred_at": alert.occurred_at.isoformat() + "Z",
            "requires_ack": alert.requires_ack,
            "acknowledged": alert.acknowledged,
            "spo2": scan_event.spo2,
            "bpm": scan_event.bpm,
            "temperature_c": scan_event.temperature_c,
            "battery": scan_event.battery,
            "humidity": scan_event.humidity,
            "aqi": scan_event.aqi,
            "backend_prediction": {
                "label": scan_event.label,
                "confidence": scan_event.confidence,
                "threshold": scan_event.threshold
            }
        }
        await manager.broadcast_to_child(scan_event.child_id, alert_msg)
    
    return {
        "status": "ok",
        "scan_id": scan_id,
        "audio_sample_path": audio_sample_path,
        "result": {
            "label": prediction["label"],
            "confidence": prediction["confidence"],
            "threshold": prediction.get("threshold") or 0.36,
            "is_wheeze": prediction["is_wheeze"],
            "audio_rms": prediction.get("rms"),
        }
    }
