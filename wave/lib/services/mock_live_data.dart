import 'dart:async';
import 'dart:math' as math;

import '../features/app_state/app_state.dart';
import '../features/live_data/live_models.dart';

class MockLiveDataStore {
  static final DateTime _seedTime = DateTime.now().toUtc();

  static List<ChildSummary> children() {
    return const <ChildSummary>[
      ChildSummary(
        id: 'child_lina',
        name: 'Lina',
        ageLabel: '4y 2m',
        deviceId: 'WM-2048',
        hasAssignedDevice: true,
      ),
      ChildSummary(
        id: 'child_omar',
        name: 'Omar',
        ageLabel: '7y 1m',
        deviceId: 'WM-1781',
        hasAssignedDevice: true,
      ),
    ];
  }

  static LiveMonitorFrame latestFrame(String childId, {int tick = 0}) {
    final bool lina = childId == 'child_lina';
    final DateTime capturedAt = _seedTime.add(Duration(seconds: tick * 5));
    final int spo2 = lina ? math.max(92, 96 - (tick % 3)) : 97 + (tick % 2);
    final double backendConfidence = lina
        ? (tick % 4 == 3 ? 0.82 : 0.34 + ((tick % 3) * 0.08))
        : 0.12 + ((tick % 2) * 0.05);
    final PredictionResult backend = PredictionResult(
      source: PredictionSource.backend,
      label: backendConfidence >= 0.30
          ? PredictionLabel.wheeze
          : PredictionLabel.normal,
      confidence: backendConfidence,
      threshold: 0.30,
      capturedAt: capturedAt,
    );
    final double deviceConfidence = lina
        ? backendConfidence - (tick.isEven ? 0.04 : 0.22)
        : backendConfidence + 0.02;
    final PredictionResult device = PredictionResult(
      source: PredictionSource.device,
      label: deviceConfidence >= 0.30
          ? PredictionLabel.wheeze
          : PredictionLabel.normal,
      confidence: deviceConfidence.clamp(0.0, 1.0),
      threshold: 0.30,
      capturedAt: capturedAt,
    );
    final LiveVitals vitals = LiveVitals(
      spo2: spo2,
      bpm: lina ? 108 + (tick % 4) : 90 + (tick % 3),
      temperatureC: lina ? 37.1 + ((tick % 3) * 0.1) : 36.7,
      battery: lina ? 82 - (tick % 5) : 63 - (tick % 4),
      humidity: lina ? 38 + (tick % 5) : 46 + (tick % 4),
      aqi: lina ? 41 + (tick % 6) : 22 + (tick % 3),
    );
    return LiveMonitorFrame(
      childId: childId,
      deviceId: lina ? 'WM-2048' : 'WM-1781',
      capturedAt: capturedAt,
      vitals: vitals,
      comparison: ComparisonResult.fromSources(
        backend: backend,
        device: device,
        vitals: vitals,
      ),
      waveformPreview: _waveform(tick),
      nextScanSeconds: 30 - ((tick * 5) % 30),
    );
  }

  static List<AlertEvent> alerts(String childId) {
    final List<AlertEvent> items = <AlertEvent>[
      _alert(
        id: '$childId-alert-1',
        childId: childId,
        titleEn: 'Wheeze detected',
        titleAr: 'تم اكتشاف أزيز',
        bodyEn: 'Backend confidence crossed the alert threshold.',
        bodyAr: 'تجاوزت ثقة الخادم حد التنبيه.',
        tick: 1,
        requiresAck: false,
      ),
      _alert(
        id: '$childId-alert-2',
        childId: childId,
        titleEn: 'Humidity low',
        titleAr: 'الرطوبة منخفضة',
        bodyEn: 'Room humidity dropped under the recommended range.',
        bodyAr: 'انخفضت رطوبة الغرفة عن النطاق الموصى به.',
        tick: 2,
        severity: AlertSeverity.normal,
      ),
    ];

    if (childId == 'child_lina') {
      items.insert(
        0,
        _alert(
          id: '$childId-alert-3',
          childId: childId,
          titleEn: 'Emergency breathing pattern',
          titleAr: 'نمط تنفس طارئ',
          bodyEn: 'Persistent wheeze with falling SpO2 requires acknowledgement.',
          bodyAr: 'أزيز مستمر مع انخفاض الأكسجين ويتطلب تأكيداً.',
          tick: 3,
          severity: AlertSeverity.emergency,
          requiresAck: true,
        ),
      );
    }
    return items;
  }

  static AlertEvent alertDetail(String childId, String alertId) {
    return alerts(childId).firstWhere(
      (AlertEvent alert) => alert.id == alertId,
      orElse: () => alerts(childId).first,
    );
  }

