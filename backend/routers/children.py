from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db.database import get_db, Child, ScanEvent, Alert

router = APIRouter()

@router.get("/children")
def get_children(db: Session = Depends(get_db)):
    children = db.query(Child).all()
    return children

@router.get("/children/{child_id}/latest")
def get_latest_scan(child_id: str, db: Session = Depends(get_db)):
    scan = db.query(ScanEvent).filter(ScanEvent.child_id == child_id).order_by(ScanEvent.captured_at.desc()).first()
    if not scan:
        return {"child_id": child_id, "captured_at": None, "spo2": 0, "bpm": 0, "temperature_c": 0, "battery": 0, "humidity": 0, "aqi": 0, "backend_prediction": {"label": "normal", "confidence": 0, "threshold": 0.3}}
        
    return {
        "child_id": child_id,
        "device_id": scan.device_id,
        "captured_at": scan.captured_at.isoformat() + "Z",
        "spo2": scan.spo2,
        "bpm": scan.bpm,
        "temperature_c": scan.temperature_c,
        "battery": scan.battery,
        "humidity": scan.humidity,
        "aqi": scan.aqi,
        "backend_prediction": {
            "label": scan.label,
            "confidence": scan.confidence,
            "threshold": scan.threshold,
            "captured_at": scan.captured_at.isoformat() + "Z"
        },
        "waveform_preview": [],
        "next_scan_seconds": 30
    }

@router.get("/children/{child_id}/alerts")
def get_alerts(child_id: str, page: int = 1, limit: int = 20, db: Session = Depends(get_db)):
    alerts = db.query(Alert).filter(Alert.child_id == child_id).order_by(Alert.occurred_at.desc()).limit(limit).offset((page - 1) * limit).all()
    result = []
    for alert in alerts:
        scan = db.query(ScanEvent).filter(ScanEvent.id == alert.scan_event_id).first()
        result.append({
            "id": alert.id,
            "title_en": alert.title_en,
            "title_ar": alert.title_ar,
            "body_en": alert.body_en,
            "body_ar": alert.body_ar,
            "severity": alert.severity,
            "occurred_at": alert.occurred_at.isoformat() + "Z",
            "requires_ack": alert.requires_ack,
            "acknowledged": alert.acknowledged,
            "spo2": scan.spo2 if scan else 0,
            "bpm": scan.bpm if scan else 0,
            "temperature_c": scan.temperature_c if scan else 0,
            "battery": scan.battery if scan else 0,
            "humidity": scan.humidity if scan else 0,
            "aqi": scan.aqi if scan else 0,
            "backend_prediction": {
                "label": scan.label if scan else "normal",
                "confidence": scan.confidence if scan else 0,
                "threshold": scan.threshold if scan else 0.3
            }
        })
    return result

@router.get("/children/{child_id}/alerts/{alert_id}")
def get_alert_detail(child_id: str, alert_id: str, db: Session = Depends(get_db)):
    alert = db.query(Alert).filter(Alert.id == alert_id, Alert.child_id == child_id).first()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert not found")
        
    scan = db.query(ScanEvent).filter(ScanEvent.id == alert.scan_event_id).first()
    return {
        "id": alert.id,
        "title_en": alert.title_en,
        "title_ar": alert.title_ar,
        "body_en": alert.body_en,
        "body_ar": alert.body_ar,
        "severity": alert.severity,
        "occurred_at": alert.occurred_at.isoformat() + "Z",
        "requires_ack": alert.requires_ack,
        "acknowledged": alert.acknowledged,
        "spo2": scan.spo2 if scan else 0,
        "bpm": scan.bpm if scan else 0,
        "temperature_c": scan.temperature_c if scan else 0,
        "battery": scan.battery if scan else 0,
        "humidity": scan.humidity if scan else 0,
        "aqi": scan.aqi if scan else 0,
        "backend_prediction": {
            "label": scan.label if scan else "normal",
            "confidence": scan.confidence if scan else 0,
            "threshold": scan.threshold if scan else 0.3
        }
    }
