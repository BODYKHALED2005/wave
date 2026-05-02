import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../services/api_config.dart';
import '../../services/auth_session_service.dart';
import '../../services/device_api_service.dart';
import '../../services/gemini_service.dart';
import '../../services/live_stream_service.dart';
import '../../services/local_storage.dart';
import '../../services/mock_live_data.dart';
import '../live_data/live_models.dart';

enum AppLanguage { en, ar }

enum AlertSeverity { normal, wheeze, emergency }

String tr(AppLanguage language, String en, String ar) {
  return language == AppLanguage.en ? en : ar;
}

String severityLabel(AppLanguage language, AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.normal => tr(language, 'Normal', 'طبيعي'),
    AlertSeverity.wheeze => tr(language, 'Wheeze', 'أزيز'),
    AlertSeverity.emergency => tr(language, 'Emergency', 'طارئ'),
  };
}

Color severityColor(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.normal => AppColors.success,
    AlertSeverity.wheeze => AppColors.warning,
    AlertSeverity.emergency => AppColors.danger,
  };
}

@immutable
class WeeklyMetric {
  const WeeklyMetric({
    required this.labelEn,
    required this.labelAr,
    required this.wheezeCount,
    required this.spo2,
  });

  final String labelEn;
  final String labelAr;
  final int wheezeCount;
  final double spo2;
}

@immutable
class SmartDevice {
  const SmartDevice({
    required this.nameEn,
    required this.nameAr,
    required this.reasonEn,
    required this.reasonAr,
    required this.iconCodePoint,
    required this.isOn,
  });

  final String nameEn;
  final String nameAr;
  final String reasonEn;
  final String reasonAr;
  final int iconCodePoint;
  final bool isOn;
}

@immutable
class ChatMessage {
  const ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

final Provider<LocalStorage> localStorageProvider = Provider<LocalStorage>((
  Ref ref,
) {
  throw UnimplementedError('LocalStorage must be overridden in ProviderScope');
});

final Provider<ApiConfig> apiConfigProvider = Provider<ApiConfig>((Ref ref) {
  return ApiConfig.fromEnvironment();
});

final Provider<AuthSessionService> authSessionServiceProvider =
    Provider<AuthSessionService>((Ref ref) {
      return AuthSessionService(FirebaseAuth.instance);
    });

final Provider<DeviceApiService> deviceApiServiceProvider =
    Provider<DeviceApiService>((Ref ref) {
      return DeviceApiService(
        config: ref.watch(apiConfigProvider),
        authSessionService: ref.watch(authSessionServiceProvider),
      );
    });

final Provider<LiveStreamService> liveStreamServiceProvider =
    Provider<LiveStreamService>((Ref ref) {
      return LiveStreamService(
        config: ref.watch(apiConfigProvider),
        authSessionService: ref.watch(authSessionServiceProvider),
      );
    });

final Provider<GeminiService> geminiServiceProvider = Provider<GeminiService>((
  Ref ref,
) {
  return GeminiService();
});

class WaveMedAppState extends ChangeNotifier {
  WaveMedAppState(this._localStorage, this._authSessionService) {
    _language = _localStorage.languageCode == 'ar'
        ? AppLanguage.ar
        : AppLanguage.en;
    _completedOnboarding = _localStorage.completedOnboarding;
    _notificationsEnabled = _localStorage.notificationsEnabled;
    _offlineInferenceEnabled = _localStorage.offlineInferenceEnabled;
    _selectedChildId = _localStorage.selectedChildId;
    _userEmail = _localStorage.userEmail;
    _authenticated = _localStorage.authenticated;
    _authSubscription = _authSessionService.sessionChanges().listen((
      AuthSession? session,
    ) {
      _authenticated = session != null;
      _userEmail = session?.email ?? '';
      unawaited(_localStorage.setAuthenticated(_authenticated));
      unawaited(_localStorage.setUserEmail(_userEmail));
      notifyListeners();
    });
  }

  final LocalStorage _localStorage;
  final AuthSessionService _authSessionService;
  StreamSubscription<AuthSession?>? _authSubscription;

  AppLanguage _language = AppLanguage.en;
  bool _completedOnboarding = false;
  bool _authenticated = false;
  bool _notificationsEnabled = true;
  bool _offlineInferenceEnabled = true;
  String _selectedChildId = '';
  String _userEmail = '';
  final Set<String> _locallyAcknowledgedAlertIds = <String>{};

  AppLanguage get language => _language;
  bool get completedOnboarding => _completedOnboarding;
  bool get authenticated => _authenticated;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get offlineInferenceEnabled => _offlineInferenceEnabled;
  String get selectedChildId => _selectedChildId;
  String get userEmail => _userEmail;
  Set<String> get locallyAcknowledgedAlertIds =>
      Set<String>.unmodifiable(_locallyAcknowledgedAlertIds);

