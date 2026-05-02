import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  const ApiConfig({
    required this.httpBaseUrl,
    required this.wsBaseUrl,
    required this.useMockBackend,
  });

  factory ApiConfig.fromEnvironment() {
    final String httpFromDefine = const String.fromEnvironment(
      'WAVEMED_API_BASE_URL',
      defaultValue: '',
    );
    final String wsFromDefine = const String.fromEnvironment(
      'WAVEMED_WS_BASE_URL',
      defaultValue: '',
    );
    final bool explicitMockFromDefine = const bool.fromEnvironment(
      'WAVEMED_USE_MOCK_BACKEND',
      defaultValue: false,
    );
    final String httpFromEnv = dotenv.env['WAVEMED_API_BASE_URL'] ?? '';
    final String wsFromEnv = dotenv.env['WAVEMED_WS_BASE_URL'] ?? '';
    final String mockFromEnv = (dotenv.env['WAVEMED_USE_MOCK_BACKEND'] ?? '')
        .trim()
        .toLowerCase();

    final String httpBaseUrl = httpFromDefine.isNotEmpty
        ? httpFromDefine
        : httpFromEnv;
    final String wsBaseUrl = wsFromDefine.isNotEmpty ? wsFromDefine : wsFromEnv;
    final bool explicitMock = explicitMockFromDefine ||
        mockFromEnv == '1' ||
        mockFromEnv == 'true' ||
        mockFromEnv == 'yes';

    return ApiConfig(
      httpBaseUrl: httpBaseUrl,
      wsBaseUrl: wsBaseUrl,
      useMockBackend: explicitMock || httpBaseUrl.isEmpty || wsBaseUrl.isEmpty,
    );
  }

  final String httpBaseUrl;
  final String wsBaseUrl;
  final bool useMockBackend;
}
