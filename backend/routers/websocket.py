from typing import Dict
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, list[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, child_id: str):
        await websocket.accept()
        if child_id not in self.active_connections:
            self.active_connections[child_id] = []
        self.active_connections[child_id].append(websocket)

    def disconnect(self, websocket: WebSocket, child_id: str):
        if child_id in self.active_connections:
            self.active_connections[child_id].remove(websocket)

    async def broadcast_to_child(self, child_id: str, message: dict):
        if child_id in self.active_connections:
            for connection in self.active_connections[child_id]:
                try:
                    await connection.send_json(message)
                except Exception:
                    pass

manager = ConnectionManager()

@router.websocket("/children/{child_id}")
async def websocket_endpoint(websocket: WebSocket, child_id: str):
    await manager.connect(websocket, child_id)
    try:
        while True:
            data = await websocket.receive_text()
            # we can process auth message here if needed
    except WebSocketDisconnect:
        manager.disconnect(websocket, child_id)
