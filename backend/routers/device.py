from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
import datetime
from db.database import get_db, ScanEvent
from services.model_service import model_service
from services.alert_engine import process_scan_for_alerts
from routers.websocket import manager

router = APIRouter()

class DeviceScan(BaseModel):
    device_id: str
    child_id: str
    captured_at: str
    spo2: int
    bpm: int
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
    prediction = model_service.predict(scan_data.audio_base64, scan_data.sample_rate)
    
    # 2. Save scan event
    captured_time = datetime.datetime.fromisoformat(scan_data.captured_at.replace('Z', '+00:00')) if scan_data.captured_at else datetime.datetime.utcnow()
    
    scan_event = ScanEvent(
        id=scan_id,
        child_id=scan_data.child_id,
        device_id=scan_data.device_id,
        captured_at=captured_time,
        spo2=scan_data.spo2,
        bpm=scan_data.bpm,
        temperature_c=scan_data.temperature_c,
        battery=scan_data.battery,
        humidity=scan_data.humidity,
        aqi=scan_data.aqi,
        label=prediction["label"],
        confidence=prediction["confidence"],
        threshold=0.30
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
        "threshold": scan_event.threshold,
        "is_wheeze": scan_event.label == "wheeze",
        "spo2": scan_event.spo2,
        "bpm": scan_event.bpm,
        "temperature_c": scan_event.temperature_c,
        "battery": scan_event.battery,
        "humidity": scan_event.humidity,
        "aqi": scan_event.aqi,
        "waveform_preview": [] # we omit heavy waveform for now or generate dummy
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
            "threshold": 0.30,
            "is_wheeze": prediction["is_wheeze"]
        }
    }
