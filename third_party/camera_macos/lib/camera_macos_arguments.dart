import 'dart:typed_data';

import 'package:camera_macos/camera_macos_device.dart';
import 'package:flutter/material.dart';

enum PictureFormat { jpg, jpeg, tiff, bmp, png, raw }

enum VideoFormat { m4v, mov, mp4 }

enum Torch { on, off, auto }

enum CameraMacOSMode { photo, video }

enum AudioQuality { min, low, medium, high, max }

enum AudioFormat {
  kAudioFormat60958AC3,
  kAudioFormatAC3,
  kAudioFormatAES3,
  kAudioFormatALaw,
  kAudioFormatAMR,
  kAudioFormatAMR_WB,
  kAudioFormatAppleIMA4,
  kAudioFormatAppleLossless,
  kAudioFormatAudible,
  kAudioFormatDVIIntelIMA,
  kAudioFormatEnhancedAC3,
  kAudioFormatFLAC,
  kAudioFormatLinearPCM,
  kAudioFormatMACE3,
  kAudioFormatMACE6,
  kAudioFormatMIDIStream,
  kAudioFormatMPEG4AAC,
  kAudioFormatMPEG4AAC_ELD,
  kAudioFormatMPEG4AAC_ELD_SBR,
  kAudioFormatMPEG4AAC_ELD_V2,
  kAudioFormatMPEG4AAC_HE,
  kAudioFormatMPEG4AAC_HE_V2,
  kAudioFormatMPEG4AAC_LD,
  kAudioFormatMPEG4AAC_Spatial,
  kAudioFormatMPEG4CELP,
  kAudioFormatMPEG4HVXC,
  kAudioFormatMPEG4TwinVQ,
  kAudioFormatMPEGD_USAC,
  kAudioFormatMPEGLayer1,
  kAudioFormatMPEGLayer2,
  kAudioFormatMPEGLayer3,
  kAudioFormatMicrosoftGSM,
  kAudioFormatOpus,
  kAudioFormatParameterValueStream,
  kAudioFormatQDesign,
  kAudioFormatQDesign2,
  kAudioFormatQUALCOMM,
  kAudioFormatTimeCode,
  kAudioFormatULaw,
  kAudioFormatiLBC,
}

enum PictureResolution {
  /// 480p (640x480)
  low,

  /// 540p (960x540)
  medium,

  /// 720p (1280x720)
  high,

  /// 1080p (1920x1080)
  veryHigh,

  /// 2160p (3840x2160)
  ultraHigh,

  /// The highest resolution available.
  max,
}

/// The camera orientation angle to be specified
enum CameraOrientation {
  orientation0deg,
  orientation90deg,
  orientation180deg,
  orientation270deg
}

//double get getMaxZoomLevel =>

class CameraImageData {
  CameraImageData(
      {required this.width,
      required this.height,
      required this.bytesPerRow,
      required this.bytes});

  final int width;
  final int height;
  final int bytesPerRow;
  final Uint8List bytes;

  @override
  String toString() {
    return {'width': width, 'height': height, 'bytesPerRow': bytesPerRow}
        .toString();
  }
}

class CameraPoseLandmark {
  CameraPoseLandmark({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
    required this.presence,
  });

  factory CameraPoseLandmark.fromMap(Map<dynamic, dynamic> map) {
    return CameraPoseLandmark(
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      z: (map['z'] as num?)?.toDouble() ?? 0,
      visibility: (map['visibility'] as num?)?.toDouble() ?? 0,
      presence: (map['presence'] as num?)?.toDouble() ?? 0,
    );
  }

  final double x;
  final double y;
  final double z;
  final double visibility;
  final double presence;
}

class CameraPoseResult {
  CameraPoseResult({
    required this.timestampMs,
    required this.overallConfidence,
    required this.landmarks,
    required this.worldLandmarks,
  });

  factory CameraPoseResult.fromMap(Map<dynamic, dynamic> map) {
    List<CameraPoseLandmark> parseLandmarks(String key) {
      final List<dynamic> values = (map[key] as List<dynamic>?) ?? const <dynamic>[];
      return values
          .whereType<Map<dynamic, dynamic>>()
          .map(CameraPoseLandmark.fromMap)
          .toList();
    }

    return CameraPoseResult(
      timestampMs: (map['timestampMs'] as num?)?.toInt() ?? 0,
      overallConfidence: (map['overallConfidence'] as num?)?.toDouble() ?? 0,
      landmarks: parseLandmarks('landmarks'),
      worldLandmarks: parseLandmarks('worldLandmarks'),
    );
  }

  final int timestampMs;
  final double overallConfidence;
  final List<CameraPoseLandmark> landmarks;
  final List<CameraPoseLandmark> worldLandmarks;

  bool get hasPose => landmarks.isNotEmpty;
}

class CameraMacOSArguments {
  /// The texture id.
  final int? textureId;

  /// Size of the texture.
  final Size size;

  /// Chosen device
  final List<CameraMacOSDevice>? devices;

  /// Create a [CameraMacOSArguments].
  CameraMacOSArguments({
    this.textureId,
    required this.size,
    this.devices,
  });
}