  void setLanguage(AppLanguage language) {
    _language = language;
    unawaited(
      _localStorage.setLanguageCode(language == AppLanguage.ar ? 'ar' : 'en'),
    );
    notifyListeners();
  }

  void completeOnboarding() {
    _completedOnboarding = true;
    unawaited(_localStorage.setCompletedOnboarding(true));
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
    required bool registerMode,
  }) async {
    await _authSessionService.signIn(
      email: email,
      password: password,
      registerMode: registerMode,
    );
  }

  Future<void> signInWithGoogle() {
    return _authSessionService.signInWithGoogle();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _authSessionService.sendPasswordResetEmail(email);
  }

  Future<void> signOut() async {
    _locallyAcknowledgedAlertIds.clear();
    await _authSessionService.signOut();
  }

  void selectChild(String childId) {
    _selectedChildId = childId;
    unawaited(_localStorage.setSelectedChildId(childId));
    notifyListeners();
  }

  void acknowledgeEmergency(String alertId) {
    _locallyAcknowledgedAlertIds.add(alertId);
    notifyListeners();
  }

  void clearAcknowledgement(String alertId) {
    _locallyAcknowledgedAlertIds.remove(alertId);
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    unawaited(_localStorage.setNotificationsEnabled(value));
    notifyListeners();
  }

