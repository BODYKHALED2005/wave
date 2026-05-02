/*
 * WaveMed ESP32 Firmware — Backend Edition
 * ==========================================
 * نفس الأجهزة بالظبط، لكن بدل ما نشغل النموذج هنا
 * هنبعت الصوت + القراءات للـ Backend عشان يشغل النموذج الحقيقي
 *
 * Sensors:
 *   MAX30102  → SpO2 + BPM      (I2C_MAX: SDA=4, SCL=5)
 *   MLX90614  → درجة الحرارة    (I2C_MLX: SDA=1, SCL=2)
 *   INMP441   → Mic I2S         (WS=11, SD=13, SCK=12)
 */

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <driver/i2s.h>
#include <time.h>
#include "esp_heap_caps.h"
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <Adafruit_MLX90614.h>
#include "mbedtls/base64.h"

// ─── ✏️ عدّل القيم دي بس ────────────────────────────────────────────────────────
const char* WIFI_SSID   = "WE88B9DF";      // ← اسم الـ WiFi
const char* WIFI_PASS   = "ka106669";      // ← باسوورد الـ WiFi
const char* BACKEND_URL = "http://192.168.1.2:8000"; // ← IP جهازك
const char* DEVICE_ID   = "WM-2048";
const char* CHILD_ID    = "child_lina";          // ← ID الطفل في الـ DB
// ────────────────────────────────────────────────────────────────────────────────

// ─── I2S Mic ──────────────────────────────────────────────────────────────────
#define I2S_WS      11
#define I2S_SD      13
#define I2S_SCK     12
#define SAMPLE_RATE 16000
#define DURATION_S  5
#define FALLBACK_DURATION_S 2
#define TOTAL_SAMPLES (SAMPLE_RATE * DURATION_S)  // 80,000 sample (default)

// ─── I2C ──────────────────────────────────────────────────────────────────────
TwoWire I2C_MAX = TwoWire(0);  // MAX30102 on SDA=4, SCL=5
TwoWire I2C_MLX = TwoWire(1);  // MLX90614 on SDA=1, SCL=2

MAX30105             particleSensor;
Adafruit_MLX90614   mlx = Adafruit_MLX90614();

// ─── SpO2 buffers ─────────────────────────────────────────────────────────────
uint32_t irBuffer[100];
uint32_t redBuffer[100];
int32_t  spo2Val, heartRateVal;
int8_t   validSPO2, validHR;

// ─── Audio buffer (في الـ PSRAM) ──────────────────────────────────────────────
int16_t* audioBuffer = nullptr;
int recordingDurationS = DURATION_S;
size_t recordingSamples = TOTAL_SAMPLES;

// ─────────────────────────────────────────────────────────────────────────────
String currentUtcIso8601() {
  struct tm timeinfo;
  if (getLocalTime(&timeinfo, 1500)) {
    char ts[30];
    strftime(ts, sizeof(ts), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
    return String(ts);
  }

  // Fallback when NTP is unavailable: monotonic time in UTC-like format.
  unsigned long seconds = millis() / 1000;
  char fallback[30];
  snprintf(fallback, sizeof(fallback), "1970-01-01T00:%02lu:%02luZ",
           (seconds / 60) % 60, seconds % 60);
  return String(fallback);
}

// ─────────────────────────────────────────────────────────────────────────────
void setup_i2s() {
  const i2s_config_t i2s_config = {
    .mode                 = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
    .sample_rate          = SAMPLE_RATE,
    .bits_per_sample      = I2S_BITS_PER_SAMPLE_32BIT, // INMP441 بيبعت 32bit
    .channel_format       = I2S_CHANNEL_FMT_ONLY_LEFT,
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags     = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count        = 8,
    .dma_buf_len          = 64,
    .use_apll             = false,
    .tx_desc_auto_clear   = false,
    .fixed_mclk           = 0
  };
  const i2s_pin_config_t pin_config = {
    .bck_io_num   = I2S_SCK,
    .ws_io_num    = I2S_WS,
    .data_out_num = I2S_PIN_NO_CHANGE,
    .data_in_num  = I2S_SD
  };
  i2s_driver_install(I2S_NUM_0, &i2s_config, 0, NULL);
  i2s_set_pin(I2S_NUM_0, &pin_config);
}

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n[WaveMed] Starting...");

  // تخصيص الـ Buffer في الـ PSRAM
  if (psramInit()) {
    Serial.println("✅ PSRAM Ready");
    audioBuffer = (int16_t*)ps_malloc(TOTAL_SAMPLES * sizeof(int16_t));
  }
  if (!audioBuffer) {
    // بدون PSRAM نقلل مدة التسجيل لتقليل استهلاك الذاكرة.
    recordingDurationS = FALLBACK_DURATION_S;
    recordingSamples = SAMPLE_RATE * recordingDurationS;
    Serial.printf("⚠️ PSRAM فاشل، بستخدم Heap مع تسجيل %d ثانية.\n", recordingDurationS);
    audioBuffer = (int16_t*)malloc(recordingSamples * sizeof(int16_t));
  }
  if (!audioBuffer) {
    Serial.println("❌ فشل تخصيص الذاكرة! وقف.");
    while (1);
  }

  setup_i2s();
  Serial.println("✅ Mic Ready");

  // MAX30102
  I2C_MAX.begin(4, 5, 400000);
  if (particleSensor.begin(I2C_MAX, I2C_SPEED_FAST)) {
    particleSensor.setup(60, 4, 2, 100, 411, 4096);
    Serial.println("✅ MAX30102 Ready");
  } else {
    Serial.println("❌ MAX30102 مش لاقيه!");
  }

  // MLX90614
  I2C_MLX.begin(1, 2, 100000);
  if (mlx.begin(0x5A, &I2C_MLX)) {
    Serial.println("✅ MLX90614 Ready");
  } else {
    Serial.println("❌ MLX90614 مش لاقيه!");
  }

  // WiFi
  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED && tries++ < 40) {
    delay(500);
    Serial.print(".");
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n✅ WiFi Connected! IP: %s\n", WiFi.localIP().toString().c_str());
    configTime(0, 0, "pool.ntp.org", "time.nist.gov");
    struct tm timeinfo;
    if (getLocalTime(&timeinfo, 3000)) {
      Serial.println("✅ NTP time synced");
    } else {
      Serial.println("⚠️ NTP sync failed, using fallback timestamp.");
    }
  } else {
    Serial.println("\n❌ WiFi فشل!");
  }

  Serial.println("[WaveMed] ✅ جاهز! بدأ المسح كل 30 ثانية.");
}

