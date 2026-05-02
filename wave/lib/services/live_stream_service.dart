import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../features/live_data/live_models.dart';
import 'api_config.dart';
import 'auth_session_service.dart';
import 'mock_live_data.dart';

class LiveStreamService {
  LiveStreamService({
    required ApiConfig config,
    required AuthSessionService authSessionService,
  }) : _config = config,
       _authSessionService = authSessionService;

  final ApiConfig _config;
  final AuthSessionService _authSessionService;

  Stream<LiveStreamEnvelope> watchChild(String childId) {
    if (_config.useMockBackend) {
      return _watchMock(childId);
    }
    return _watchWebSocket(childId);
  }

  Stream<LiveStreamEnvelope> _watchMock(String childId) async* {
    yield const LiveStreamEnvelope(connection: ConnectionHealth.connected);
    for (int tick = 0; ; tick++) {
      await Future<void>.delayed(const Duration(seconds: 4));
      yield await MockLiveDataStore.nextEnvelope(childId, tick);
    }
  }

  Stream<LiveStreamEnvelope> _watchWebSocket(String childId) async* {
    Duration backoff = const Duration(seconds: 2);
    while (true) {
      yield const LiveStreamEnvelope(connection: ConnectionHealth.connecting);
      WebSocketChannel? channel;
      try {
        final String? idToken = await _authSessionService.getFreshIdToken();
        final Uri uri = Uri.parse('${_config.wsBaseUrl}/ws/children/$childId');
        channel = WebSocketChannel.connect(uri);
        channel.sink.add(
          jsonEncode(<String, dynamic>{
            'type': 'auth',
            'token': idToken,
            'child_id': childId,
          }),
        );
        yield const LiveStreamEnvelope(connection: ConnectionHealth.connected);
        await for (final dynamic raw in channel.stream) {
          final Map<String, dynamic> json =
              jsonDecode(raw as String) as Map<String, dynamic>;
          final String type = (json['type'] as String? ?? 'scan_result')
              .toLowerCase();
          if (type == 'alert') {
            yield LiveStreamEnvelope(
              alert: AlertEvent.fromJson(json),
              connection: ConnectionHealth.connected,
            );
            continue;
          }
          yield LiveStreamEnvelope(
            frame: LiveMonitorFrame.fromJson(json),
            connection: ConnectionHealth.connected,
          );
        }
      } catch (_) {
        yield const LiveStreamEnvelope(connection: ConnectionHealth.degraded);
        await Future<void>.delayed(backoff);
        backoff = Duration(
          seconds: (backoff.inSeconds * 2).clamp(2, 30),
        );
      } finally {
        await channel?.sink.close();
      }
    }
  }
}
