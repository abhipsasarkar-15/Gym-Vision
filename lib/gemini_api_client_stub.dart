import 'gemini_api_client.dart';

class _StubGeminiApiClient implements GeminiApiClient {
  @override
  Future<String?> generateWorkoutCue(GeminiCoachingRequest request) async {
    return null;
  }
}

GeminiApiClient createGeminiApiClient() => _StubGeminiApiClient();