// ─────────────────────────────────────────────────────────────────────────────
void loop() {
  Serial.println("\n══════════════════════════════");
  Serial.println("[WaveMed] 🔄 بدأ مسح جديد...");

  // 1. قراءة درجة الحرارة
  float temp = mlx.readObjectTempC();
  if (isnan(temp)) temp = 36.5;
  Serial.printf("🌡️  درجة الحرارة: %.1f°C\n", temp);

  // 2. قراءة النبض والأكسجين
  Serial.println("💓 بقيس النبض... خليك ثابت 10 ثواني");
  for (byte i = 0; i < 100; i++) {
    while (particleSensor.available() == false) particleSensor.check();
    redBuffer[i] = particleSensor.getRed();
    irBuffer[i]  = particleSensor.getIR();
    particleSensor.nextSample();
  }
  maxim_heart_rate_and_oxygen_saturation(
    irBuffer, 100, redBuffer,
    &spo2Val, &validSPO2, &heartRateVal, &validHR
  );
  int bpm  = (validHR   && heartRateVal > 20) ? (int)heartRateVal : 75;
  int spo2 = (validSPO2 && spo2Val > 50)      ? (int)spo2Val     : 98;
  Serial.printf("💓 BPM: %d  |  🫁 SpO2: %d%%\n", bpm, spo2);

  // 3. تسجيل الصوت
  Serial.printf("🎤 تسجيل الصوت %d ثانية...\n", recordingDurationS);
  size_t totalBytesNeeded = recordingSamples * sizeof(int16_t);
  size_t totalBytesRead   = 0;

  while (totalBytesRead < totalBytesNeeded) {
    int32_t sample32 = 0;
    size_t  bytesRead = 0;
    // اقرأ sample 32-bit وحوّله لـ 16-bit زي ما الكود الأصلي بيعمل
    i2s_read(I2S_NUM_0, &sample32, sizeof(sample32), &bytesRead, portMAX_DELAY);
    if (bytesRead > 0) {
      size_t idx = totalBytesRead / sizeof(int16_t);
      audioBuffer[idx] = (int16_t)(sample32 >> 14); // تحويل 32→16 bit
      totalBytesRead += sizeof(int16_t);
    }
  }
  Serial.println("✅ تسجيل الصوت خلص.");

  // 4. تشفير الصوت Base64
  Serial.println("🔐 تشفير الصوت...");
  size_t  rawSize     = recordingSamples * sizeof(int16_t);
  size_t  encodedSize = 4 * ((rawSize + 2) / 3) + 1;
  uint8_t* encoded    = (uint8_t*)ps_malloc(encodedSize);
  if (!encoded) encoded = (uint8_t*)malloc(encodedSize);

  if (!encoded) {
    Serial.println("❌ فشل تخصيص ذاكرة للـ Base64");
    delay(10000);
    return;
  }

  size_t writtenLen = 0;
  mbedtls_base64_encode(encoded, encodedSize, &writtenLen, (const uint8_t*)audioBuffer, rawSize);
  encoded[writtenLen] = '\0';
  Serial.printf("✅ حجم الصوت المشفر: %d حرف\n", writtenLen);

  // 5. إرسال للـ Backend
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("📡 بعت للـ Backend...");

    HTTPClient http;
    http.begin(String(BACKEND_URL) + "/api/v1/device-scan");
    http.addHeader("Content-Type", "application/json");
    http.setTimeout(60000); // 60 ثانية للـ inference

    // ابني JSON يدويًا لتفادي تحويل audio_base64 إلى null تحت ضغط الذاكرة.
    String body;
    body.reserve(writtenLen + 512);
    body += "{\"device_id\":\"";
    body += DEVICE_ID;
    body += "\",\"child_id\":\"";
    body += CHILD_ID;
    body += "\",\"captured_at\":\"";
    body += currentUtcIso8601();
    body += "\",\"spo2\":";
    body += String(spo2);
    body += ",\"bpm\":";
    body += String(bpm);
    body += ",\"temperature_c\":";
    body += String(temp, 2);
    body += ",\"humidity\":50,\"battery\":90,\"aqi\":0,\"sample_rate\":";
    body += String(SAMPLE_RATE);
    body += ",\"duration_sec\":";
    body += String(recordingDurationS);
    body += ",\"audio_base64\":\"";
    body += (char*)encoded;
    body += "\"}";
    free(encoded);

    int code = http.POST(body);
    body = "";

    if (code > 0) {
      String resp = http.getString();
      Serial.printf("✅ رد السيرفر (%d): %s\n", code, resp.c_str());
    } else {
      Serial.printf("❌ خطأ HTTP: %s\n", http.errorToString(code).c_str());
    }
    http.end();
  } else {
    free(encoded);
    Serial.println("❌ WiFi مش متصل!");
    WiFi.reconnect();
  }

  Serial.println("[WaveMed] ✅ انتهى المسح. استنى 30 ثانية...");
  delay(30000);
}
