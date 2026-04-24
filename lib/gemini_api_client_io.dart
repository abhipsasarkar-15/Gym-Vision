import 'dart:convert';
import 'dart:io';

import 'gemini_api_client.dart';

class _IoGeminiApiClient implements GeminiApiClient {
  final HttpClient _httpClient = HttpClient();

  @override
  Future<String?> generateWorkoutCue(GeminiCoachingRequest request) async {
    if (request.apiKey.isEmpty) {
      return null;
    }

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${request.model}:generateContent',
    );
    final HttpClientRequest httpRequest = await _httpClient.postUrl(uri);
    httpRequest.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    httpRequest.headers.set('x-goog-api-key', request.apiKey);

    final String cuesText = request.cues
        .map((cue) => '${cue['label']}: ${cue['state']}')
        .join(', ');

    final Map<String, Object> payload = <String, Object>{
      'system_instruction': <String, Object>{
        'parts': <Map<String, String>>[
          <String, String>{
            'text':
                'You are Cult Eidos, a real-time deadlift coach delivering short spoken cues during a live set. Return one short spoken coaching line only. Keep it under 10 words. Be crisp, clear, actionable, and safe. Prefer simple gym-floor language. No emojis. No explanations. No prefixes. If the athlete is doing well, use a short reinforcing cue instead of praise-heavy copy.',
          },
        ],
      },
      'contents': <Map<String, Object>>[
        <String, Object>{
          'role': 'user',
          'parts': <Map<String, String>>[
            <String, String>{
              'text':
                  'Exercise: ${request.exerciseName}. Rep count: ${request.repCount}. Pose confidence: ${request.poseConfidence.toStringAsFixed(2)}. Active focus: ${request.activeCueTitle}. Command: ${request.activeCommand}. Detail: ${request.activeDetail}. Cue states: $cuesText. Return the single best short voice cue for this moment.',
            },
          ],
        },
      ],
      'generationConfig': <String, Object>{
        'temperature': 0.3,
        'thinkingConfig': <String, int>{'thinkingBudget': 0},
        'maxOutputTokens': 24,
      },
    };

    httpRequest.write(jsonEncode(payload));
    final HttpClientResponse response = await httpRequest.close();
    final String body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final dynamic decoded = jsonDecode(body);
    final List<dynamic>? candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return null;
    }
    final dynamic content = candidates.first['content'];
    final List<dynamic>? parts = content['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      return null;
    }
    final String? text = parts.first['text'] as String?;
    return text?.trim();
  }
}

GeminiApiClient createGeminiApiClient() => _IoGeminiApiClient();
