import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../features/app_state/app_state.dart';
import '../features/live_data/live_models.dart';

class GeminiService {
  GeminiService({http.Client? client, String? apiKey, String? model})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? dotenv.env['GEMINI_API_KEY'] ?? '',
      _model = model ?? dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash';

  final http.Client _client;
  final String _apiKey;
  final String _model;

  bool get isConfigured => _apiKey.trim().isNotEmpty;

  Future<String> send({
    required AppLanguage language,
    required ChildSummary? child,
    required ChildSessionState? session,
    required List<ChatMessage> history,
    required String message,
  }) async {
    if (!isConfigured) {
      throw const GeminiConfigurationException();
    }

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
    );
    final http.Response response = await _client.post(
      uri,
      headers: const <String, String>{'content-type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'systemInstruction': <String, dynamic>{
          'parts': <Map<String, String>>[
            <String, String>{'text': _systemPrompt(language, child, session)},
          ],
        },
        'contents': <Map<String, dynamic>>[
          for (final ChatMessage item in history.take(12))
            <String, dynamic>{
              'role': item.isUser ? 'user' : 'model',
              'parts': <Map<String, String>>[
                <String, String>{'text': item.text},
              ],
            },
          <String, dynamic>{
            'role': 'user',
            'parts': <Map<String, String>>[
              <String, String>{'text': message},
            ],
          },
        ],
        'generationConfig': <String, dynamic>{
          'temperature': 0.35,
          'topP': 0.9,
          'maxOutputTokens': 700,
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GeminiRequestException(response.statusCode, response.body);
    }

    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> candidates =
        payload['candidates'] as List<dynamic>? ?? <dynamic>[];
    if (candidates.isEmpty) {
      return language == AppLanguage.ar
          ? 'لم أستطع إنشاء رد الآن. حاول مرة أخرى.'
          : 'I could not generate a reply right now. Try again.';
    }
    final Map<String, dynamic> content =
        candidates.first['content'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final List<dynamic> parts = content['parts'] as List<dynamic>? ?? <dynamic>[];
    return parts
        .map((dynamic part) => (part as Map<String, dynamic>)['text'] as String? ?? '')
        .where((String text) => text.trim().isNotEmpty)
        .join('\n')
        .trim();
  }

  String _systemPrompt(
    AppLanguage language,
    ChildSummary? child,
    ChildSessionState? session,
  ) {
    final LiveMonitorFrame? frame = session?.frame;
    final List<AlertEvent> alerts = session?.alerts.take(3).toList() ?? <AlertEvent>[];
    return '''
You are WaveMed's pediatric respiratory health assistant.
Reply in ${language == AppLanguage.ar ? 'Arabic' : 'English'}.
You help parents understand monitoring data in simple language.
Never diagnose, never replace a doctor, and clearly recommend urgent care for severe breathing difficulty, blue lips, confusion, or very low oxygen.

Child:
- Name: ${child?.name ?? 'Unknown'}
- Age: ${child?.ageLabel ?? 'Unknown'}
- Device: ${child?.deviceId ?? 'Unknown'}

Current live status:
- Severity: ${frame == null ? 'unknown' : frame.status.name}
- SpO2: ${frame?.vitals.spo2 ?? 'unknown'}
- BPM: ${frame?.vitals.bpm ?? 'unknown'}
- Temperature C: ${frame?.vitals.temperatureC.toStringAsFixed(1) ?? 'unknown'}
- Backend confidence: ${frame == null ? 'unknown' : (frame.comparison.backend.confidence * 100).round()}
- Device confidence: ${frame?.comparison.device == null ? 'unavailable' : (frame!.comparison.device!.confidence * 100).round()}
- Model mismatch: ${frame?.comparison.isMismatch ?? false}

Recent alerts:
${alerts.map((AlertEvent alert) => '- ${alert.titleEn}: ${alert.bodyEn}').join('\n')}
''';
  }
}

class GeminiConfigurationException implements Exception {
  const GeminiConfigurationException();
}

class GeminiRequestException implements Exception {
  const GeminiRequestException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'GeminiRequestException($statusCode, $body)';
}
