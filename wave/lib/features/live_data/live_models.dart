import 'package:flutter/foundation.dart';

import '../app_state/app_state.dart';

enum PredictionSource { backend, device }

enum PredictionLabel { normal, wheeze }

enum ConnectionHealth { connecting, connected, degraded }

enum SetupStepState { pending, completed, blocked }

@immutable
class ChildSummary {
  const ChildSummary({
    required this.id,
    required this.name,
    required this.ageLabel,
    required this.deviceId,
    required this.hasAssignedDevice,
  });

  final String id;
  final String name;
  final String ageLabel;
  final String deviceId;
  final bool hasAssignedDevice;

  factory ChildSummary.fromJson(Map<String, dynamic> json) {
    return ChildSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      ageLabel: json['age_label'] as String? ?? json['age'] as String? ?? '-',
      deviceId: json['device_id'] as String? ?? 'Unassigned',
      hasAssignedDevice:
          json['has_assigned_device'] as bool? ??
          ((json['device_id'] as String?)?.isNotEmpty ?? false),
    );
  }
}

@immutable
class LiveVitals {
  const LiveVitals({
    this.spo2,
    this.bpm,
    required this.temperatureC,
    required this.battery,
    required this.humidity,
    required this.aqi,
  });

  final int? spo2;
  final int? bpm;
  final double temperatureC;
  final int battery;
  final int humidity;
  final int aqi;

  factory LiveVitals.fromJson(Map<String, dynamic> json) {
    int? nullableInt(dynamic v) {
      if (v == null) {
        return null;
      }
      if (v is num) {
        return v.round();
      }
      return null;
    }

    return LiveVitals(
      spo2: nullableInt(json['spo2']),
      bpm: nullableInt(json['bpm']),
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 0,
      battery: (json['battery'] as num?)?.round() ?? 0,
      humidity: (json['humidity'] as num?)?.round() ?? 0,
      aqi: (json['aqi'] as num?)?.round() ?? 0,
    );
  }
}

@immutable
class PredictionResult {
  const PredictionResult({
    required this.source,
    required this.label,
    required this.confidence,
    required this.threshold,
    required this.capturedAt,
  });

  final PredictionSource source;
  final PredictionLabel label;
  final double confidence;
  final double threshold;
  final DateTime capturedAt;

  bool get isWheeze => label == PredictionLabel.wheeze;

  factory PredictionResult.fromJson(
    Map<String, dynamic> json, {
    required PredictionSource source,
    DateTime? fallbackCapturedAt,
  }) {
    final String rawLabel =
        (json['label'] as String? ?? json['status'] as String? ?? 'normal')
            .toLowerCase();
    return PredictionResult(
      source: source,
      label: rawLabel == 'wheeze'
          ? PredictionLabel.wheeze
          : PredictionLabel.normal,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.30,
      capturedAt: DateTime.tryParse(json['captured_at'] as String? ?? '') ??
          fallbackCapturedAt ??
          DateTime.now(),
    );
  }
}

@immutable
class ComparisonResult {
  const ComparisonResult({
    required this.backend,
    required this.device,
    required this.derivedSeverity,
    required this.isMismatch,
  });

  final PredictionResult backend;
  final PredictionResult? device;
  final AlertSeverity derivedSeverity;
  final bool isMismatch;

  factory ComparisonResult.fromSources({
    required PredictionResult backend,
    required PredictionResult? device,
    required LiveVitals vitals,
  }) {
    return ComparisonResult(
      backend: backend,
      device: device,
      derivedSeverity: deriveSeverity(
        backendLabel: backend.label,
        spo2: vitals.spo2,
      ),
      isMismatch: _isMismatch(backend, device),
    );
  }

  static bool _isMismatch(
    PredictionResult backend,
    PredictionResult? device,
  ) {
    if (device == null) {
      return false;
    }
    return backend.label != device.label ||
        (backend.confidence - device.confidence).abs() >= 0.20;
  }
}

