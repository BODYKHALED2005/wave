import datetime
from db.database import Alert, ScanEvent

ALERT_COOLDOWN_SECONDS = 180

def derive_severity_from_scan(scan: ScanEvent) -> str:
    """Use stored label (same threshold as model_service) so alerts match UI."""
    if scan.label != "wheeze":
        return "normal"
    if scan.spo2 is not None and scan.spo2 < 94:
        return "emergency"
    return "wheeze"


def process_scan_for_alerts(db, scan: ScanEvent):
    severity = derive_severity_from_scan(scan)
    
    if severity == "normal":
        return None

    last_alert = (
        db.query(Alert)
        .filter(Alert.child_id == scan.child_id)
        .order_by(Alert.occurred_at.desc())
        .first()
    )

    # Prevent flooding: skip same-severity alerts inside cooldown window.
    if last_alert and last_alert.severity == severity:
        delta = abs((scan.captured_at - last_alert.occurred_at).total_seconds())
        if delta < ALERT_COOLDOWN_SECONDS:
            return None

    # Only keep one active emergency until it is acknowledged.
    if severity == "emergency":
        open_emergency = (
            db.query(Alert)
            .filter(
                Alert.child_id == scan.child_id,
                Alert.severity == "emergency",
                Alert.requires_ack == True,
                Alert.acknowledged == False,
            )
            .order_by(Alert.occurred_at.desc())
            .first()
        )
        if open_emergency:
            return None
        
    alert = Alert(
        id=f"alert_{scan.id}",
        child_id=scan.child_id,
        severity=severity,
        occurred_at=scan.captured_at,
        scan_event_id=scan.id
    )
    
    if severity == "emergency":
        alert.title_en = "Emergency breathing pattern"
        alert.title_ar = "نمط تنفس طارئ"
        alert.body_en = "Persistent wheeze with falling SpO2 requires acknowledgement."
        alert.body_ar = "أزيز مستمر مع انخفاض الأكسجين ويتطلب تأكيداً."
        alert.requires_ack = True
    else:
        alert.title_en = "Wheeze detected"
        alert.title_ar = "تم اكتشاف أزيز"
        alert.body_en = "Backend confidence crossed the alert threshold."
        alert.body_ar = "تجاوزت ثقة الخادم حد التنبيه."
        alert.requires_ack = False
        
    db.add(alert)
    db.commit()
    db.refresh(alert)
    return alert
