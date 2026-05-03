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

/** IR average threshold: without a finger readings are usually much lower — tune via Serial Monitor. */
constexpr uint32_t MAX30102_IR_FINGER_MIN = 45000UL;
/** خوارزمية Maxim أحيانًا تعطي SpO2 بين 70–100 قبل الاستقرار؛ 85 كانت صارمة جدًا. */
constexpr int32_t SPO2_MIN_ACCEPT = 70;
constexpr int32_t SPO2_MAX_ACCEPT = 100;
constexpr int32_t BPM_MIN_ACCEPT  = 40;
constexpr int32_t BPM_MAX_ACCEPT  = 220;

// ─── SpO2 buffers ─────────────────────────────────────────────────────────────
uint32_t irBuffer[100];
uint32_t redBuffer[100];
int32_t  spo2Val, heartRateVal;
int8_t   validSPO2, validHR;

// ─── Audio buffer (في الـ PSRAM) ──────────────────────────────────────────────
int16_t* audioBuffer = nullptr;
int recordingDurationS = DURATION_S;
size_t recordingSamples = TOTAL_SAMPLES;

static bool g_max30102Ready = false;
static int32_t g_lastGoodBpm = 0;
static int32_t g_lastGoodSpo2 = 0;

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
    g_max30102Ready = true;
    Serial.println("✅ MAX30102 Ready");
  } else {
    g_max30102Ready = false;
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
  int32_t  spo2ValLocal = 0;
  int32_t  heartRateValLocal = 0;
  int8_t   validSPO2Local = 0;
  int8_t   validHRLocal = 0;
  uint32_t irAvg = 0;

  if (!g_max30102Ready) {
    Serial.println("⚠️ تخطّي نبض/SpO2 — MAX30102 غير مهيأ.");
    validHR = 0;
    validSPO2 = 0;
    heartRateVal = 0;
    spo2Val = 0;
  } else {
    Serial.println("💓 بقيس النبض... ثبّت الإصبع 10–15 ثانية على الحساس.");
    // تسخين: عيّنات أولى ترمى حتى يستقر الفلتر والـ LED
    for (word w = 0; w < 120; w++) {
      while (particleSensor.available() == false) {
        particleSensor.check();
      }
      particleSensor.nextSample();
    }

    for (byte attempt = 0; attempt < 2; attempt++) {
      for (byte i = 0; i < 100; i++) {
        while (particleSensor.available() == false) {
          particleSensor.check();
        }
        redBuffer[i] = particleSensor.getRed();
        irBuffer[i]  = particleSensor.getIR();
        particleSensor.nextSample();
      }
      maxim_heart_rate_and_oxygen_saturation(
        irBuffer, 100, redBuffer,
        &spo2ValLocal, &validSPO2Local, &heartRateValLocal, &validHRLocal
      );
      if (validHRLocal && validSPO2Local) {
        break;
      }
      delay(150);
    }

    uint64_t irSum = 0;
    for (byte i = 0; i < 100; i++) {
      irSum += irBuffer[i];
    }
    irAvg = (uint32_t)(irSum / 100UL);

    validHR = validHRLocal;
    validSPO2 = validSPO2Local;
    heartRateVal = heartRateValLocal;
    spo2Val = spo2ValLocal;
  }

  bool fingerPresent = g_max30102Ready && irAvg >= MAX30102_IR_FINGER_MIN;
  // validHR/validSPO2 flags from Maxim can flap on noisy contacts.
  bool hrInRange = heartRateVal >= BPM_MIN_ACCEPT && heartRateVal <= BPM_MAX_ACCEPT;
  bool spo2InRange = spo2Val >= SPO2_MIN_ACCEPT && spo2Val <= SPO2_MAX_ACCEPT;
  bool hrOk = fingerPresent && hrInRange;
  bool spo2Ok = fingerPresent && spo2InRange;

  if (hrOk) g_lastGoodBpm = heartRateVal;
  if (spo2Ok) g_lastGoodSpo2 = spo2Val;

  int32_t bpmToSend = hrOk ? heartRateVal : (g_lastGoodBpm > 0 ? g_lastGoodBpm : 0);
  int32_t spo2ToSend = spo2Ok ? spo2Val : (g_lastGoodSpo2 > 0 ? g_lastGoodSpo2 : 0);
  bool bpmHasValue = bpmToSend > 0;
  bool spo2HasValue = spo2ToSend > 0;

  if (g_max30102Ready) {
    Serial.printf("MAX30102 IR avg: %lu (finger if >= %lu)\n",
                  (unsigned long)irAvg,
                  (unsigned long)MAX30102_IR_FINGER_MIN);
    Serial.printf(
        "MAX30102 raw: validHR=%d BPM=%ld | validSpO2=%d SpO2=%ld\n",
        (int)validHR,
        (long)heartRateVal,
        (int)validSPO2,
        (long)spo2Val);
  }
  if (!fingerPresent || !hrOk || !spo2Ok) {
    Serial.println(
        "⚠️ لا قراءة نبض/أكسجة موثوقة — ضَع الإصبع على المحس بحيث يغطي "
        "الLEDين وانتظر الثبات.");
    if (bpmHasValue) {
      Serial.printf("💓 BPM: %ld%s\n",
                    (long)bpmToSend,
                    hrOk ? "" : " (last valid)");
    } else {
      Serial.println("💓 BPM: ---");
    }
    if (spo2HasValue) {
      Serial.printf("🫁 SpO2: %ld%%%s\n",
                    (long)spo2ToSend,
                    spo2Ok ? "" : " (last valid)");
    } else {
      Serial.println("🫁 SpO2: ---");
    }
  } else {
    Serial.printf("💓 BPM: %ld  |  🫁 SpO2: %ld%%\n",
                  (long)heartRateVal,
                  (long)spo2Val);
  }

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
  int b64rc = mbedtls_base64_encode(
      encoded, encodedSize, &writtenLen, (const uint8_t*)audioBuffer, rawSize);
  if (b64rc != 0 || writtenLen < 2048) {
    Serial.printf("❌ فشل Base64 (rc=%d, len=%u) — تخطي الإرسال.\n",
                  b64rc,
                  (unsigned)writtenLen);
    free(encoded);
    delay(5000);
    return;
  }
  encoded[writtenLen] = '\0';
  Serial.printf("✅ حجم الصوت المشفر: %u حرف\n", (unsigned)writtenLen);

  // 5. إرسال للـ Backend
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("📡 بعت للـ Backend...");

    // نبني Header/Prefix فقط، ونبعت Base64 stream مباشرة لتجنب تخصيص payload كبير.
    const String spo2Field = spo2HasValue ? String((int)spo2ToSend) : String("null");
    const String bpmField  = bpmHasValue ? String((int)bpmToSend) : String("null");
    const String prefix =
        String("{\"device_id\":\"") + DEVICE_ID +
        "\",\"child_id\":\"" + CHILD_ID +
        "\",\"captured_at\":\"" + currentUtcIso8601() +
        "\",\"spo2\":" + spo2Field +
        ",\"bpm\":" + bpmField +
        ",\"temperature_c\":" + String(temp, 2) +
        ",\"humidity\":50,\"battery\":90,\"aqi\":0,\"sample_rate\":" + String(SAMPLE_RATE) +
        ",\"duration_sec\":" + String(recordingDurationS) +
        ",\"audio_base64\":\"";
    const String suffix = "\"}";

    const size_t payloadLen = prefix.length() + writtenLen + suffix.length();
    Serial.printf("📦 JSON size: %u bytes\n", (unsigned)payloadLen);

    // Parse BACKEND_URL => host, port
    String hostPort = String(BACKEND_URL);
    if (!hostPort.startsWith("http://")) {
      Serial.println("❌ BACKEND_URL لازم يبدأ بـ http://");
      free(encoded);
      delay(5000);
      return;
    }
    hostPort.remove(0, 7); // remove http://
    int slashPos = hostPort.indexOf('/');
    if (slashPos >= 0) {
      hostPort = hostPort.substring(0, slashPos);
    }
    String host = hostPort;
    uint16_t port = 80;
    int colonPos = hostPort.indexOf(':');
    if (colonPos >= 0) {
      host = hostPort.substring(0, colonPos);
      port = (uint16_t)hostPort.substring(colonPos + 1).toInt();
      if (port == 0) port = 80;
    }

    bool requestOk = false;
    for (int attempt = 1; attempt <= 3 && !requestOk; attempt++) {
      WiFiClient client;
      client.setTimeout(12);

      if (!client.connect(host.c_str(), port)) {
        Serial.printf("❌ محاولة %d: فشل الاتصال بالـ Backend (TCP).\n", attempt);
        delay(200);
        continue;
      }

      // HTTP request headers
      client.print("POST /api/v1/device-scan HTTP/1.1\r\n");
      client.print("Host: " + host + "\r\n");
      client.print("Content-Type: application/json\r\n");
      client.print("Connection: close\r\n");
      client.print("Content-Length: ");
      client.print((unsigned)payloadLen);
      client.print("\r\n\r\n");

      // Stream body in parts (prefix + base64 + suffix)
      client.print(prefix);
      size_t sent = 0;
      while (sent < writtenLen) {
        size_t chunk = writtenLen - sent;
        if (chunk > 1024) chunk = 1024;
        size_t w = client.write(encoded + sent, chunk);
        if (w == 0) break;
        sent += w;
        delay(1); // avoids bursts that may drop Wi-Fi socket writes
      }
      client.print(suffix);

      if (sent != writtenLen) {
        Serial.printf("❌ محاولة %d: انقطاع أثناء إرسال audio_base64 (%u/%u).\n",
                      attempt,
                      (unsigned)sent,
                      (unsigned)writtenLen);
        client.stop();
        delay(200);
        continue;
      }

      // Read status line
      unsigned long t0 = millis();
      while (!client.available() && millis() - t0 < 12000) {
        delay(10);
      }
      if (!client.available()) {
        Serial.printf("❌ محاولة %d: لا يوجد رد من السيرفر (timeout).\n", attempt);
        client.stop();
        delay(200);
        continue;
      }
      String statusLine = client.readStringUntil('\n');
      statusLine.trim();
      if (statusLine.indexOf("200") >= 0) {
        Serial.printf("✅ رد السيرفر: %s\n", statusLine.c_str());
        requestOk = true;
      } else {
        Serial.printf("❌ محاولة %d: رد السيرفر: %s\n", attempt, statusLine.c_str());
      }
      client.stop();
    }

    free(encoded);
    if (!requestOk) {
      delay(5000);
      return;
    }
  } else {
    free(encoded);
    Serial.println("❌ WiFi مش متصل!");
    WiFi.reconnect();
  }

  Serial.println("[WaveMed] ✅ انتهى المسح. استنى 30 ثانية...");
  delay(30000);
}
