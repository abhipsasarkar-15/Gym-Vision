import Cocoa
import AVFoundation
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let voiceSynth = AVSpeechSynthesizer()

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      super.applicationDidFinishLaunching(notification)
      return
    }

    let voiceChannel = FlutterMethodChannel(
      name: "cult_vision_voice",
      binaryMessenger: controller.engine.binaryMessenger
    )

    voiceChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "VOICE_UNAVAILABLE", message: "Voice synthesizer is unavailable.", details: nil))
        return
      }

      switch call.method {
      case "speakText":
        guard
          let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected non-empty text.", details: nil))
          return
        }

        self.voiceSynth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.47
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        if let voice = AVSpeechSynthesisVoice(language: "en-IN") ??
            AVSpeechSynthesisVoice(language: "en-US") {
          utterance.voice = voice
        }
        self.voiceSynth.speak(utterance)
        result(nil)

      case "stopSpeaking":
        self.voiceSynth.stopSpeaking(at: .immediate)
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