@immutable
class LiveMonitorFrame {
  const LiveMonitorFrame({
    required this.childId,
    required this.deviceId,
    required this.capturedAt,
    required this.vitals,
    required this.comparison,
    required this.waveformPreview,
    required this.nextScanSeconds,
  });

  final String childId;
  final String deviceId;
  final DateTime capturedAt;
  final LiveVitals vitals;
  final ComparisonResult comparison;
  final List<double> waveformPreview;
  final int nextScanSeconds;

  AlertSeverity get status => comparison.derivedSeverity;

  String lastSyncLabel(AppLanguage language) {
    final Duration age = DateTime.now().difference(capturedAt);
    if (age.inSeconds < 60) {
      return tr(
        language,
        '${age.inSeconds}s ago',
        'منذ ${age.inSeconds}ث',
      );
    }
    return tr(
      language,
      '${age.inMinutes}m ago',
      'منذ ${age.inMinutes}د',
    );
  }

  factory LiveMonitorFrame.fromJson(Map<String, dynamic> json) {
    final DateTime capturedAt =
        DateTime.tryParse(json['captured_at'] as String? ?? '') ??
        DateTime.now();
    final LiveVitals vitals = LiveVitals.fromJson(json);
    final PredictionResult backend = PredictionResult.fromJson(
      (json['backend_prediction'] as Map<String, dynamic>?) ??
          <String, dynamic>{
            'label': json['status'],
            'confidence': json['confidence'],
            'threshold': json['threshold'],
            'captured_at': json['captured_at'],
          },
      source: PredictionSource.backend,
      fallbackCapturedAt: capturedAt,
    );
    final PredictionResult? device = _predictionFromOptional(
      json['device_prediction'],
      source: PredictionSource.device,
      fallbackCapturedAt: capturedAt,
    );

    return LiveMonitorFrame(
      childId: json['child_id'] as String,
      deviceId: json['device_id'] as String? ?? 'Unknown',
      capturedAt: capturedAt,
      vitals: vitals,
      comparison: ComparisonResult.fromSources(
        backend: backend,
        device: device,
        vitals: vitals,
      ),
      waveformPreview: (json['waveform_preview'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => (value as num).toDouble())
          .toList(growable: false),
      nextScanSeconds: (json['next_scan_seconds'] as num?)?.round() ?? 30,
    );
  }
}

@immutable
class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.severity,
    required this.occurredAt,
    required this.vitals,
    required this.comparison,
    required this.requiresAck,
    required this.acknowledged,
  });

  final String id;
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
  final AlertSeverity severity;
  final DateTime occurredAt;
  final LiveVitals vitals;
  final ComparisonResult comparison;
  final bool requiresAck;
  final bool acknowledged;

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    final DateTime occurredAt =
        DateTime.tryParse(json['occurred_at'] as String? ?? '') ??
        DateTime.tryParse(json['captured_at'] as String? ?? '') ??
        DateTime.now();
    final LiveVitals vitals = LiveVitals.fromJson(json);
    final PredictionResult backend = PredictionResult.fromJson(
      (json['backend_prediction'] as Map<String, dynamic>?) ??
          <String, dynamic>{
            'label': json['status'],
            'confidence': json['confidence'],
            'threshold': json['threshold'],
            'captured_at': json['captured_at'],
          },
      source: PredictionSource.backend,
      fallbackCapturedAt: occurredAt,
    );
    final PredictionResult? device = _predictionFromOptional(
      json['device_prediction'],
      source: PredictionSource.device,
      fallbackCapturedAt: occurredAt,
    );
    final AlertSeverity severity = _severityFromRaw(
      (json['severity'] as String?)?.toLowerCase(),
      fallback: deriveSeverity(
        backendLabel: backend.label,
        spo2: vitals.spo2,
      ),
    );
    return AlertEvent(
      id: json['id'] as String? ??
          json['alert_id'] as String? ??
          '${occurredAt.microsecondsSinceEpoch}',
      titleEn: json['title_en'] as String? ??
          json['title'] as String? ??
          'Wheeze event',
      titleAr: json['title_ar'] as String? ??
          json['title'] as String? ??
          'حدث أزيز',
      bodyEn: json['body_en'] as String? ??
          json['body'] as String? ??
          'Monitoring event received.',
      bodyAr: json['body_ar'] as String? ??
          json['body'] as String? ??
          'تم استقبال حدث للمراقبة.',
      severity: severity,
      occurredAt: occurredAt,
      vitals: vitals,
      comparison: ComparisonResult.fromSources(
        backend: backend,
        device: device,
        vitals: vitals,
      ),
      requiresAck: json['requires_ack'] as bool? ?? false,
      acknowledged: json['acknowledged'] as bool? ?? false,
    );
  }
}

