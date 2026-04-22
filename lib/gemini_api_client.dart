import 'gemini_api_client_stub.dart'
    if (dart.library.io) 'gemini_api_client_io.dart' as impl;

class GeminiCoachingRequest {
  GeminiCoachingRequest({
    required this.model,
    required this.apiKey,
    required this.exerciseName,
    required this.repCount,
    required this.poseConfidence,
    required this.activeCueTitle,
    required this.activeCommand,
    required this.activeDetail,
    required this.cues,
  });

  final String model;
  final String apiKey;
  final String exerciseName;
  final int repCount;
  final double poseConfidence;
  final String activeCueTitle;
  final String activeCommand;
  final String activeDetail;
  final List<Map<String, String>> cues;
}

abstract class GeminiApiClient {
  Future<String?> generateWorkoutCue(GeminiCoachingRequest request);
}

GeminiApiClient createGeminiApiClient() => impl.createGeminiApiClient();
