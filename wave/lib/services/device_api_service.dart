import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/live_data/live_models.dart';
import 'api_config.dart';
import 'auth_session_service.dart';
import 'mock_live_data.dart';

class DeviceApiService {
  DeviceApiService({
    required ApiConfig config,
    required AuthSessionService authSessionService,
    http.Client? client,
  }) : _config = config,
       _authSessionService = authSessionService,
       _client = client ?? http.Client();

  final ApiConfig _config;
  final AuthSessionService _authSessionService;
  final http.Client _client;

  Future<List<ChildSummary>> fetchChildren() async {
    if (_config.useMockBackend) {
      return MockLiveDataStore.children();
    }

    final http.Response response = await _get('/api/v1/children');
    final List<dynamic> payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((dynamic item) => ChildSummary.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<AlertEvent>> fetchAlerts(
    String childId, {
    int page = 1,
    int limit = 20,
  }) async {
    if (_config.useMockBackend) {
      return MockLiveDataStore.alerts(childId);
    }

    final http.Response response = await _get(
      '/api/v1/children/$childId/alerts?page=$page&limit=$limit',
    );
    final List<dynamic> payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((dynamic item) => AlertEvent.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<AlertEvent> fetchAlertDetail(String childId, String alertId) async {
    if (_config.useMockBackend) {
      return MockLiveDataStore.alertDetail(childId, alertId);
    }

    final http.Response response = await _get(
      '/api/v1/children/$childId/alerts/$alertId',
    );
    return AlertEvent.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<LiveMonitorFrame> fetchLatest(String childId) async {
    if (_config.useMockBackend) {
      return MockLiveDataStore.latestFrame(childId);
    }

    final http.Response response = await _get('/api/v1/children/$childId/latest');
    return LiveMonitorFrame.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SetupStatus> assignDevice(DeviceAssignment assignment) async {
    if (_config.useMockBackend) {
      return MockLiveDataStore.setupStatus(assignment.childId);
    }

    final http.Response response = await _post(
      '/api/v1/devices/assign',
      assignment.toJson(),
    );
    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final ChildSummary child = ChildSummary.fromJson(
      payload['child'] as Map<String, dynamic>? ??
          <String, dynamic>{
            'id': assignment.childId,
            'name': 'Configured child',
            'age_label': '-',
            'device_id': assignment.deviceId,
            'has_assigned_device': true,
          },
    );
    final bool bleProvisioningEnabled =
        payload['ble_provisioning_enabled'] as bool? ?? false;
    final List<dynamic> rawSteps = payload['steps'] as List<dynamic>? ?? <dynamic>[];
    return SetupStatus(
      child: child,
      bleProvisioningEnabled: bleProvisioningEnabled,
      steps: rawSteps.map((dynamic rawStep) {
        final Map<String, dynamic> step = rawStep as Map<String, dynamic>;
        return SetupStepStatus(
          titleEn: step['title_en'] as String? ?? 'Step',
          titleAr: step['title_ar'] as String? ?? 'خطوة',
          descriptionEn: step['description_en'] as String? ?? '',
          descriptionAr: step['description_ar'] as String? ?? '',
          state: switch ((step['state'] as String? ?? '').toLowerCase()) {
            'completed' => SetupStepState.completed,
            'blocked' => SetupStepState.blocked,
            _ => SetupStepState.pending,
          },
        );
      }).toList(growable: false),
    );
  }

  Future<http.Response> _get(String path) async {
    final String? idToken = await _authSessionService.getFreshIdToken();
    final http.Response response = await _client.get(
      Uri.parse('${_config.httpBaseUrl}$path'),
      headers: _headers(idToken),
    );
    _ensureSuccess(response);
    return response;
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final String? idToken = await _authSessionService.getFreshIdToken();
    final http.Response response = await _client.post(
      Uri.parse('${_config.httpBaseUrl}$path'),
      headers: _headers(idToken),
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
    return response;
  }

  Map<String, String> _headers(String? idToken) {
    return <String, String>{
      'content-type': 'application/json',
      if (idToken != null && idToken.isNotEmpty) 'authorization': 'Bearer $idToken',
    };
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw DeviceApiException(
      'Request failed with status ${response.statusCode}: ${response.body}',
    );
  }
}

class DeviceApiException implements Exception {
  DeviceApiException(this.message);

  final String message;

  @override
  String toString() => 'DeviceApiException($message)';
}