@immutable
class DeviceAssignment {
  const DeviceAssignment({
    required this.childId,
    required this.deviceId,
    required this.networkName,
    required this.networkPassword,
  });

  final String childId;
  final String deviceId;
  final String networkName;
  final String networkPassword;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'child_id': childId,
      'device_id': deviceId,
      'network_name': networkName,
      'network_password': networkPassword,
    };
  }
}

@immutable
class SetupStepStatus {
  const SetupStepStatus({
    required this.titleEn,
    required this.titleAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.state,
  });

  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;
  final SetupStepState state;
}

@immutable
class SetupStatus {
  const SetupStatus({
    required this.child,
    required this.steps,
    required this.bleProvisioningEnabled,
  });

  final ChildSummary child;
  final List<SetupStepStatus> steps;
  final bool bleProvisioningEnabled;
}

@immutable
class LiveStreamEnvelope {
  const LiveStreamEnvelope({
    this.frame,
    this.alert,
    this.connection = ConnectionHealth.connected,
  });

  final LiveMonitorFrame? frame;
  final AlertEvent? alert;
  final ConnectionHealth connection;
}

@immutable
class ChildSessionState {
  const ChildSessionState({
    required this.child,
    required this.frame,
    required this.alerts,
    required this.connection,
    required this.setupStatus,
  });

  final ChildSummary child;
  final LiveMonitorFrame frame;
  final List<AlertEvent> alerts;
  final ConnectionHealth connection;
  final SetupStatus setupStatus;

  ChildSessionState copyWith({
    ChildSummary? child,
    LiveMonitorFrame? frame,
    List<AlertEvent>? alerts,
    ConnectionHealth? connection,
    SetupStatus? setupStatus,
  }) {
    return ChildSessionState(
      child: child ?? this.child,
      frame: frame ?? this.frame,
      alerts: alerts ?? this.alerts,
      connection: connection ?? this.connection,
      setupStatus: setupStatus ?? this.setupStatus,
    );
  }

  AlertEvent? activeEmergency({
    required Set<String> locallyAcknowledgedAlerts,
  }) {
    for (final AlertEvent alert in alerts) {
      if (alert.severity == AlertSeverity.emergency &&
          alert.requiresAck &&
          !alert.acknowledged &&
          !locallyAcknowledgedAlerts.contains(alert.id)) {
        return alert;
      }
    }
    return null;
  }
}

AlertSeverity deriveSeverity({
  required PredictionLabel backendLabel,
  required int? spo2,
}) {
  if (backendLabel != PredictionLabel.wheeze) {
    return AlertSeverity.normal;
  }
  if (spo2 != null && spo2 < 94) {
    return AlertSeverity.emergency;
  }
  return AlertSeverity.wheeze;
}

PredictionResult? _predictionFromOptional(
  dynamic json, {
  required PredictionSource source,
  required DateTime fallbackCapturedAt,
}) {
  if (json is! Map<String, dynamic>) {
    return null;
  }
  try {
    return PredictionResult.fromJson(
      json,
      source: source,
      fallbackCapturedAt: fallbackCapturedAt,
    );
  } catch (_) {
    return null;
  }
}

AlertSeverity _severityFromRaw(String? raw, {required AlertSeverity fallback}) {
  return switch (raw) {
    'emergency' => AlertSeverity.emergency,
    'wheeze' => AlertSeverity.wheeze,
    'normal' => AlertSeverity.normal,
    _ => fallback,
  };
}
