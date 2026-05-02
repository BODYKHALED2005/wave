import 'package:hive_flutter/hive_flutter.dart';

class LocalStorage {
  LocalStorage._({Box<dynamic>? box, Map<String, Object?>? memory})
    : _box = box,
      _memory = memory;

  static const String _boxName = 'wavemed_prefs';
  static const String _completedOnboardingKey = 'completed_onboarding';
  static const String _authenticatedKey = 'authenticated';
  static const String _languageKey = 'language';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _offlineInferenceEnabledKey = 'offline_inference_enabled';
  static const String _selectedChildKey = 'selected_child';
  static const String _selectedChildIdKey = 'selected_child_id';
  static const String _userEmailKey = 'user_email';

  final Box<dynamic>? _box;
  final Map<String, Object?>? _memory;

  static Future<LocalStorage> init() async {
    await Hive.initFlutter();
    final Box<dynamic> box = await Hive.openBox<dynamic>(_boxName);
    return LocalStorage._(box: box);
  }

  factory LocalStorage.memory() {
    return LocalStorage._(memory: <String, Object?>{});
  }

  bool get completedOnboarding =>
      _read(_completedOnboardingKey, fallback: false);

  bool get authenticated => _read(_authenticatedKey, fallback: false);

  String get languageCode => _read(_languageKey, fallback: 'en');

  bool get notificationsEnabled =>
      _read(_notificationsEnabledKey, fallback: true);

  bool get offlineInferenceEnabled =>
      _read(_offlineInferenceEnabledKey, fallback: true);

  int get selectedChildIndex => _read(_selectedChildKey, fallback: 0);

  String get selectedChildId => _read(_selectedChildIdKey, fallback: '');

  String get userEmail => _read(_userEmailKey, fallback: '');

  Future<void> setCompletedOnboarding(bool value) {
    return _write(_completedOnboardingKey, value);
  }

  Future<void> setAuthenticated(bool value) {
    return _write(_authenticatedKey, value);
  }

  Future<void> setLanguageCode(String value) {
    return _write(_languageKey, value);
  }

  Future<void> setNotificationsEnabled(bool value) {
    return _write(_notificationsEnabledKey, value);
  }

  Future<void> setOfflineInferenceEnabled(bool value) {
    return _write(_offlineInferenceEnabledKey, value);
  }

  Future<void> setSelectedChildIndex(int value) {
    return _write(_selectedChildKey, value);
  }

  Future<void> setSelectedChildId(String value) {
    return _write(_selectedChildIdKey, value);
  }

  Future<void> setUserEmail(String value) {
    return _write(_userEmailKey, value);
  }

  T _read<T>(String key, {required T fallback}) {
    if (_box != null) {
      return (_box.get(key) as T?) ?? fallback;
    }
    return (_memory![key] as T?) ?? fallback;
  }

  Future<void> _write(String key, Object? value) async {
    if (_box != null) {
      await _box.put(key, value);
      return;
    }
    _memory![key] = value;
  }
}