  static SetupStatus setupStatus(String childId) {
    final ChildSummary child = children().firstWhere(
      (ChildSummary item) => item.id == childId,
      orElse: () => children().first,
    );
    return SetupStatus(
      child: child,
      bleProvisioningEnabled: false,
      steps: <SetupStepStatus>[
        const SetupStepStatus(
          titleEn: 'Child profile',
          titleAr: 'ملف الطفل',
          descriptionEn: 'Child is registered in the care workspace.',
          descriptionAr: 'تم تسجيل الطفل في مساحة الرعاية.',
          state: SetupStepState.completed,
        ),
        SetupStepStatus(
          titleEn: 'Device assignment',
          titleAr: 'ربط الجهاز',
          descriptionEn: 'Assigned device ${child.deviceId} is ready.',
          descriptionAr: 'تم تجهيز الجهاز ${child.deviceId}.',
          state: SetupStepState.completed,
        ),
        const SetupStepStatus(
          titleEn: 'BLE / Wi-Fi provisioning',
          titleAr: 'إعداد BLE و Wi-Fi',
          descriptionEn: 'Blocked until the firmware GATT contract is supplied.',
          descriptionAr: 'متوقف حتى يتم توفير عقد GATT الخاص بالبرنامج الثابت.',
          state: SetupStepState.blocked,
        ),
      ],
    );
  }

  static Future<LiveStreamEnvelope> nextEnvelope(String childId, int tick) async {
    final LiveMonitorFrame frame = latestFrame(childId, tick: tick);
    if (childId == 'child_lina' && tick % 4 == 3) {
      return LiveStreamEnvelope(
        frame: frame,
        alert: _alert(
          id: '$childId-live-$tick',
          childId: childId,
          titleEn: 'Live emergency event',
          titleAr: 'حدث طارئ مباشر',
          bodyEn: 'Backend flagged wheeze with low oxygen.',
          bodyAr: 'حدد الخادم أزيزاً مع انخفاض الأكسجين.',
          tick: tick,
          severity: AlertSeverity.emergency,
          requiresAck: true,
        ),
      );
    }
    if (tick.isOdd) {
      return LiveStreamEnvelope(
        frame: frame,
        alert: _alert(
          id: '$childId-live-$tick',
          childId: childId,
          titleEn: 'Live wheeze event',
          titleAr: 'حدث أزيز مباشر',
          bodyEn: 'Backend and device scans were compared.',
          bodyAr: 'تمت مقارنة نتائج الخادم والجهاز.',
          tick: tick,
        ),
      );
    }
    return LiveStreamEnvelope(frame: frame);
  }

  static List<WeeklyMetric> weeklyMetrics(AppLanguage language) {
    return const <WeeklyMetric>[
      WeeklyMetric(labelEn: 'Mon', labelAr: 'الإثنين', wheezeCount: 2, spo2: 97.0),
      WeeklyMetric(labelEn: 'Tue', labelAr: 'الثلاثاء', wheezeCount: 3, spo2: 96.4),
      WeeklyMetric(labelEn: 'Wed', labelAr: 'الأربعاء', wheezeCount: 1, spo2: 97.6),
      WeeklyMetric(labelEn: 'Thu', labelAr: 'الخميس', wheezeCount: 4, spo2: 95.9),
      WeeklyMetric(labelEn: 'Fri', labelAr: 'الجمعة', wheezeCount: 2, spo2: 96.8),
      WeeklyMetric(labelEn: 'Sat', labelAr: 'السبت', wheezeCount: 1, spo2: 97.8),
      WeeklyMetric(labelEn: 'Sun', labelAr: 'الأحد', wheezeCount: 2, spo2: 97.1),
    ];
  }

  static List<SmartDevice> smartDevices() {
    return const <SmartDevice>[
      SmartDevice(
        nameEn: 'Air purifier',
        nameAr: 'منقي الهواء',
        reasonEn: 'Secondary automation screen pending backend control.',
        reasonAr: 'شاشة التشغيل التلقائي مؤجلة حتى دعم الخادم.',
        iconCodePoint: 0xe064,
        isOn: true,
      ),
      SmartDevice(
        nameEn: 'Humidifier',
        nameAr: 'مرطب الجو',
        reasonEn: 'Available as placeholder until MQTT integration lands.',
        reasonAr: 'متاح مؤقتاً حتى يكتمل ربط MQTT.',
        iconCodePoint: 0xe798,
        isOn: false,
      ),
    ];
  }

  static List<ChatMessage> assistantMessages() {
    return const <ChatMessage>[
      ChatMessage(
        text:
            'AI assistant remains in placeholder mode until backend conversation context is added.',
        isUser: false,
      ),
    ];
  }

  static AlertEvent _alert({
    required String id,
    required String childId,
    required String titleEn,
    required String titleAr,
    required String bodyEn,
    required String bodyAr,
    required int tick,
    AlertSeverity? severity,
    bool requiresAck = false,
  }) {
    final LiveMonitorFrame frame = latestFrame(childId, tick: tick);
    final AlertSeverity resolvedSeverity = severity ?? frame.status;
    return AlertEvent(
      id: id,
      titleEn: titleEn,
      titleAr: titleAr,
      bodyEn: bodyEn,
      bodyAr: bodyAr,
      severity: resolvedSeverity,
      occurredAt: frame.capturedAt,
      vitals: frame.vitals,
      comparison: frame.comparison,
      requiresAck: requiresAck,
      acknowledged: false,
    );
  }

  static List<double> _waveform(int tick) {
    return List<double>.generate(80, (int index) {
      final double x = (index + tick) / 8;
      return (math.sin(x) * 0.6) + (math.sin(x * 2.4) * 0.18);
    }, growable: false);
  }
}
