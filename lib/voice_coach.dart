import 'dart:async';

import 'package:flutter/services.dart';

import 'gemini_api_client.dart';

class VoiceCoachController {
  VoiceCoachController({
    required String apiKey,
    required String model,
  })  : _apiKey = apiKey,
        _model = model;

  static const MethodChannel _voiceChannel = MethodChannel('cult_vision_voice');

  final String _apiKey;
  final String _model;
  final GeminiApiClient _client = createGeminiApiClient();

  DateTime? _lastRequestAt;
  String? _lastSpokenLine;
  bool _requestInFlight = false;

  Future<void> maybeSpeak({
    required bool enabled,
    required String exerciseName,
    required int repCount,
    required double poseConfidence,
    required String activeCueTitle,
    required String activeCommand,
    required String activeDetail,
    required List<Map<String, String>> cues,
    Duration minGap = const Duration(seconds: 4),
  }) async {
    if (!enabled || _apiKey.isEmpty || _requestInFlight) {
      return;
    }
    final DateTime now = DateTime.now();
    if (_lastRequestAt != null && now.difference(_lastRequestAt!) < minGap) {
      return;
    }

    _requestInFlight = true;
    _lastRequestAt = now;
    try {
      final String? line = await _client.generateWorkoutCue(
        GeminiCoachingRequest(
          model: _model,
          apiKey: _apiKey,
          exerciseName: exerciseName,
          repCount: repCount,
          poseConfidence: poseConfidence,
          activeCueTitle: activeCueTitle,
          activeCommand: activeCommand,
          activeDetail: activeDetail,
          cues: cues,
        ),
      );
      if (line == null || line.isEmpty || line == _lastSpokenLine) {
        return;
      }
      _lastSpokenLine = line;
      await _voiceChannel.invokeMethod<void>('speakText', <String, Object>{
        'text': line,
      });
    } catch (_) {
      // Fails soft so coaching UI remains responsive.
    } finally {
      _requestInFlight = false;
    }
  }

  Future<void> stop() async {
    try {
      await _voiceChannel.invokeMethod<void>('stopSpeaking');
    } catch (_) {}
  }
}
