# WaveMed Live Integration Plan

## Goal

Make the current Flutter app work with the real ESP32 device and the trained wheeze model so the app can:

- show live child vitals
- show live device state
- show a live waveform preview
- show wheeze detection as `true` / `false`
- raise alerts when wheeze is detected
- escalate to emergency when wheeze + low SpO2 are both present

This plan is based on:

- the current Flutter project in this repo
- the ESP32 Arduino code you provided
- the model contract inside [train-model.ipynb](/Users/tank/StudioProjects/WaveMed/train-model.ipynb)

## Current Reality

### Flutter app

The app is still a UI shell with mocked state in [lib/features/app_state/app_state.dart](/Users/tank/StudioProjects/WaveMed/lib/features/app_state/app_state.dart). It does not yet consume real device data.

### ESP32 firmware

Your Arduino code currently does three things locally:

- reads temperature from `MLX90614`
- reads pulse / SpO2 from `MAX30102`
- reads audio from `INMP441`

It also already calls:

```cpp
run_classifier(&signal, &result, false);
```

through:

```cpp
#include <hamedatef-project-1_inferencing.h>
```

### Model notebook

The notebook defines a different inference path:

- sample rate: `16000`
- duration: `5.0` seconds
- mel bands: `128`
- FFT: `2048`
- hop length: `512`
- input shape: `(128, 157, 1)`
- classes: `normal`, `wheeze`
- recommended threshold: `0.30`
- exported files:
  - `wheeze_model.h5`
  - `wheeze_model.tflite`
  - `model_config.json`

## Critical Decision

You must choose one inference source of truth.

Right now there are two:

1. Edge Impulse style on-device inference via `hamedatef-project-1_inferencing.h`
2. notebook-trained TensorFlow/TFLite inference via `train-model.ipynb`

If both remain active, you will get inconsistent results.

## Recommended Architecture

For MVP, use this architecture:

1. BLE is only for setup
2. Wi-Fi is used for real device data
3. backend runs the notebook-trained model
4. Flutter app receives live status through WebSocket
5. TFLite in the app is added later as offline fallback

That gives you:

- one model source of truth
- simpler debugging
- easier re-training and threshold changes
- less risk on the ESP32

## Final Data Flow

```text
ESP32 device
  -> collects 5s audio + Spo2 + BPM + temp
  -> sends packet to backend over Wi-Fi

Backend
  -> converts audio to mel spectrogram
  -> runs notebook model
  -> applies threshold 0.30
  -> stores event
  -> pushes live result over WebSocket
  -> optionally sends Firebase push alert

Flutter app
  -> subscribes to child live stream
  -> updates home screen + monitor screen
  -> shows normal / wheeze / emergency state
```

## What Should Run Where

### On ESP32

Keep:

- sensor reads
- short audio capture
- Wi-Fi connection
- packet upload

Do not use ESP32 as the primary model runtime for MVP unless you convert and validate the same notebook model on-device.

For MVP, remove or disable:

```cpp
run_classifier(...)
```

or treat it only as a debug comparison, not the production result.

### On Backend

Run the real wheeze model from the notebook:

- load `wheeze_model.h5` or `wheeze_model.tflite`
- recreate the same preprocessing:
  - `16000 Hz`
  - `5.0s`
  - `128` mel bins
  - `2048` FFT
  - `512` hop length
  - normalize mel to `[0, 1]`
- output:
  - `confidence`
  - `is_wheeze = confidence >= 0.30`

### In Flutter

Do not send raw audio into the UI layer.

The app should receive:

- vitals
- current classification
- confidence
- optional waveform preview points
- alert state

## Required Backend Contracts

## 1. Device ingest API

`POST /api/v1/device-scan`

Request:

```json
{
  "device_id": "WM-2048",
  "child_id": "child_123",
  "captured_at": "2026-04-28T14:15:22Z",
  "spo2": 96,
  "bpm": 108,
  "temperature_c": 37.1,
  "humidity": 38,
  "battery": 82,
  "audio_base64": "....",
  "sample_rate": 16000,
  "duration_sec": 5.0
}
```

Response:

```json
{
  "status": "ok",
  "scan_id": "scan_987",
  "result": {
    "label": "wheeze",
    "confidence": 0.76,
    "threshold": 0.30,
    "is_wheeze": true
  }
}
```

## 2. Live app stream

`GET /ws/children/{child_id}`

Message:

```json
{
  "type": "scan_result",
  "child_id": "child_123",
  "device_id": "WM-2048",
  "captured_at": "2026-04-28T14:15:22Z",
  "status": "wheeze",
  "confidence": 0.76,
  "is_wheeze": true,
  "spo2": 96,
  "bpm": 108,
  "temperature_c": 37.1,
  "battery": 82,
  "humidity": 38,
  "aqi": 41,
  "waveform_preview": [0.11, 0.05, -0.02, 0.13, -0.09]
}
```

## 3. Alert event payload

```json
{
  "type": "alert",
  "severity": "emergency",
  "title": "Wheeze with low SpO2",
  "body": "SpO2 dropped to 91% and wheeze was detected",
  "spo2": 91,
  "confidence": 0.84,
  "requires_ack": true
}
```

## Emergency Rule

Use this exact rule in the backend:

- `normal` when `confidence < 0.30`
- `wheeze` when `confidence >= 0.30`
- `emergency` when `confidence >= 0.30` and `spo2 < 94`

