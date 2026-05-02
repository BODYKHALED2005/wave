import datetime
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, create_engine
from sqlalchemy.orm import declarative_base, relationship, sessionmaker
from services.api_config import get_settings

Base = declarative_base()

class Child(Base):
    __tablename__ = "children"
    id = Column(String, primary_key=True, index=True)
    name = Column(String)
    age_label = Column(String)
    device_id = Column(String)
    has_assigned_device = Column(Boolean, default=False)

class ScanEvent(Base):
    __tablename__ = "scan_events"
    id = Column(String, primary_key=True, index=True)
    child_id = Column(String, ForeignKey("children.id"), index=True)
    device_id = Column(String)
    captured_at = Column(DateTime, default=datetime.datetime.utcnow)
    spo2 = Column(Integer)
    bpm = Column(Integer)
    temperature_c = Column(Float)
    battery = Column(Integer)
    humidity = Column(Integer)
    aqi = Column(Integer)
    
    # Model predictions
    label = Column(String) # normal, wheeze
    confidence = Column(Float)
    threshold = Column(Float)
    
class Alert(Base):
    __tablename__ = "alerts"
    id = Column(String, primary_key=True, index=True)
    child_id = Column(String, ForeignKey("children.id"), index=True)
    title_en = Column(String)
    title_ar = Column(String)
    body_en = Column(String)
    body_ar = Column(String)
    severity = Column(String) # normal, wheeze, emergency
    occurred_at = Column(DateTime, default=datetime.datetime.utcnow)
    requires_ack = Column(Boolean, default=False)
    acknowledged = Column(Boolean, default=False)
    
    scan_event_id = Column(String, ForeignKey("scan_events.id"))

settings = get_settings()
engine = create_engine(settings.db_url, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db():
    Base.metadata.create_all(bind=engine)