  void setOfflineInferenceEnabled(bool value) {
    _offlineInferenceEnabled = value;
    unawaited(_localStorage.setOfflineInferenceEnabled(value));
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final ChangeNotifierProvider<WaveMedAppState> appStateProvider =
    ChangeNotifierProvider<WaveMedAppState>(
      (Ref ref) => WaveMedAppState(
        ref.watch(localStorageProvider),
        ref.watch(authSessionServiceProvider),
      ),
    );

final FutureProvider<List<ChildSummary>> childrenProvider =
    FutureProvider<List<ChildSummary>>((Ref ref) async {
      final List<ChildSummary> children = await ref
          .read(deviceApiServiceProvider)
          .fetchChildren();
      final WaveMedAppState appState = ref.read(appStateProvider);
      if (children.isNotEmpty &&
          !children.any((ChildSummary child) => child.id == appState.selectedChildId)) {
        appState.selectChild(children.first.id);
      }
      return children;
    });

final Provider<String?> activeChildIdProvider = Provider<String?>((Ref ref) {
  final String selectedChildId = ref.watch(
    appStateProvider.select((WaveMedAppState state) => state.selectedChildId),
  );
  if (selectedChildId.isNotEmpty) {
    return selectedChildId;
  }
  final AsyncValue<List<ChildSummary>> children = ref.watch(childrenProvider);
  return children.valueOrNull?.isNotEmpty == true
      ? children.valueOrNull!.first.id
      : null;
});

final Provider<ChildSummary?> activeChildProvider = Provider<ChildSummary?>((
  Ref ref,
) {
  final String? activeChildId = ref.watch(activeChildIdProvider);
  final List<ChildSummary>? children = ref.watch(childrenProvider).valueOrNull;
  if (activeChildId == null || children == null || children.isEmpty) {
    return null;
  }
  for (final ChildSummary child in children) {
    if (child.id == activeChildId) {
      return child;
    }
  }
  return children.first;
});

class ChildSessionController extends FamilyAsyncNotifier<ChildSessionState, String> {
  StreamSubscription<LiveStreamEnvelope>? _streamSubscription;

  @override
  Future<ChildSessionState> build(String childId) async {
    final DeviceApiService api = ref.read(deviceApiServiceProvider);
    final List<ChildSummary> children = await ref.watch(childrenProvider.future);
    final ChildSummary child = children.firstWhere(
      (ChildSummary item) => item.id == childId,
      orElse: () => children.first,
    );
    final Future<LiveMonitorFrame> latestFuture = api.fetchLatest(childId);
    final Future<List<AlertEvent>> alertsFuture = api.fetchAlerts(childId);
    final LiveMonitorFrame frame = await latestFuture;
    final List<AlertEvent> alerts = await alertsFuture;
    final SetupStatus setupStatus = _buildSetupStatus(
      child,
      ref.read(apiConfigProvider),
    );

    _streamSubscription?.cancel();
    _streamSubscription = ref
        .read(liveStreamServiceProvider)
        .watchChild(childId)
        .listen(_applyEnvelope);
    ref.onDispose(() {
      _streamSubscription?.cancel();
    });

    return ChildSessionState(
      child: child,
      frame: frame,
      alerts: alerts,
      connection: ConnectionHealth.connected,
      setupStatus: setupStatus,
    );
  }

  void _applyEnvelope(LiveStreamEnvelope envelope) {
    final ChildSessionState? current = state.valueOrNull;
    if (current == null) {
      return;
    }

    ChildSessionState next = current.copyWith(connection: envelope.connection);
    if (envelope.frame != null) {
      next = next.copyWith(frame: envelope.frame);
    }
    if (envelope.alert != null) {
      final List<AlertEvent> alerts = <AlertEvent>[
        envelope.alert!,
        ...current.alerts.where(
          (AlertEvent alert) => alert.id != envelope.alert!.id,
        ),
      ];
      next = next.copyWith(alerts: alerts);
    }
    state = AsyncData(next);
  }
}

final AsyncNotifierProviderFamily<
  ChildSessionController,
  ChildSessionState,
  String
>
childSessionProvider = AsyncNotifierProviderFamily<
  ChildSessionController,
  ChildSessionState,
  String
>(ChildSessionController.new);

final Provider<AsyncValue<ChildSessionState>?> activeChildSessionProvider =
    Provider<AsyncValue<ChildSessionState>?>((Ref ref) {
      final String? childId = ref.watch(activeChildIdProvider);
      if (childId == null) {
        return null;
      }
      return ref.watch(childSessionProvider(childId));
    });

@immutable
class AlertLookup {
  const AlertLookup({required this.childId, required this.alertId});

  final String childId;
  final String alertId;
}

final alertDetailProvider = FutureProvider.family<AlertEvent, AlertLookup>((
  Ref ref,
  AlertLookup lookup,
) {
  return ref
      .read(deviceApiServiceProvider)
      .fetchAlertDetail(lookup.childId, lookup.alertId);
});

final Provider<List<WeeklyMetric>> secondaryMetricsProvider =
    Provider<List<WeeklyMetric>>((Ref ref) {
      final AppLanguage language = ref.watch(
        appStateProvider.select((WaveMedAppState state) => state.language),
      );
      return MockLiveDataStore.weeklyMetrics(language);
    });

final Provider<List<SmartDevice>> smartDevicesProvider =
    Provider<List<SmartDevice>>((Ref ref) {
      return MockLiveDataStore.smartDevices();
    });

class AssistantChatController extends AsyncNotifier<List<ChatMessage>> {
  @override
  Future<List<ChatMessage>> build() async {
    return MockLiveDataStore.assistantMessages();
  }

  Future<void> send(String message) async {
    final String trimmed = message.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final List<ChatMessage> current = state.valueOrNull ?? <ChatMessage>[];
    final List<ChatMessage> pending = <ChatMessage>[
      ...current,
      ChatMessage(text: trimmed, isUser: true),
    ];
    state = AsyncData(pending);
    try {
      final AppLanguage language = ref.read(appStateProvider).language;
      final String reply = await ref.read(geminiServiceProvider).send(
        language: language,
        child: ref.read(activeChildProvider),
        session: ref.read(activeChildSessionProvider)?.valueOrNull,
        history: current,
        message: trimmed,
      );
      state = AsyncData(<ChatMessage>[
        ...pending,
        ChatMessage(text: reply, isUser: false),
      ]);
    } catch (error) {
      final AppLanguage language = ref.read(appStateProvider).language;
      state = AsyncData(<ChatMessage>[
        ...pending,
        ChatMessage(
          text: error is GeminiConfigurationException
              ? tr(
                  language,
                  'Gemini is not configured yet. Add your key to .env as GEMINI_API_KEY.',
                  'لم يتم إعداد Gemini بعد. أضف المفتاح في .env باسم GEMINI_API_KEY.',
                )
              : tr(
                  language,
                  'I could not reach Gemini right now. Try again in a moment.',
                  'تعذر الاتصال بـ Gemini حالياً. حاول مرة أخرى بعد قليل.',
                ),
          isUser: false,
        ),
      ]);
    }
  }
}

final AsyncNotifierProvider<AssistantChatController, List<ChatMessage>>
assistantMessagesProvider =
    AsyncNotifierProvider<AssistantChatController, List<ChatMessage>>(
      AssistantChatController.new,
    );

SetupStatus _buildSetupStatus(ChildSummary child, ApiConfig config) {
  if (config.useMockBackend) {
    return MockLiveDataStore.setupStatus(child.id);
  }
  return SetupStatus(
    child: child,
    bleProvisioningEnabled: false,
    steps: <SetupStepStatus>[
      const SetupStepStatus(
        titleEn: 'Child profile',
        titleAr: 'ملف الطفل',
        descriptionEn: 'Child profile exists in the backend workspace.',
        descriptionAr: 'ملف الطفل موجود في مساحة العمل على الخادم.',
        state: SetupStepState.completed,
      ),
      SetupStepStatus(
        titleEn: 'Device assignment',
        titleAr: 'ربط الجهاز',
        descriptionEn: child.hasAssignedDevice
            ? 'Device ${child.deviceId} is registered.'
            : 'No device is assigned yet.',
        descriptionAr: child.hasAssignedDevice
            ? 'الجهاز ${child.deviceId} مسجل.'
            : 'لا يوجد جهاز مرتبط حتى الآن.',
        state: child.hasAssignedDevice
            ? SetupStepState.completed
            : SetupStepState.pending,
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