This matches your notebook threshold and your product behavior.

## Firmware Plan

## Phase F1: stabilize packet creation

Update the ESP32 code so it:

- captures exactly `5s` of audio at `16000 Hz`
- converts raw I2S samples to 16-bit PCM
- sends one scan packet every cycle
- includes `spo2`, `bpm`, `temperature`, `battery`, `device_id`

Recommended additions:

- unique `device_id`
- Wi-Fi reconnect logic
- HTTP retry with timeout
- rolling average for pulse values

## Phase F2: remove model conflict

Choose one:

- disable `run_classifier(...)` entirely
- or keep it under `#define LOCAL_DEBUG_INFERENCE`

Production result should come from backend inference only in MVP.

## Phase F3: add waveform preview

Do not send full audio to the app for the live chart.

Instead:

- backend or firmware computes a small preview array of 64 to 128 points
- app draws that in the waveform widget

That is enough for live UI without moving heavy audio through the app.

## Backend Plan

## Phase B1: FastAPI service

Create a backend with:

- `POST /api/v1/device-scan`
- `GET /ws/children/{child_id}`
- health endpoint
- model service
- database storage

Recommended stack:

- FastAPI
- Uvicorn
- SQLAlchemy
- PostgreSQL
- Pydantic
- `librosa`, `numpy`, `tensorflow`

## Phase B2: model service

Implement:

- `load_model()`
- `preprocess_audio_to_mel(audio_bytes) -> [1, 128, 157, 1]`
- `predict(confidence)`
- threshold application

This service must exactly match the notebook preprocessing.

## Phase B3: alert engine

Implement:

- normal / wheeze / emergency rule
- event history storage
- WebSocket broadcast to subscribers
- FCM push later

## Flutter Plan

## Phase A1: replace mock state with repositories

The app currently hardcodes child state and alerts in [lib/features/app_state/app_state.dart](/Users/tank/StudioProjects/WaveMed/lib/features/app_state/app_state.dart).

Replace that with:

- `DeviceStatus` model
- `AlertEvent` model
- `HomeRepository`
- `LiveMonitorRepository`
- `WebSocketService`

## Phase A2: live stream provider

Add a Riverpod stream provider:

```dart
final liveStatusProvider = StreamProvider<DeviceStatus>((ref) {
  final childId = ref.watch(activeChildIdProvider);
  return ref.read(webSocketServiceProvider).watchChild(childId);
});
```

Then wire:

- [lib/features/home/presentation/home_screen.dart](/Users/tank/StudioProjects/WaveMed/lib/features/home/presentation/home_screen.dart)
- [lib/features/monitor/presentation/live_monitor_screen.dart](/Users/tank/StudioProjects/WaveMed/lib/features/monitor/presentation/live_monitor_screen.dart)

to render real stream data instead of mock values.

## Phase A3: waveform preview

Feed `waveform_preview` into [lib/features/monitor/presentation/widgets/waveform_painter.dart](/Users/tank/StudioProjects/WaveMed/lib/features/monitor/presentation/widgets/waveform_painter.dart).

The app should not calculate ML features from live audio for MVP.

## Phase A4: alert history and emergency state

Wire:

- live alert banner
- alert history list
- emergency screen route

from backend events instead of hardcoded alerts.

## TFLite Plan

TFLite should be Phase 2, not Phase 1.

Use it only after backend inference works.

Reason:

- you already have one trained `.tflite`
- but the app still needs audio preprocessing identical to the notebook
- on-device inference is useless if the spectrogram generation is wrong

Later, add:

- `tflite_flutter`
- model asset `assets/ml/wheeze_model.tflite`
- config asset from `model_config.json`
- exact mel preprocessing in Dart or native code

Use TFLite only as:

- offline fallback when backend is unavailable
- optional validation mode against backend predictions

## Exact MVP Order

## Step 1

Backend first.

Deliverables:

- FastAPI app
- ingest endpoint
- WebSocket endpoint
- model inference service using notebook export

## Step 2

ESP32 upload integration.

Deliverables:

- Wi-Fi provisioning path
- device HTTP POST
- test packet reaches backend

## Step 3

Flutter live stream integration.

Deliverables:

- real WebSocket service
- live home screen values
- live monitor values
- waveform preview

## Step 4

Alerting.

Deliverables:

- wheeze alert
- emergency alert when `SpO2 < 94`
- alert history screen

## Step 5

Offline mode.

Deliverables:

- local TFLite fallback
- sync when online returns

## What I Would Build Next In This Repo

1. create real Dart models for live device status and scan events
2. add a `WebSocketService`
3. replace mock child data with Riverpod stream-backed state
4. add a small local mock WebSocket adapter so UI can be tested before backend is ready
5. after that, wire the real backend URL

## Acceptance Criteria

The system is working when all of these are true:

- ESP32 sends one scan every cycle to backend
- backend classifies the audio using the notebook model
- backend sends the result over WebSocket within a few seconds
- Flutter home screen updates live without restart
- monitor screen shows changing waveform preview
- app shows `Normal` when `confidence < 0.30`
- app shows `Wheeze` when `confidence >= 0.30`
- app shows `Emergency` when `confidence >= 0.30` and `SpO2 < 94`

## Non-Negotiable Rule

Do not keep two independent inference implementations in production unless they are validated against the same exported model and the same preprocessing.

For now, pick one truth:

- backend inference from `train-model.ipynb`

That is the cleanest path to a working live app.
