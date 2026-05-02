from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import children, device, websocket

app = FastAPI(title="WaveMed Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(children.router, prefix="/api/v1")
app.include_router(device.router, prefix="/api/v1")
app.include_router(websocket.router, prefix="/ws")

@app.get("/")
def health_check():
    return {"status": "ok", "service": "WaveMed API"}
