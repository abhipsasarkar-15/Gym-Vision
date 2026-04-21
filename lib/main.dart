import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera_macos/camera_macos.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'platform_file.dart';
import 'platform_video_controller.dart';

const String kUserName = 'Priya';
const String kShareAssetRoute = '/share-asset';
const Duration kScreenTransition = Duration(milliseconds: 220);
const Duration kTipsUnlockDuration = Duration(seconds: 5);
const Duration kTipRotationDuration = Duration(milliseconds: 1500);
const bool kStartInRecording = bool.fromEnvironment(
  'START_IN_RECORDING',
  defaultValue: false,
);

const Curve kVoidEase = Cubic(0.16, 1, 0.3, 1);
const Duration kVoidFast = Duration(milliseconds: 100);
const Duration kVoidBase = Duration(milliseconds: 180);
const Duration kVoidSlow = Duration(milliseconds: 320);

const List<TipContent> kTips = [
  TipContent(
    icon: LucideIcons.footprints,
    text: 'Feet hip-width apart. Bar over mid-foot. Own the floor.',
  ),
  TipContent(
    icon: LucideIcons.ruler,
    text: 'Hinge at the hip first. Back flat like a tabletop. Not a hammock.',
  ),
  TipContent(
    icon: LucideIcons.eye,
    text: 'Eyes forward. Drive through the floor. Lock out proud at the top.',
  ),
];

const List<String> kCues = ['Back flat', 'Hip hinge', 'Lock out'];
const Map<String, String> kCueCallouts = {
  'Back flat': 'FLATTEN YOUR BACK.',
  'Hip hinge': 'HINGE AT THE HIP.',
  'Lock out': 'LOCK IT OUT.',
};
const List<LiveCoachingCue> kLiveCoachingPlan = [
  LiveCoachingCue(
    title: 'Set your frame',
    command: 'SQUARE SHOULDERS',
    detail:
        'Stand tall and center your body in the frame before the rep starts.',
    state: CueState.neutral,
    focusLabel: 'Setup',
    focusValue: 'Centered',
  ),
  LiveCoachingCue(
    title: 'Brace',
    command: 'RIBS DOWN',
    detail:
        'Brace hard through the belly so your spine stays long and stacked.',
    state: CueState.warn,
    focusLabel: 'Spine',
    focusValue: 'Needs brace',
  ),
  LiveCoachingCue(
    title: 'Start the pull',
    command: 'PUSH HIPS BACK',
    detail: 'Load the hamstrings first. Hinge before you chase depth.',
    state: CueState.warn,
    focusLabel: 'Hip path',
    focusValue: 'Sit back',
  ),
  LiveCoachingCue(
    title: 'Mid-rep',
    command: 'DRIVE THE FLOOR',
    detail:
        'Push through the whole foot and keep the bar path tight to the body.',
    state: CueState.pass,
    focusLabel: 'Drive',
    focusValue: 'Strong',
  ),
  LiveCoachingCue(
    title: 'Finish',
    command: 'CHEST TALL',
    detail: 'Finish proud at the top without leaning back or overextending.',
    state: CueState.warn,
    focusLabel: 'Lockout',
    focusValue: 'Clean finish',
  ),
  LiveCoachingCue(
    title: 'Rep complete',
    command: 'RESET AND BREATHE',
    detail: 'Reset the brace and stack up before the next repetition.',
    state: CueState.pass,
    focusLabel: 'Rhythm',
    focusValue: 'Ready again',
  ),
];

const List<FormRecommendation> kFormRecommendations = [
  FormRecommendation(
    title: 'Chest taller at lockout',
    detail: 'Finish proud without leaning back so the top position stays stacked.',
    impactLabel: 'Highest impact',
  ),
  FormRecommendation(
    title: 'Brace earlier before the pull',
    detail: 'Set the ribs down before you break the floor to keep the spine quieter.',
    impactLabel: 'Do next set',
  ),
  FormRecommendation(
    title: 'Keep the bar closer',
    detail: 'Brush the line of the leg on the way up to tighten the path.',
    impactLabel: 'Small refinement',
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const CultVisionApp());
}

class CultVisionApp extends StatelessWidget {
  const CultVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    final TextTheme textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppPalette.n50,
      displayColor: AppPalette.n50,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cult Vision Kiosk',
      theme: base.copyWith(
        scaffoldBackgroundColor: AppPalette.voidColor,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        textTheme: textTheme,
        primaryTextTheme: textTheme,
        iconTheme: const IconThemeData(
          color: AppPalette.n300,
          size: 18,
        ),
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.n50,
          onPrimary: AppPalette.voidColor,
          secondary: AppPalette.n200,
          onSecondary: AppPalette.voidColor,
          surface: AppPalette.depth1,
          onSurface: AppPalette.n50,
          error: AppPalette.redBright,
          onError: Colors.white,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const KioskFlowPage(),
    );
  }
}

enum KioskScreen {
  idle,
  onboarding,
  tips,
  recording,
  preview,
  uploading,
  uploadFailed,
  cultApp,
  shareAsset,
}

enum CueState { neutral, warn, pass }
enum RecordingSubState { detecting, active, pausedOutOfFrame }

class TipContent {
  const TipContent({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class LiveCoachingCue {
  const LiveCoachingCue({
    required this.title,
    required this.command,
    required this.detail,
    required this.state,
    required this.focusLabel,
    required this.focusValue,
  });

  final String title;
  final String command;
  final String detail;
  final CueState state;
  final String focusLabel;
  final String focusValue;
}

class FormRecommendation {
  const FormRecommendation({
    required this.title,
    required this.detail,
    required this.impactLabel,
  });

  final String title;
  final String detail;
  final String impactLabel;
}

class VisionSessionData {
  const VisionSessionData({
    required this.exerciseName,
    required this.repCount,
    required this.formScore,
    required this.centerName,
    required this.insight,
    required this.cues,
    this.tempVideoPath,
    this.processedVideoPath,
  });

  final String exerciseName;
  final int repCount;
  final int formScore;
  final String centerName;
  final String insight;
  final List<SessionCueSummary> cues;
  final String? tempVideoPath;
  final String? processedVideoPath;

  String? get shareableVideoPath => processedVideoPath ?? tempVideoPath;

  Map<String, dynamic> toJson() {
    return {
      'exerciseName': exerciseName,
      'repCount': repCount,
      'formScore': formScore,
      'centerName': centerName,
      'insight': insight,
      'tempVideoPath': tempVideoPath,
      'processedVideoPath': processedVideoPath,
      'cues': cues
          .map((cue) => {
                'label': cue.label,
                'state': cue.state.name,
              })
          .toList(),
    };
  }
}

class SessionCueSummary {
  const SessionCueSummary({
    required this.label,
    required this.state,
  });

  final String label;
  final CueState state;
}

class RecordingPoseAssessment {
  const RecordingPoseAssessment({
    required this.confidence,
    required this.cues,
    required this.hipAngle,
    required this.kneeAngle,
    required this.torsoLean,
    required this.backExtension,
  });

  final double confidence;
  final List<SessionCueSummary> cues;
  final double hipAngle;
  final double kneeAngle;
  final double torsoLean;
  final double backExtension;
}

enum VoidIconSize { inline, interactive, standalone }

extension on VoidIconSize {
  double get pixels => switch (this) {
    VoidIconSize.inline => 14,
    VoidIconSize.interactive => 18,
    VoidIconSize.standalone => 24,
  };
}

class VoidIcon extends StatelessWidget {
  const VoidIcon(
    this.icon, {
    super.key,
    this.size = VoidIconSize.inline,
    this.color,
  });

  final IconData icon;
  final VoidIconSize size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size.pixels, color: color);
  }
}

class VoidPressable extends StatefulWidget {
  const VoidPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 18,
    this.enabled = true,
    this.focusColor = AppPalette.violetBright,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final bool enabled;
  final Color focusColor;

  @override
  State<VoidPressable> createState() => _VoidPressableState();
}

class _VoidPressableState extends State<VoidPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final bool activeOverlay = _hovered || _pressed;

    return FocusableActionDetector(
      enabled: _enabled,
      onShowFocusHighlight: (bool focused) {
        if (_focused != focused) {
          setState(() {
            _focused = focused;
          });
        }
      },
      mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: MouseRegion(
        onEnter: _enabled
            ? (_) => setState(() {
                _hovered = true;
              })
            : null,
        onExit: _enabled
            ? (_) => setState(() {
                _hovered = false;
                _pressed = false;
              })
            : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled
              ? (_) => setState(() {
                  _pressed = true;
                })
              : null,
          onTapCancel: _enabled
              ? () => setState(() {
                  _pressed = false;
                })
              : null,
          onTapUp: _enabled
              ? (_) => setState(() {
                  _pressed = false;
                })
              : null,
          onTap: widget.onTap,
          child: AnimatedOpacity(
            duration: kVoidBase,
            curve: kVoidEase,
            opacity: _enabled ? 1 : 0.42,
            child: AnimatedScale(
              duration: kVoidFast,
              curve: kVoidEase,
              scale: _pressed ? 0.985 : 1,
              child: AnimatedContainer(
                duration: kVoidBase,
                curve: kVoidEase,
                transform: Matrix4.translationValues(
                  0,
                  _hovered && !_pressed ? -1 : 0,
                  0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    if (_hovered && !_pressed)
                      const BoxShadow(
                        color: Color.fromRGBO(0, 0, 0, 0.42),
                        blurRadius: 22,
                        offset: Offset(0, 12),
                      ),
                    if (_focused)
                      BoxShadow(
                        color: widget.focusColor.withValues(alpha: 0.18),
                        blurRadius: 0,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    widget.child,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          duration: kVoidFast,
                          opacity: activeOverlay ? 1 : 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                widget.borderRadius,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withValues(alpha: _pressed ? 0.05 : 0.07),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VoidTextAction extends StatelessWidget {
  const VoidTextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = AppPalette.n400,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return VoidPressable(
      onTap: onTap,
      borderRadius: 999,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              VoidIcon(icon!, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppPalette.n300,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return VoidPressable(
      onTap: onTap,
      borderRadius: 14,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppPalette.glass2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.glassBorder),
        ),
        alignment: Alignment.center,
        child: VoidIcon(
          icon,
          size: VoidIconSize.interactive,
          color: color,
        ),
      ),
    );
  }
}

class KioskFlowPage extends StatefulWidget {
  const KioskFlowPage({super.key});

  @override
  State<KioskFlowPage> createState() => _KioskFlowPageState();
}

class _KioskFlowPageState extends State<KioskFlowPage> {
  static const String _uploadQueueStorageKey = 'eidos_upload_queue';

  KioskScreen _screen = kStartInRecording
      ? KioskScreen.recording
      : KioskScreen.idle;
  bool _hasOnboarded = false;
  bool _nextUserWaiting = false;
  String? _cameraError;
  String? _queuedUploadNotice;
  VisionSessionData _sessionData = const VisionSessionData(
    exerciseName: 'Deadlift',
    repCount: 8,
    formScore: 84,
    centerName: 'Koramangala',
    insight:
        'Your lockout looked strongest when the ribcage stayed stacked. Keep the hinge earlier and you will get a cleaner bar path on the next set.',
    cues: [
      SessionCueSummary(label: 'Back flat', state: CueState.pass),
      SessionCueSummary(label: 'Hip hinge', state: CueState.warn),
      SessionCueSummary(label: 'Lock out', state: CueState.pass),
    ],
  );

  void _goTo(KioskScreen screen) {
    setState(() {
      _screen = screen;
    });
  }

  void _handleScan() {
    _goTo(_hasOnboarded ? KioskScreen.tips : KioskScreen.onboarding);
  }

  void _handleOnboardingAccept() {
    setState(() {
      _hasOnboarded = true;
      _screen = KioskScreen.tips;
    });
  }

  void _handleRecordingStart() {
    setState(() {
      _cameraError = null;
      _screen = KioskScreen.recording;
    });
  }

  void _handleRecordingStop(VisionSessionData session) {
    setState(() {
      _sessionData = VisionSessionData(
        exerciseName: session.exerciseName,
        repCount: session.repCount,
        formScore: session.formScore,
        centerName: session.centerName,
        insight: session.insight,
        cues: session.cues,
        tempVideoPath: session.tempVideoPath ?? _sessionData.tempVideoPath,
        processedVideoPath: session.processedVideoPath ?? _sessionData.processedVideoPath,
      );
      _screen = KioskScreen.preview;
    });
  }

  Future<void> _openShareAssetRoute() async {
    setState(() {
      _screen = KioskScreen.uploading;
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) {
      return;
    }
    if (_shouldFailUpload(_sessionData)) {
      setState(() {
        _screen = KioskScreen.uploadFailed;
      });
      return;
    }
    setState(() {
      _queuedUploadNotice = null;
      _screen = KioskScreen.cultApp;
    });
  }

  void _handleReturnToIdle() {
    setState(() {
      _screen = KioskScreen.idle;
      _cameraError = null;
    });
  }

  bool _shouldFailUpload(VisionSessionData session) {
    return session.shareableVideoPath == null || session.shareableVideoPath!.isEmpty;
  }

  Future<void> _retryUpload() async {
    setState(() {
      _screen = KioskScreen.uploading;
    });
    await _openShareAssetRoute();
  }

  Future<void> _remindLater() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> queuedUploads =
        prefs.getStringList(_uploadQueueStorageKey) ?? <String>[];
    queuedUploads.add(jsonEncode(_sessionData.toJson()));
    await prefs.setStringList(_uploadQueueStorageKey, queuedUploads);
    if (!mounted) {
      return;
    }
    setState(() {
      _queuedUploadNotice = "We'll send it when wifi returns.";
      _screen = KioskScreen.cultApp;
    });
  }

  Widget _screenForState() {
    switch (_screen) {
      case KioskScreen.idle:
        return IdleScreen(key: const ValueKey('idle'), onScan: _handleScan);
      case KioskScreen.onboarding:
        return OnboardingScreen(
          key: const ValueKey('onboarding'),
          userName: kUserName,
          onAccept: _handleOnboardingAccept,
        );
      case KioskScreen.tips:
        return TipsScreen(
          key: const ValueKey('tips'),
          userName: kUserName,
          cameraError: _cameraError,
          onReady: _handleRecordingStart,
        );
      case KioskScreen.recording:
        return RecordingScreen(
          key: const ValueKey('recording'),
          userName: kUserName,
          onStop: _handleRecordingStop,
          onSwitchUser: _handleReturnToIdle,
        );
      case KioskScreen.preview:
        return VideoPreviewScreen(
          key: const ValueKey('preview'),
          session: _sessionData,
          onSave: _openShareAssetRoute,
          onDiscard: () => _goTo(KioskScreen.tips),
        );
      case KioskScreen.uploading:
        return const UploadProgressScreen(key: ValueKey('uploading'));
      case KioskScreen.uploadFailed:
        return UploadFailedScreen(
          key: const ValueKey('upload_failed'),
          onRetry: _retryUpload,
          onRemindLater: _remindLater,
        );
      case KioskScreen.cultApp:
        return CultAppScreen(
          key: const ValueKey('cult_app'),
          userName: kUserName,
          onOpenAsset: () => _goTo(KioskScreen.shareAsset),
          nextUserWaiting: _nextUserWaiting,
          onRecordNext: () => _goTo(KioskScreen.tips),
          onEndSession: _handleReturnToIdle,
          queuedUploadNotice: _queuedUploadNotice,
          onToggleNextUser: () {
            setState(() {
              _nextUserWaiting = !_nextUserWaiting;
            });
          },
        );
      case KioskScreen.shareAsset:
        return ShareableAssetScreen(
          key: const ValueKey('share_asset'),
          session: _sessionData,
          onRecordNext: () => _goTo(KioskScreen.tips),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: AppPalette.voidColor),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AmbientBackdrop(),
            SafeArea(
              child: KeyedSubtree(
                key: ValueKey<KioskScreen>(_screen),
                child: _screenForState(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: const [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppPalette.voidColor,
                  AppPalette.depth1,
                  AppPalette.voidColor,
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.7, -1),
                  radius: 1.1,
                  colors: [
                    Color.fromRGBO(80, 60, 200, 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.92, -0.95),
                  radius: 0.88,
                  colors: [
                    Color.fromRGBO(60, 30, 140, 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.85, 0.95),
                  radius: 0.92,
                  colors: [
                    Color.fromRGBO(40, 20, 100, 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: VoidGridPainter())),
          Positioned(
            top: -120,
            left: -90,
            child: GlowOrb(size: 250, color: Color.fromRGBO(123, 86, 194, 0.08)),
          ),
          Positioned(
            bottom: -160,
            right: -40,
            child: GlowOrb(size: 280, color: Color.fromRGBO(123, 86, 194, 0.06)),
          ),
        ],
      ),
    );
  }
}

class VoidGridPainter extends CustomPainter {
  const VoidGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 28;
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.022)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlowOrb extends StatelessWidget {
  const GlowOrb({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class IdleScreen extends StatelessWidget {
  const IdleScreen({super.key, required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onScan,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                BrandMark(),
                SizedBox(width: 12),
                StatusPill(label: 'Idle', dotColor: AppPalette.n700),
              ],
            ),
            const Spacer(),
            Column(children: const [BreathingQrFrame(), SizedBox(height: 24)]),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 160),
              child: Text(
                'Open the Cult app and scan to start',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.n400,
                  fontSize: 12,
                  height: 1.6,
                  letterSpacing: -0.12,
                ),
              ),
            ),
            const Spacer(),
            const Text(
              'CHECKED-IN MEMBERS ONLY',
              style: TextStyle(
                color: AppPalette.n700,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BreathingQrFrame extends StatefulWidget {
  const BreathingQrFrame({super.key});

  @override
  State<BreathingQrFrame> createState() => _BreathingQrFrameState();
}

class _BreathingQrFrameState extends State<BreathingQrFrame> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _expanded ? 0.96 : 1,
        end: _expanded ? 1 : 0.96,
      ),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted) {
          setState(() {
            _expanded = !_expanded;
          });
        }
      },
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: SizedBox(
        width: 124,
        height: 124,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppPalette.glassBorder, width: 1.2),
              ),
            ),
            const _CornerDecoration(alignment: Alignment.topLeft),
            const _CornerDecoration(alignment: Alignment.topRight),
            const _CornerDecoration(alignment: Alignment.bottomLeft),
            const _CornerDecoration(alignment: Alignment.bottomRight),
            Text(
              '▦',
              style: TextStyle(
                fontSize: 46,
                color: AppPalette.n50.withValues(alpha: 0.06),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerDecoration extends StatelessWidget {
  const _CornerDecoration({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final bool top = alignment.y < 0;
    final bool left = alignment.x < 0;

    return Align(
      alignment: alignment,
      child: Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: AppPalette.n100, width: 2)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: AppPalette.n100, width: 2)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: AppPalette.n100, width: 2)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: AppPalette.n100, width: 2)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: left && top ? const Radius.circular(4) : Radius.zero,
            topRight: !left && top ? const Radius.circular(4) : Radius.zero,
            bottomLeft: left && !top ? const Radius.circular(4) : Radius.zero,
            bottomRight: !left && !top ? const Radius.circular(4) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({
    super.key,
    required this.userName,
    required this.onAccept,
  });

  final String userName;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              GlassAvatar(letter: userName.characters.first),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Hey $userName.',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.02,
                    letterSpacing: -1.4,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          const Column(
            children: [
              GuidanceRow(
                icon: LucideIcons.move,
                text: 'Stand 2 metres away, side-on to the camera.',
              ),
              SizedBox(height: 24),
              GuidanceRow(
                icon: LucideIcons.video,
                text: 'We record your set only, not between sets.',
              ),
              SizedBox(height: 24),
              GuidanceRow(
                icon: LucideIcons.badgeCheck,
                text: 'Your video goes straight to your Cult app.',
              ),
            ],
          ),
          const SizedBox(height: 28),
          const GlassPanel(
            padding: EdgeInsets.all(18),
            backgroundColor: AppPalette.passGlass,
            borderColor: AppPalette.passBorder,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VoidIcon(
                  LucideIcons.shieldCheck,
                  color: AppPalette.passBright,
                  size: VoidIconSize.interactive,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text:
                          'Background is always blurred. No one else in frame will appear in your video. ',
                      style: TextStyle(
                        color: AppPalette.n300,
                        fontSize: 14,
                        height: 1.55,
                      ),
                      children: [
                        TextSpan(
                          text: 'Ever.',
                          style: TextStyle(
                            color: AppPalette.passBright,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'By recording, you agree to our terms.',
            style: TextStyle(color: AppPalette.n500, fontSize: 12),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: "Got it, let's go", onPressed: onAccept),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Read full terms',
              style: TextStyle(color: AppPalette.n400, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class TipsScreen extends StatefulWidget {
  const TipsScreen({
    super.key,
    required this.userName,
    required this.onReady,
    required this.cameraError,
  });

  final String userName;
  final VoidCallback onReady;
  final String? cameraError;

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerLeft,
            child: PreviewTag(
              leadingColor: AppPalette.passBright,
              label: 'Front camera · true orientation',
            ),
          ),
          const Spacer(),
          GlassPanel(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            backgroundColor: AppPalette.glass1,
            borderColor: AppPalette.glassBorder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to record',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: -1.2,
                    color: AppPalette.n50,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Stand in frame and tap once to open the camera.',
                  style: TextStyle(
                    color: AppPalette.n300,
                    fontSize: 15,
                    height: 1.55,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.glass2,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppPalette.glassBorderSoft),
                  ),
                  child: const Row(
                    children: [
                      VoidIcon(
                        LucideIcons.scanFace,
                        size: VoidIconSize.interactive,
                        color: AppPalette.n200,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Minimal capture mode. No rotating tips. No extra steps.',
                          style: TextStyle(
                            color: AppPalette.n300,
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (widget.cameraError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassPanel(
                padding: const EdgeInsets.all(16),
                backgroundColor: AppPalette.redGlass,
                borderColor: AppPalette.redBorder,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const VoidIcon(
                      LucideIcons.circleAlert,
                      size: VoidIconSize.interactive,
                      color: AppPalette.redBright,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.cameraError!,
                        style: const TextStyle(
                          color: AppPalette.redBright,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          PrimaryButton(label: 'Open camera', onPressed: widget.onReady),
          const SizedBox(height: 18),
          Text(
            widget.userName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.n500,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your preview opens in true orientation with front camera priority.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.n500,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.userName,
    required this.onStop,
    required this.onSwitchUser,
  });

  final String userName;
  final ValueChanged<VisionSessionData> onStop;
  final VoidCallback onSwitchUser;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  static const List<SessionCueSummary> _neutralCues = [
    SessionCueSummary(label: 'Back', state: CueState.neutral),
    SessionCueSummary(label: 'Hinge', state: CueState.neutral),
    SessionCueSummary(label: 'Lock', state: CueState.neutral),
  ];

  Timer? _timer;
  Duration _recordingElapsed = Duration.zero;
  Duration _detectingElapsed = Duration.zero;
  Duration _pausedElapsed = Duration.zero;
  Duration _idleElapsed = Duration.zero;
  Duration _idleOverlayRemaining = const Duration(seconds: 120);
  bool _muted = false;
  Color? _edgePulseColor;
  RecordingSubState _recordingSubState = RecordingSubState.active;
  double _poseConfidence = 0;
  int _consecutiveHighConfidenceFrames = 0;
  int _consecutiveLowConfidenceFrames = 0;
  int _consecutiveOutOfFrameFrames = 0;
  int _consecutiveRecoveredFrames = 0;
  bool _showDetectingRetry = false;
  bool _showIdleOverlay = false;
  String? _positiveNudge;
  Timer? _positiveNudgeTimer;
  RecordingPoseAssessment? _latestAssessment;
  DateTime? _lastPoseUpdateAt;
  int _completedRepCount = 0;
  bool _repBottomReached = false;
  int _lastRepTimestampMs = 0;
  final Map<String, int> _cueObservedCounts = <String, int>{
    'Back flat': 0,
    'Hip hinge': 0,
    'Lock out': 0,
  };
  final Map<String, int> _cuePassCounts = <String, int>{
    'Back flat': 0,
    'Hip hinge': 0,
    'Lock out': 0,
  };

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tickRecordingState(const Duration(milliseconds: 250));
      });
    });
    _edgePulseColor = _colorForState(_activeCue.state);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positiveNudgeTimer?.cancel();
    super.dispose();
  }

  String _timeLabel() {
    final int totalSeconds = _recordingElapsed.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String minuteText = minutes.toString().padLeft(2, '0');
    final String secondText = seconds.toString().padLeft(2, '0');
    return '$minuteText:$secondText';
  }

  int get _repCount => _completedRepCount;

  LiveCoachingCue get _activeCue {
    if (_recordingSubState == RecordingSubState.detecting) {
      return kLiveCoachingPlan.first;
    }
    final List<SessionCueSummary> cues = _currentCueSummaries;
    SessionCueSummary? warningCue;
    for (final SessionCueSummary cue in cues) {
      if (cue.state == CueState.warn) {
        warningCue = cue;
        break;
      }
    }
    if (warningCue?.label == 'Back') {
      return const LiveCoachingCue(
        title: 'Spine line',
        command: 'BACK FLAT',
        detail: 'Keep the chest open and brace earlier so the spine stays long through the hinge.',
        state: CueState.warn,
        focusLabel: 'Back',
        focusValue: 'Flatten',
      );
    }
    if (warningCue?.label == 'Hinge') {
      return const LiveCoachingCue(
        title: 'Hip path',
        command: 'PUSH HIPS BACK',
        detail: 'Let the hips travel back sooner so the hamstrings load before the pull.',
        state: CueState.warn,
        focusLabel: 'Hinge',
        focusValue: 'Sit back',
      );
    }
    if (warningCue?.label == 'Lock') {
      return const LiveCoachingCue(
        title: 'Finish',
        command: 'CHEST TALL',
        detail: 'Stand tall at the top and stack the ribs over the hips without leaning back.',
        state: CueState.warn,
        focusLabel: 'Lockout',
        focusValue: 'Stand tall',
      );
    }
    return const LiveCoachingCue(
      title: 'Rep quality',
      command: 'CLEAN REP',
      detail: 'Landmarks are stable and the main hinge checkpoints are reading clean.',
      state: CueState.pass,
      focusLabel: 'Form',
      focusValue: 'Strong',
    );
  }

  List<SessionCueSummary> get _currentCueSummaries {
    if (_recordingSubState != RecordingSubState.active || _poseConfidence < 0.65) {
      return _neutralCues;
    }
    return _latestAssessment?.cues ?? _neutralCues;
  }

  bool get _allCuesPass =>
      _currentCueSummaries.every((cue) => cue.state == CueState.pass);

  void _tickRecordingState(Duration step) {
    if (_showIdleOverlay) {
      _idleOverlayRemaining -= step;
      if (_idleOverlayRemaining <= Duration.zero) {
        _finishSession();
        return;
      }
      return;
    }

    if (_lastPoseUpdateAt == null ||
        DateTime.now().difference(_lastPoseUpdateAt!) > const Duration(milliseconds: 900)) {
      _poseConfidence = 0;
      _latestAssessment = null;
    }

    switch (_recordingSubState) {
      case RecordingSubState.detecting:
        _detectingElapsed += step;
        if (_poseConfidence > 0.65) {
          _consecutiveHighConfidenceFrames += 1;
        } else {
          _consecutiveHighConfidenceFrames = 0;
        }
        if (_consecutiveHighConfidenceFrames >= 3) {
          _recordingSubState = RecordingSubState.active;
          _detectingElapsed = Duration.zero;
          _showDetectingRetry = false;
          _idleElapsed = Duration.zero;
        } else if (_detectingElapsed >= const Duration(seconds: 20)) {
          _showDetectingRetry = true;
        }
      case RecordingSubState.active:
        _recordingElapsed += step;
        _idleElapsed += step;
        if (_poseConfidence >= 0.65) {
          _consecutiveLowConfidenceFrames = 0;
          _consecutiveOutOfFrameFrames = 0;
          _edgePulseColor = _colorForState(_activeCue.state);
        } else if (_poseConfidence >= 0.3) {
          _consecutiveLowConfidenceFrames += 1;
          _consecutiveOutOfFrameFrames = 0;
        } else {
          _consecutiveOutOfFrameFrames += 1;
          if (_consecutiveOutOfFrameFrames >= 3) {
            _recordingSubState = RecordingSubState.pausedOutOfFrame;
            _pausedElapsed = Duration.zero;
          }
        }

        if (_idleElapsed >= const Duration(seconds: 120)) {
          _showIdleOverlay = true;
          _idleOverlayRemaining = const Duration(seconds: 120);
        }
      case RecordingSubState.pausedOutOfFrame:
        _pausedElapsed += step;
        if (_poseConfidence > 0.65) {
          _consecutiveRecoveredFrames += 1;
        } else {
          _consecutiveRecoveredFrames = 0;
        }
        if (_consecutiveRecoveredFrames >= 3) {
          _recordingSubState = RecordingSubState.active;
          _pausedElapsed = Duration.zero;
          _consecutiveRecoveredFrames = 0;
          _edgePulseColor = _colorForState(_activeCue.state);
          return;
        }
        if (_pausedElapsed >= const Duration(seconds: 10)) {
          return;
        }
    }
  }

  void _showPositiveNudge(String text) {
    _positiveNudgeTimer?.cancel();
    _positiveNudge = text;
    _positiveNudgeTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _positiveNudge = null;
        });
      }
    });
  }

  void _resetDetectingTimer() {
    setState(() {
      _detectingElapsed = Duration.zero;
      _showDetectingRetry = false;
      _consecutiveHighConfidenceFrames = 0;
    });
  }

  void _handlePoseResult(
    CameraPoseResult? result,
    CameraMacOSException? error,
  ) {
    if (!mounted || error != null) {
      return;
    }
    if (result == null || !result.hasPose) {
      setState(() {
        _lastPoseUpdateAt = DateTime.now();
        _poseConfidence = 0;
        _latestAssessment = null;
      });
      return;
    }

    final RecordingPoseAssessment assessment = _buildPoseAssessment(result);
    final double confidence = assessment.confidence;
    final bool justCompletedRep = _updateRepCycle(
      assessment: assessment,
      timestampMs: result.timestampMs,
    );

    setState(() {
      _lastPoseUpdateAt = DateTime.now();
      _poseConfidence = confidence;
      _latestAssessment = assessment;
      _edgePulseColor = _colorForState(_activeCue.state);
      if (confidence >= 0.65) {
        for (final SessionCueSummary cue in assessment.cues) {
          _recordCueObservation(cue);
        }
      }
      if (justCompletedRep) {
        _idleElapsed = Duration.zero;
        if (confidence >= 0.65 && _allCuesPass) {
          _showPositiveNudge('Clean rep.');
        }
      }
    });
  }

  bool _updateRepCycle({
    required RecordingPoseAssessment assessment,
    required int timestampMs,
  }) {
    final bool inBottomRange =
        assessment.hipAngle < 118 && assessment.torsoLean > 18;
    final bool atTopRange =
        assessment.hipAngle > 154 &&
        assessment.kneeAngle > 154 &&
        assessment.torsoLean < 18;

    if (assessment.confidence < 0.65) {
      return false;
    }

    if (inBottomRange) {
      _repBottomReached = true;
      return false;
    }

    if (_repBottomReached &&
        atTopRange &&
        timestampMs - _lastRepTimestampMs > 1200) {
      _repBottomReached = false;
      _completedRepCount += 1;
      _lastRepTimestampMs = timestampMs;
      return true;
    }

    return false;
  }

  RecordingPoseAssessment _buildPoseAssessment(CameraPoseResult result) {
    const int leftShoulder = 11;
    const int rightShoulder = 12;
    const int leftHip = 23;
    const int rightHip = 24;
    const int leftKnee = 25;
    const int rightKnee = 26;
    const int leftAnkle = 27;
    const int rightAnkle = 28;
    const int leftEar = 7;
    const int rightEar = 8;

    final List<CameraPoseLandmark> landmarks = result.landmarks;
    final List<CameraPoseLandmark> worldLandmarks =
        result.worldLandmarks.length == landmarks.length
        ? result.worldLandmarks
        : result.landmarks;

    double confidenceFor(List<int> indices) {
      double total = 0;
      int count = 0;
      for (final int index in indices) {
        if (index >= landmarks.length) {
          continue;
        }
        final CameraPoseLandmark landmark = landmarks[index];
        total += math.min(landmark.visibility, landmark.presence);
        count += 1;
      }
      return count == 0 ? 0 : total / count;
    }

    final bool useLeftSide = confidenceFor([
          leftShoulder,
          leftHip,
          leftKnee,
          leftAnkle,
          leftEar,
        ]) >=
        confidenceFor([
          rightShoulder,
          rightHip,
          rightKnee,
          rightAnkle,
          rightEar,
        ]);

    CameraPoseLandmark landmarkAt(int leftIndex, int rightIndex, {bool world = false}) {
      final List<CameraPoseLandmark> source = world ? worldLandmarks : landmarks;
      final int index = useLeftSide ? leftIndex : rightIndex;
      return source[index];
    }

    Offset point(CameraPoseLandmark landmark) => Offset(landmark.x, landmark.y);

    double angleDegrees(Offset a, Offset b, Offset c) {
      final Offset ba = a - b;
      final Offset bc = c - b;
      final double magnitude =
          ba.distance * bc.distance;
      if (magnitude == 0) {
        return 180;
      }
      final double cosine =
          ((ba.dx * bc.dx) + (ba.dy * bc.dy)) / magnitude;
      return math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;
    }

    double vectorAngleFromVertical(Offset from, Offset to) {
      final Offset vector = to - from;
      final Offset vertical = const Offset(0, -1);
      final double magnitude = vector.distance * vertical.distance;
      if (magnitude == 0) {
        return 0;
      }
      final double cosine =
          ((vector.dx * vertical.dx) + (vector.dy * vertical.dy)) / magnitude;
      return math.acos(cosine.clamp(-1.0, 1.0)) * 180 / math.pi;
    }

    final CameraPoseLandmark shoulder = landmarkAt(leftShoulder, rightShoulder, world: true);
    final CameraPoseLandmark hip = landmarkAt(leftHip, rightHip, world: true);
    final CameraPoseLandmark knee = landmarkAt(leftKnee, rightKnee, world: true);
    final CameraPoseLandmark ankle = landmarkAt(leftAnkle, rightAnkle, world: true);
    final CameraPoseLandmark ear = landmarkAt(leftEar, rightEar, world: true);

    final double hipAngle =
        angleDegrees(point(shoulder), point(hip), point(knee));
    final double kneeAngle =
        angleDegrees(point(hip), point(knee), point(ankle));
    final double torsoLean =
        vectorAngleFromVertical(point(hip), point(shoulder));
    final double backExtension =
        angleDegrees(point(ear), point(shoulder), point(hip));
    final bool hingePhase = hipAngle < 138 || torsoLean > 22;
    final bool backPass = backExtension > 148;
    final bool hingePass = hingePhase ? hipAngle < 122 : true;
    final bool lockPass =
        !hingePhase && hipAngle > 154 && kneeAngle > 154 && torsoLean < 18;

    final List<SessionCueSummary> cues = [
      SessionCueSummary(
        label: 'Back',
        state: backPass ? CueState.pass : CueState.warn,
      ),
      SessionCueSummary(
        label: 'Hinge',
        state: hingePhase
            ? (hingePass ? CueState.pass : CueState.warn)
            : CueState.neutral,
      ),
      SessionCueSummary(
        label: 'Lock',
        state: hingePhase
            ? CueState.neutral
            : (lockPass ? CueState.pass : CueState.warn),
      ),
    ];

    return RecordingPoseAssessment(
      confidence: result.overallConfidence,
      cues: cues,
      hipAngle: hipAngle,
      kneeAngle: kneeAngle,
      torsoLean: torsoLean,
      backExtension: backExtension,
    );
  }

  void _recordCueObservation(SessionCueSummary cue) {
    final String? key = switch (cue.label) {
      'Back' => 'Back flat',
      'Hinge' => 'Hip hinge',
      'Lock' => 'Lock out',
      _ => null,
    };
    if (key == null || cue.state == CueState.neutral) {
      return;
    }
    _cueObservedCounts[key] = (_cueObservedCounts[key] ?? 0) + 1;
    if (cue.state == CueState.pass) {
      _cuePassCounts[key] = (_cuePassCounts[key] ?? 0) + 1;
    }
  }

  List<SessionCueSummary> _sessionCueSummaries() {
    CueState stateFor(String key) {
      final int observed = _cueObservedCounts[key] ?? 0;
      if (observed == 0) {
        return CueState.neutral;
      }
      final double ratio = (_cuePassCounts[key] ?? 0) / observed;
      return ratio >= 0.72 ? CueState.pass : CueState.warn;
    }

    return [
      SessionCueSummary(label: 'Back flat', state: stateFor('Back flat')),
      SessionCueSummary(label: 'Hip hinge', state: stateFor('Hip hinge')),
      SessionCueSummary(label: 'Lock out', state: stateFor('Lock out')),
    ];
  }

  int _sessionFormScore() {
    final List<double> ratios = _cueObservedCounts.keys.map((String key) {
      final int observed = _cueObservedCounts[key] ?? 0;
      if (observed == 0) {
        return 0.65;
      }
      return (_cuePassCounts[key] ?? 0) / observed;
    }).toList();
    final double average = ratios.reduce((double a, double b) => a + b) / ratios.length;
    return (average * 100).round().clamp(1, 100);
  }

  String _sessionInsight() {
    final Map<String, double> ratios = {
      for (final String key in _cueObservedCounts.keys)
        key: (_cueObservedCounts[key] ?? 0) == 0
            ? 0.65
            : (_cuePassCounts[key] ?? 0) / (_cueObservedCounts[key] ?? 1),
    };
    final String weakestCue =
        ratios.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    switch (weakestCue) {
      case 'Back flat':
        return 'Your cleanest reps kept the spine longer through the hinge. Brace sooner and keep the chest from softening at the bottom.';
      case 'Hip hinge':
        return 'The set improved whenever the hips moved back before the pull. Start the next set by loading the hamstrings earlier.';
      case 'Lock out':
      default:
        return 'Your best finish came when the ribs stayed stacked over the hips. Stand tall at the top without leaning back to clean up the lockout.';
    }
  }

  void _finishSession() {
    widget.onStop(
      VisionSessionData(
        exerciseName: 'Deadlift',
        repCount: _repCount,
        formScore: _sessionFormScore(),
        centerName: 'Koramangala',
        insight: _sessionInsight(),
        cues: _sessionCueSummaries(),
      ),
    );
  }

  Color? _colorForState(CueState state) {
    switch (state) {
      case CueState.warn:
        return AppPalette.redBright;
      case CueState.pass:
        return AppPalette.passBright;
      case CueState.neutral:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDetecting = _recordingSubState == RecordingSubState.detecting;
    final bool isPaused = _recordingSubState == RecordingSubState.pausedOutOfFrame;
    final bool showLowConfidenceWarning =
        _recordingSubState == RecordingSubState.active &&
        _consecutiveLowConfidenceFrames >= 3 &&
        _poseConfidence >= 0.3 &&
        _poseConfidence < 0.65;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            decoration: BoxDecoration(
              border: Border.all(
                color:
                    _edgePulseColor?.withValues(alpha: 0.75) ??
                    Colors.transparent,
                width: 4,
              ),
              boxShadow: _edgePulseColor == null
                  ? null
                  : [
                      BoxShadow(
                        color: _edgePulseColor!.withValues(alpha: 0.35),
                        blurRadius: 48,
                        spreadRadius: 6,
                      ),
                    ],
            ),
          ),
        ),
        Positioned.fill(
          child: RecordingCameraBackdrop(onPoseResult: _handlePoseResult),
        ),
        Positioned.fill(
          child: Container(
            color: isPaused
                ? const Color.fromRGBO(6, 8, 16, 0.55)
                : const Color.fromRGBO(6, 8, 16, 0.28),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            children: [
              Row(
                children: [
                  GlassIconButton(
                    onTap: () {
                      setState(() {
                        _muted = !_muted;
                      });
                    },
                    icon: _muted
                        ? LucideIcons.volumeX
                        : LucideIcons.volume2,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RecordingIntroBanner(userName: widget.userName),
                  ),
                  const SizedBox(width: 10),
                  _RepCounterPill(repCount: _repCount),
                  if (!isDetecting) ...[
                    const SizedBox(width: 10),
                    RecordingPill(timeLabel: _timeLabel()),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              if (isDetecting)
                Align(
                  alignment: Alignment.center,
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    backgroundColor: const Color.fromRGBO(6, 8, 16, 0.7),
                    borderColor: Colors.transparent,
                    borderRadius: 999,
                    blur: 12,
                    child: const Text(
                      'Stand side-on, 2 metres away',
                      style: TextStyle(
                        color: Color.fromRGBO(255, 255, 255, 0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else
                LiveCoachBanner(
                  cue: _activeCue,
                  muted: _muted || isPaused || showLowConfidenceWarning,
                ),
              const Spacer(),
              if (_positiveNudge != null && !showLowConfidenceWarning && !isPaused)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    backgroundColor: AppPalette.passGlass,
                    borderColor: AppPalette.passBorder,
                    borderRadius: 16,
                    child: Text(
                      _positiveNudge!,
                      style: const TextStyle(
                        color: AppPalette.passBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (isPaused)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _RecordingWarningBar(
                    text: 'Step back into frame',
                    foreground: Color.fromRGBO(184, 96, 0, 1),
                    background: Color.fromRGBO(184, 96, 0, 0.1),
                  ),
                )
              else if (showLowConfidenceWarning)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _RecordingWarningBar(
                    text: 'Adjust lighting or step closer',
                    foreground: Color.fromRGBO(255, 255, 255, 0.5),
                    background: Color.fromRGBO(184, 96, 0, 0.1),
                  ),
                ),
              if (isDetecting || isPaused)
                _CuePillRow(cues: _currentCueSummaries)
              else
                Row(
                  children: List.generate(3, (index) {
                    final SessionCueSummary cue = _currentCueSummaries[index];
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                        child: CoachingMeter(
                          label: cue.label,
                          value: cue.state == CueState.pass
                              ? 'Pass'
                              : cue.state == CueState.warn
                                  ? 'Warn'
                                  : 'Neutral',
                          state: cue.state,
                          isActive: index == 0,
                        ),
                      ),
                    );
                  }),
                ),
              if (_showDetectingRetry) ...[
                const SizedBox(height: 12),
                Column(
                  children: [
                    const Text(
                      'Adjust your position — try standing side-on',
                      style: TextStyle(
                        color: AppPalette.n300,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(label: 'Try again', onPressed: _resetDetectingTimer),
                  ],
                ),
              ],
              if (isPaused && _pausedElapsed >= const Duration(seconds: 10)) ...[
                const SizedBox(height: 12),
                Column(
                  children: [
                    const Text(
                      'Still recording. Step into frame or stop.',
                      style: TextStyle(
                        color: AppPalette.n300,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(label: 'Stop recording', onPressed: _finishSession),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: VoidTextAction(
                        label: 'Switch user',
                        onTap: widget.onSwitchUser,
                        icon: LucideIcons.arrowRightLeft,
                      ),
                    ),
                  ),
                  GlassStopButton(onPressed: _finishSession),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ),
        if (_showIdleOverlay)
          Positioned.fill(
            child: Container(
              color: const Color.fromRGBO(6, 8, 16, 0.8),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1120),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Still working out?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _idleOverlayRemaining.inSeconds.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w200,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showIdleOverlay = false;
                              _idleElapsed = Duration.zero;
                              _idleOverlayRemaining = const Duration(seconds: 120);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF07080F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Keep recording',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _finishSession,
                        child: const Text('End session'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class VideoPreviewScreen extends StatefulWidget {
  const VideoPreviewScreen({
    super.key,
    required this.session,
    required this.onSave,
    required this.onDiscard,
  });

  final VisionSessionData session;
  final Future<void> Function() onSave;
  final VoidCallback onDiscard;

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  bool _isRendering = false;
  bool _thumbnailReady = false;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF07080F),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double mediaHeight = math.min(
            constraints.maxHeight * 0.58,
            constraints.maxHeight - 176,
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: mediaHeight.clamp(240, constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SubmissionVideoThumbnail(
                      videoPath: widget.session.tempVideoPath,
                      onLoadedChanged: (loaded) {
                        if (_thumbnailReady != loaded && mounted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _thumbnailReady = loaded;
                              });
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.session.exerciseName,
                            style: const TextStyle(
                              color: Color(0xFFF0F1F7),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            '${widget.session.repCount} reps',
                            style: const TextStyle(
                              color: Color(0x66FFFFFF),
                              fontSize: 18,
                              fontWeight: FontWeight.w200,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_thumbnailReady)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isRendering
                                ? null
                                : () async {
                                    setState(() {
                                      _isRendering = true;
                                    });
                                    await Future<void>.delayed(
                                      const Duration(milliseconds: 900),
                                    );
                                    if (!mounted) {
                                      return;
                                    }
                                    await widget.onSave();
                                    if (mounted) {
                                      setState(() {
                                        _isRendering = false;
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF0F1F7),
                              foregroundColor: const Color(0xFF07080F),
                              disabledBackgroundColor: const Color(0xFFF0F1F7),
                              disabledForegroundColor: const Color(0xFF07080F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _isRendering ? 'Saving...' : 'Save and share',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isRendering ? null : _showDiscardDialog,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0x44FFFFFF),
                          overlayColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Discard',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color.fromRGBO(255, 255, 255, 0.27),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDiscardDialog() async {
    final bool? shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard this recording?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    if (shouldDiscard == true) {
      await _deleteTempFile();
      if (mounted) {
        widget.onDiscard();
      }
    }
  }

  Future<void> _deleteTempFile() async {
    final String? path = widget.session.tempVideoPath;
    if (path == null || path.isEmpty) {
      return;
    }
    await deleteLocalFileIfExists(path);
  }
}

class UploadProgressScreen extends StatelessWidget {
  const UploadProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF07080F),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Uploading',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(999)),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Color.fromRGBO(255, 255, 255, 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF378ADD),
                  ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Processing your form data',
              style: TextStyle(
                color: Color.fromRGBO(255, 255, 255, 0.35),
                fontSize: 13,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UploadFailedScreen extends StatelessWidget {
  const UploadFailedScreen({
    super.key,
    required this.onRetry,
    required this.onRemindLater,
  });

  final Future<void> Function() onRetry;
  final Future<void> Function() onRemindLater;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF07080F),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not connect.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your recording is saved locally.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.55),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF07080F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Try again',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: onRemindLater,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color.fromRGBO(255, 255, 255, 0.55),
                    side: const BorderSide(
                      color: Color.fromRGBO(255, 255, 255, 0.12),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Remind me later',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CultAppScreen extends StatefulWidget {
  const CultAppScreen({
    super.key,
    required this.userName,
    required this.onOpenAsset,
    required this.onRecordNext,
    required this.onEndSession,
    required this.nextUserWaiting,
    required this.queuedUploadNotice,
    required this.onToggleNextUser,
  });

  final String userName;
  final VoidCallback onOpenAsset;
  final VoidCallback onRecordNext;
  final VoidCallback onEndSession;
  final bool nextUserWaiting;
  final String? queuedUploadNotice;
  final VoidCallback onToggleNextUser;

  @override
  State<CultAppScreen> createState() => _CultAppScreenState();
}

class _CultAppScreenState extends State<CultAppScreen> {
  Timer? _countdownTimer;
  Timer? _renderTimer;
  int? _countdown;
  int _renderStage = 0;

  @override
  void initState() {
    super.initState();
    _renderTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_renderStage >= 2) {
        timer.cancel();
        return;
      }
      setState(() {
        _renderStage += 1;
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _renderTimer?.cancel();
    super.dispose();
  }

  void _startEndSession() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown == null) {
        timer.cancel();
        return;
      }
      if (_countdown == 0) {
        timer.cancel();
        widget.onEndSession();
      } else {
        setState(() {
          _countdown = _countdown! - 1;
        });
      }
    });
  }

  String get _statusTitle {
    switch (_renderStage) {
      case 0:
        return 'Rendering your workout asset';
      case 1:
        return 'Syncing video and recommendations';
      case 2:
        return 'Live in the Cult app';
    }
    return '';
  }

  String get _statusBody {
    switch (_renderStage) {
      case 0:
        return 'We are stabilizing the clip, cleaning the frame, and choosing the workout cover moment.';
      case 1:
        return 'The rendered video and coaching takeaways are being attached to today\'s workout summary.';
      case 2:
        return 'Your finished workout is now visible inside the Cult app and ready to replay or share.';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.nextUserWaiting)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: AppPalette.redGlass,
              child: const Text(
                'Next up: tap End session to hand over.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.redBright,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SuccessBadge(),
                const SizedBox(height: 28),
                Text(
                  _renderStage == 2
                      ? 'Your workout is in Cult, ${widget.userName}.'
                      : 'Sending it to Cult, ${widget.userName}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.n50,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                    height: 1.04,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _statusTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.n300,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
                if (widget.queuedUploadNotice != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.queuedUploadNotice!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppPalette.n400,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 342),
                  child: CultAppResultCard(
                    userName: widget.userName,
                    stage: _renderStage,
                    body: _statusBody,
                  ),
                ),
                const SizedBox(height: 28),
                if (_countdown != null)
                  Column(
                    children: [
                      const Text(
                        'ENDING SESSION IN',
                        style: TextStyle(
                          color: AppPalette.n500,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_countdown',
                        style: const TextStyle(
                          color: AppPalette.n50,
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  )
                else if (_renderStage == 2)
                  Column(
                    children: [
                      PrimaryButton(
                        label: 'Open Shareable Asset',
                        onPressed: widget.onOpenAsset,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Record Next Set',
                              onPressed: widget.onRecordNext,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SecondaryButton(
                              label: 'End Session',
                              backgroundColor: Colors.transparent,
                              borderColor: AppPalette.glassBorderSoft,
                              textColor: AppPalette.n300,
                              onPressed: _startEndSession,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Record Next Set',
                          onPressed: widget.onRecordNext,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SecondaryButton(
                          label: 'End Session',
                          backgroundColor: Colors.transparent,
                          borderColor: AppPalette.glassBorderSoft,
                          textColor: AppPalette.n300,
                          onPressed: _startEndSession,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 12,
          child: VoidPressable(
            onTap: widget.onToggleNextUser,
            borderRadius: 999,
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: AppPalette.glass2,
              borderColor: AppPalette.glassBorder,
              borderRadius: 999,
              child: Text(
                widget.nextUserWaiting
                    ? 'Next user waiting'
                    : 'Toggle: next user',
                style: const TextStyle(
                  color: AppPalette.n400,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        text: 'CULT ',
        style: TextStyle(
          color: AppPalette.n50,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.9,
        ),
        children: [
          TextSpan(
            text: 'EIDOS',
            style: TextStyle(
              color: AppPalette.n600,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.dotColor});

  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      borderRadius: 999,
      backgroundColor: AppPalette.glass1,
      borderColor: AppPalette.glassBorderSoft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppPalette.n600,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassAvatar extends StatelessWidget {
  const GlassAvatar({super.key, required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppPalette.glass3,
        shape: BoxShape.circle,
        border: Border.all(color: AppPalette.glassBorderStrong),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: AppPalette.n200,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class GuidanceRow extends StatelessWidget {
  const GuidanceRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: VoidIcon(
            icon,
            color: AppPalette.n400,
            size: VoidIconSize.interactive,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppPalette.n200,
              fontSize: 16,
              height: 1.7,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class LiveCoachBanner extends StatelessWidget {
  const LiveCoachBanner({super.key, required this.cue, required this.muted});

  final LiveCoachingCue cue;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final bool isWarn = cue.state == CueState.warn;
    final bool isPass = cue.state == CueState.pass;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      backgroundColor: AppPalette.glass3,
      borderColor: isWarn
          ? AppPalette.warnBorder
          : isPass
          ? AppPalette.passBorder
          : AppPalette.glassBorderStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: cue.title,
                dotColor: isWarn
                    ? AppPalette.warnBright
                    : isPass
                    ? AppPalette.passBright
                    : AppPalette.n400,
              ),
              const Spacer(),
              Text(
                muted ? 'VOICE OFF' : 'VOICE ON',
                style: const TextStyle(
                  color: AppPalette.n500,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            cue.command,
            style: TextStyle(
              color: isWarn
                  ? AppPalette.warnBright
                  : isPass
                  ? AppPalette.passBright
                  : AppPalette.n50,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            cue.detail,
            style: const TextStyle(
              color: AppPalette.n200,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class CoachingMeter extends StatelessWidget {
  const CoachingMeter({
    super.key,
    required this.label,
    required this.value,
    required this.state,
    required this.isActive,
  });

  final String label;
  final String value;
  final CueState state;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (state) {
      CueState.warn => AppPalette.warnBright,
      CueState.pass => AppPalette.passBright,
      CueState.neutral => AppPalette.n300,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        backgroundColor: isActive
            ? AppPalette.glass3
            : AppPalette.glass1.withValues(alpha: 0.88),
        borderColor: isActive
            ? accent.withValues(alpha: 0.45)
            : AppPalette.glassBorderSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 3,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppPalette.n500,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: isActive ? AppPalette.n50 : AppPalette.n300,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CultAppResultCard extends StatelessWidget {
  const CultAppResultCard({
    super.key,
    required this.userName,
    required this.stage,
    required this.body,
  });

  final String userName;
  final int stage;
  final String body;

  @override
  Widget build(BuildContext context) {
    final bool isReady = stage == 2;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      backgroundColor: AppPalette.glass2,
      borderColor: isReady
          ? AppPalette.violetBorder
          : AppPalette.glassBorderStrong,
      child: Column(
        children: [
          Row(
            children: [
              const BrandMark(),
              const Spacer(),
              StatusPill(
                label: isReady ? 'Live in app' : 'Rendering',
                dotColor: isReady
                    ? AppPalette.violetBright
                    : AppPalette.redBright,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const VoidSessionScoreCard(score: 84),
          const SizedBox(height: 12),
          _CultAppFeedMockup(userName: userName, isReady: isReady, body: body),
          const SizedBox(height: 12),
          _CultAppRecommendationsPanel(isReady: isReady),
        ],
      ),
    );
  }
}

class ShareableAssetScreen extends StatelessWidget {
  const ShareableAssetScreen({
    super.key,
    required this.session,
    required this.onRecordNext,
  });

  final VisionSessionData session;
  final VoidCallback onRecordNext;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF07080F),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ShareAssetVideoCard(videoPath: session.shareableVideoPath),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: session.cues
                      .map(
                        (cue) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: cue == session.cues.last ? 0 : 8,
                            ),
                            child: _CueSummaryChip(cue: cue),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${session.repCount}',
                          style: const TextStyle(
                            color: Color(0xFFF0F1F7),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const Text(
                          'reps',
                          style: TextStyle(
                            color: Color(0x55FFFFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${session.formScore}',
                          style: const TextStyle(
                            color: Color(0xFFF0F1F7),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const Text(
                          'form score',
                          style: TextStyle(
                            color: Color(0x55FFFFFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x0F7B56C2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x287B56C2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FROM THIS SESSION',
                        style: TextStyle(
                          color: Color(0x66C2A8FF),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.insight,
                        style: const TextStyle(
                          color: Color(0x88FFFFFF),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          height: 1.6,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: _ShareAssetActions(
                  session: session,
                  onRecordNext: onRecordNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmissionVideoThumbnail extends StatefulWidget {
  const _SubmissionVideoThumbnail({
    required this.videoPath,
    this.onLoadedChanged,
  });

  final String? videoPath;
  final ValueChanged<bool>? onLoadedChanged;

  @override
  State<_SubmissionVideoThumbnail> createState() => _SubmissionVideoThumbnailState();
}

class _SubmissionVideoThumbnailState extends State<_SubmissionVideoThumbnail> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  bool _failedToLoad = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant _SubmissionVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _disposeController();
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _initializeVideo() {
    _failedToLoad = false;
    final String? path = widget.videoPath;
    if (path == null || path.isEmpty) {
      widget.onLoadedChanged?.call(true);
      return;
    }
    _controller = createVideoControllerForPath(path);
    if (_controller == null) {
      _failedToLoad = true;
      widget.onLoadedChanged?.call(true);
      return;
    }
    _initializeFuture = _controller!.initialize().catchError((_) {
      if (mounted) {
        setState(() {
          _failedToLoad = true;
        });
      } else {
        _failedToLoad = true;
      }
      widget.onLoadedChanged?.call(true);
    });
  }

  void _disposeController() {
    final VideoPlayerController? controller = _controller;
    _controller = null;
    _initializeFuture = null;
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: const Color(0xFF0D1018),
        child: widget.videoPath == null || widget.videoPath!.isEmpty || _failedToLoad
            ? const _SubmissionPreviewFallback()
            : FutureBuilder<void>(
                future: _initializeFuture,
                builder: (context, snapshot) {
                  final VideoPlayerController? controller = _controller;
                  if (controller == null ||
                      snapshot.connectionState != ConnectionState.done ||
                      !controller.value.isInitialized) {
                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromRGBO(255, 255, 255, 0.2),
                          ),
                        ),
                      ),
                    );
                  }
                  widget.onLoadedChanged?.call(true);
                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _SubmissionPreviewFallback extends StatelessWidget {
  const _SubmissionPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppPalette.depth2, AppPalette.voidColor],
            ),
          ),
        ),
        const PreviewCardBackdrop(),
        Container(color: const Color.fromRGBO(7, 8, 15, 0.18)),
      ],
    );
  }
}

class _ShareAssetVideoCard extends StatefulWidget {
  const _ShareAssetVideoCard({required this.videoPath});

  final String? videoPath;

  @override
  State<_ShareAssetVideoCard> createState() => _ShareAssetVideoCardState();
}

class _ShareAssetVideoCardState extends State<_ShareAssetVideoCard> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  bool _failedToLoad = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant _ShareAssetVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _disposeController();
      _initializeVideo();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _initializeVideo() {
    _failedToLoad = false;
    final String? path = widget.videoPath;
    if (path == null || path.isEmpty) {
      return;
    }
    _controller = createVideoControllerForPath(path);
    if (_controller == null) {
      _failedToLoad = true;
      return;
    }
    _initializeFuture = _controller!.initialize().then((_) async {
      await _controller!.setVolume(0);
      await _controller!.setLooping(true);
      await _controller!.play();
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _failedToLoad = true;
        });
      } else {
        _failedToLoad = true;
      }
    });
  }

  void _disposeController() {
    final VideoPlayerController? controller = _controller;
    _controller = null;
    _initializeFuture = null;
    controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: const Color(0xFF0D1018),
              child: widget.videoPath == null ||
                      widget.videoPath!.isEmpty ||
                      _failedToLoad
                  ? const _SubmissionPreviewFallback()
                  : FutureBuilder<void>(
                      future: _initializeFuture,
                      builder: (context, snapshot) {
                        final VideoPlayerController? controller = _controller;
                        if (controller == null ||
                            snapshot.connectionState != ConnectionState.done ||
                            !controller.value.isInitialized) {
                          return const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color.fromRGBO(255, 255, 255, 0.2),
                                ),
                              ),
                            ),
                          );
                        }
                        return FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        );
                      },
                    ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xAA060810),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFE8002D),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 4, height: 4),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'CULT EIDOS',
                      style: TextStyle(
                        color: Color(0x88FFFFFF),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xAA060810),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                  ),
                ),
                child: const Text(
                  '0.5×',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CueSummaryChip extends StatelessWidget {
  const _CueSummaryChip({required this.cue});

  final SessionCueSummary cue;

  @override
  Widget build(BuildContext context) {
    final bool isPass = cue.state == CueState.pass;
    final Color fill = isPass
        ? const Color(0x1A00875A)
        : const Color(0x1AB86000);
    final Color border = isPass
        ? const Color(0x3300C47A)
        : const Color(0x33E08840);
    final Color foreground = isPass
        ? const Color(0xFF00C47A)
        : const Color(0xFFE08840);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPass ? '✅' : '⚠️',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                cue.label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareAssetActions extends StatelessWidget {
  const _ShareAssetActions({
    required this.session,
    required this.onRecordNext,
  });

  final VisionSessionData session;
  final VoidCallback onRecordNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () async {
              final String shareText =
                  'Just pulled ${session.repCount} reps at ${session.centerName} with Cult Eidos. Form checked. @cultfit';
              final String? path = session.shareableVideoPath;
              if (path != null && path.isNotEmpty) {
                final Uri? uri = Uri.tryParse(path);
                if (kIsWeb && (uri == null || (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')))) {
                  await Share.share(shareText);
                } else {
                  await Share.shareXFiles([XFile(path)], text: shareText);
                }
              } else {
                await Share.share(shareText);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF0F1F7),
              foregroundColor: const Color(0xFF07080F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Share to Reels',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () async {
              final String? path = session.shareableVideoPath;
              if (path == null || path.isEmpty || kIsWeb) {
                return;
              }
              await ImageGallerySaver.saveFile(path);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xAAFFFFFF),
              side: const BorderSide(color: Color(0x22FFFFFF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              'Save to camera roll',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: onRecordNext,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0x33FFFFFF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Record another set →',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _CultAppFeedMockup extends StatelessWidget {
  const _CultAppFeedMockup({
    required this.userName,
    required this.isReady,
    required this.body,
  });

  final String userName;
  final bool isReady;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.depth1.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.glassBorderSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const GlassAvatar(letter: 'P'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$userName just dropped a new form check',
                      style: const TextStyle(
                        color: AppPalette.n50,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Deadlift · Today · Cult app feed',
                      style: TextStyle(
                        color: AppPalette.n400,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isReady)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.violetGlass,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppPalette.violetBorder),
                  ),
                  child: const Text(
                    'SHARE',
                    style: TextStyle(
                      color: AppPalette.violetHighlight,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 0.82,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppPalette.depth2, AppPalette.voidColor],
                      ),
                    ),
                  ),
                  const PreviewCardBackdrop(),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.voidColor.withValues(alpha: 0.46),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppPalette.glassBorderSoft),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isReady ? 'Best rep rendered' : 'Rendering workout clip',
                            style: const TextStyle(
                              color: AppPalette.n50,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isReady
                                ? 'Video ready with clean framing, replay, and share actions inside the Cult app.'
                                : body,
                            style: const TextStyle(
                              color: AppPalette.n200,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: PreviewTag(
                      leadingColor: isReady
                          ? AppPalette.violetBright
                          : AppPalette.redBright,
                      label: isReady ? 'Video ready' : 'Rendering',
                    ),
                  ),
                  if (!isReady)
                    Container(
                      color: AppPalette.voidColor.withValues(alpha: 0.36),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CultAppRecommendationsPanel extends StatelessWidget {
  const _CultAppRecommendationsPanel({required this.isReady});

  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.depth1.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppPalette.glassBorderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'FORM CORRECTION',
                style: TextStyle(
                  color: AppPalette.n500,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              Text(
                isReady ? 'Now visible in Cult app' : 'Syncing coaching notes',
                style: const TextStyle(
                  color: AppPalette.n400,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...kFormRecommendations.asMap().entries.map((entry) {
            final int index = entry.key;
            final FormRecommendation recommendation = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == kFormRecommendations.length - 1 ? 0 : 10,
              ),
              child: _RecommendationTile(
                recommendation: recommendation,
                isReady: isReady,
                isPrimary: index == 0,
              ),
            );
          }),
          if (isReady) ...[
            const SizedBox(height: 12),
            const Text(
              'These recommendations travel with the rendered video so the shareable asset teaches while it celebrates.',
              style: TextStyle(
                color: AppPalette.n300,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.recommendation,
    required this.isReady,
    required this.isPrimary,
  });

  final FormRecommendation recommendation;
  final bool isReady;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isReady ? 1 : 0.64,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppPalette.passGlass
              : AppPalette.glass1.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? AppPalette.passBorder
                : AppPalette.glassBorderSoft,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPrimary ? AppPalette.passBright : AppPalette.glass3,
              ),
              alignment: Alignment.center,
              child: Text(
                isPrimary ? '1' : '•',
                style: TextStyle(
                  color: isPrimary ? AppPalette.voidColor : AppPalette.n200,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title,
                    style: const TextStyle(
                      color: AppPalette.n50,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation.detail,
                    style: const TextStyle(
                      color: AppPalette.n300,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppPalette.glass1,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppPalette.glassBorderSoft),
              ),
              child: Text(
                recommendation.impactLabel,
                style: const TextStyle(
                  color: AppPalette.n400,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordButton extends StatefulWidget {
  const RecordButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _expanded ? 1.05 : 0.82,
        end: _expanded ? 0.82 : 1.05,
      ),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOut,
      onEnd: () {
        if (mounted) {
          setState(() {
            _expanded = !_expanded;
          });
        }
      },
      builder: (context, value, child) {
        return SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: value,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppPalette.glassBorderStrong.withValues(
                        alpha: 0.28,
                      ),
                      width: 1.3,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: 1.12 + ((value - 0.82) * 0.6),
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppPalette.glassBorder.withValues(alpha: 0.22),
                      width: 1.1,
                    ),
                  ),
                ),
              ),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.glass1,
                  border: Border.all(color: AppPalette.glassBorder),
                ),
              ),
              VoidPressable(
                onTap: widget.onPressed,
                borderRadius: 999,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppPalette.n50,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(240, 241, 245, 0.14),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RecordingCameraBackdrop extends StatelessWidget {
  const RecordingCameraBackdrop({
    super.key,
    this.onPoseResult,
  });

  final void Function(CameraPoseResult?, CameraMacOSException?)? onPoseResult;

  @override
  Widget build(BuildContext context) {
    final Widget preview = Theme.of(context).platform == TargetPlatform.macOS
        ? MacOSCameraPreview(onPoseResult: onPoseResult)
        : const SimulatedCameraPreview();

    return Stack(
      fit: StackFit.expand,
      children: [
        preview,
        const Positioned(
          right: 18,
          bottom: 18,
          child: PreviewTag(
            leadingColor: AppPalette.passBright,
            label: 'True orientation',
          ),
        ),
      ],
    );
  }
}

class MacOSCameraPreview extends StatefulWidget {
  const MacOSCameraPreview({
    super.key,
    this.onPoseResult,
  });

  final void Function(CameraPoseResult?, CameraMacOSException?)? onPoseResult;

  @override
  State<MacOSCameraPreview> createState() => _MacOSCameraPreviewState();
}

class _PreferredMacOSCamera {
  const _PreferredMacOSCamera({
    required this.deviceId,
  });

  final String? deviceId;
}

class _CameraSessionConfig {
  const _CameraSessionConfig({
    required this.accessState,
    required this.preferredCamera,
  });

  final _CameraAccessState accessState;
  final _PreferredMacOSCamera preferredCamera;
}

class _MacOSCameraPreviewState extends State<MacOSCameraPreview> {
  static const MethodChannel _cameraChannel = MethodChannel('camera_macos');

  CameraMacOSController? _controller;
  late final Future<_CameraSessionConfig> _cameraSessionFuture;

  @override
  void initState() {
    super.initState();
    _cameraSessionFuture = _prepareCameraSession();
  }

  @override
  void dispose() {
    _controller?.setPoseResultListener(null);
    _controller?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CameraSessionConfig>(
      future: _cameraSessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _CameraBackdropMessage(
            title: 'Opening camera',
            body: 'Starting the camera.',
          );
        }

        final _CameraSessionConfig session =
            snapshot.data ??
            const _CameraSessionConfig(
              accessState: _CameraAccessState.unknown(),
              preferredCamera: _PreferredMacOSCamera(deviceId: null),
            );
        final _CameraAccessState accessState = session.accessState;

        if (!accessState.canOpenCamera) {
          return _CameraBackdropMessage(
            title: 'Camera permission needed',
            body: accessState.message,
            actionLabel: 'Open Camera Settings',
            onAction: _openCameraPreferences,
          );
        }

        return CameraMacOSView(
          deviceId: session.preferredCamera.deviceId,
          fit: BoxFit.cover,
          cameraMode: CameraMacOSMode.photo,
          usePlatformView: true,
          enableAudio: false,
          orientation: CameraOrientation.orientation0deg,
          isVideoMirrored: false,
          onCameraInizialized: (CameraMacOSController controller) {
            _controller ??= controller;
            controller.setPoseResultListener(widget.onPoseResult);
            unawaited(
              controller.setOrientation(CameraOrientation.orientation0deg),
            );
            unawaited(controller.setVideoMirrored(false));
          },
          onCameraLoading: (Object? error) {
            if (error != null) {
              return _CameraBackdropMessage(
                title: 'Camera unavailable',
                body: _cameraErrorMessage(error),
                actionLabel: _looksLikePermissionError(error)
                    ? 'Open Camera Settings'
                    : null,
                onAction: _looksLikePermissionError(error)
                    ? _openCameraPreferences
                    : null,
              );
            }
            return const _CameraBackdropMessage(
              title: 'Opening camera',
              body: 'Starting the camera.',
            );
          },
          onCameraDestroyed: () {
            return const _CameraBackdropMessage(
              title: 'Camera stopped',
              body: 'Return to recording to start the preview again.',
            );
          },
        );
      },
    );
  }

  Future<_CameraSessionConfig> _prepareCameraSession() async {
    final _CameraAccessState accessState = await _prepareCameraAccess();
    if (!accessState.canOpenCamera) {
      return _CameraSessionConfig(
        accessState: accessState,
        preferredCamera: const _PreferredMacOSCamera(deviceId: null),
      );
    }

    final _PreferredMacOSCamera preferredCamera = await _loadPreferredCamera();
    return _CameraSessionConfig(
      accessState: accessState,
      preferredCamera: preferredCamera,
    );
  }

  Future<_CameraAccessState> _prepareCameraAccess() async {
    try {
      final String? status = await _cameraChannel.invokeMethod<String>(
        'cameraAuthorizationStatus',
      );
      switch (status) {
        case 'authorized':
          return const _CameraAccessState.authorized();
        case 'notDetermined':
          final String? requestResult = await _cameraChannel.invokeMethod<String>(
            'requestCameraPermission',
          );
          if (requestResult == 'authorized') {
            return const _CameraAccessState.authorized();
          }
          return _CameraAccessState.denied(
            requestResult == 'restricted'
                ? 'Camera access is restricted on this Mac. Please allow access in System Settings.'
                : 'Camera access was not granted. Open System Settings > Privacy & Security > Camera and allow Cult Vision Kiosk.',
          );
        case 'denied':
          return const _CameraAccessState.denied(
            'Camera access is currently denied. Open System Settings > Privacy & Security > Camera and allow Cult Vision Kiosk.',
          );
        case 'restricted':
          return const _CameraAccessState.denied(
            'Camera access is restricted on this Mac. Please allow access in System Settings.',
          );
        default:
          return const _CameraAccessState.unknown();
      }
    } catch (_) {
      return const _CameraAccessState.unknown();
    }
  }

  Future<_PreferredMacOSCamera> _loadPreferredCamera() async {
    try {
      final List<CameraMacOSDevice> devices = await CameraMacOS.instance
          .listDevices(deviceType: CameraMacOSDeviceType.video);
      if (devices.isEmpty) {
        return const _PreferredMacOSCamera(deviceId: null);
      }
      final List<CameraMacOSDevice> sortedDevices = List<CameraMacOSDevice>.from(
        devices,
      )..sort((a, b) => _cameraPriority(b).compareTo(_cameraPriority(a)));
      return _PreferredMacOSCamera(deviceId: sortedDevices.first.deviceId);
    } catch (_) {
      return const _PreferredMacOSCamera(deviceId: null);
    }
  }

  bool _isFrontFacing(CameraMacOSDevice device) {
    final String name = (device.localizedName ?? '').toLowerCase();
    return name.contains('front') || name.contains('facetime');
  }

  int _cameraPriority(CameraMacOSDevice device) {
    final String name = (device.localizedName ?? '').toLowerCase();
    final bool isBuiltIn = name.contains('built-in');
    if (_isFrontFacing(device) && isBuiltIn) {
      return 4;
    }
    if (_isFrontFacing(device)) {
      return 3;
    }
    if (isBuiltIn) {
      return 2;
    }
    if (name.contains('rear') ||
        name.contains('back') ||
        name.contains('external')) {
      return 1;
    }
    return 0;
  }

  String _cameraErrorMessage(Object error) {
    if (error is CameraMacOSException) {
      if (error.message.isNotEmpty) {
        return error.message;
      }
      if (error.code.isNotEmpty) {
        return error.code;
      }
    }
    return error.toString();
  }

  bool _looksLikePermissionError(Object error) {
    final String message = _cameraErrorMessage(error).toLowerCase();
    return message.contains('permission') ||
        message.contains('not granted') ||
        message.contains('denied');
  }

  Future<void> _openCameraPreferences() async {
    try {
      await _cameraChannel.invokeMethod('openCameraPreferences');
    } catch (_) {}
  }
}

class _CameraAccessState {
  const _CameraAccessState({
    required this.canOpenCamera,
    required this.message,
  });

  const _CameraAccessState.authorized()
      : canOpenCamera = true,
        message = '';

  const _CameraAccessState.denied(this.message) : canOpenCamera = false;

  const _CameraAccessState.unknown()
      : canOpenCamera = true,
        message = '';

  final bool canOpenCamera;
  final String message;
}

class _CameraBackdropMessage extends StatelessWidget {
  const _CameraBackdropMessage({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101525), Color(0xFF090B14)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            backgroundColor: AppPalette.glass3,
            borderColor: AppPalette.glassBorderStrong,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VoidWireframeSkeleton(size: 64),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.n50,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.n300,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 18),
                  VoidPressable(
                    onTap: onAction,
                    borderRadius: 999,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.glass2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppPalette.glassBorder),
                      ),
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(
                          color: AppPalette.n50,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimulatedCameraPreview extends StatelessWidget {
  const SimulatedCameraPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PreviewBackdropPainter(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101525), Color(0xFF090B14)],
          ),
        ),
      ),
    );
  }
}

class PreviewBackdropPainter extends CustomPainter {
  const PreviewBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glowPaint = Paint()
      ..shader =
          const RadialGradient(
            colors: [
              Color.fromRGBO(255, 255, 255, 0.05),
              Color.fromRGBO(255, 255, 255, 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.52, size.height * 0.32),
              radius: size.width * 0.42,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.32),
      size.width * 0.42,
      glowPaint,
    );

    final Paint floorPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppPalette.voidColor.withValues(alpha: 0.78),
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.55,
              size.width,
              size.height * 0.45,
            ),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
      floorPaint,
    );

    final Paint gridPaint = Paint()
      ..color = AppPalette.n50.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double y = size.height * 0.2; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Offset center = Offset(size.width * 0.52, size.height * 0.52);
    final Paint bonePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3
      ..color = AppPalette.red.withValues(alpha: 0.62);
    final Paint jointPaint = Paint()
      ..color = AppPalette.redBright.withValues(alpha: 0.7);

    final Offset head = Offset(center.dx, center.dy - 128);
    final Offset shoulderLeft = Offset(center.dx - 54, center.dy - 72);
    final Offset shoulderRight = Offset(center.dx + 54, center.dy - 72);
    final Offset hipLeft = Offset(center.dx - 32, center.dy);
    final Offset hipRight = Offset(center.dx + 32, center.dy);
    final Offset kneeLeft = Offset(center.dx - 42, center.dy + 76);
    final Offset kneeRight = Offset(center.dx + 40, center.dy + 74);
    final Offset ankleLeft = Offset(center.dx - 46, center.dy + 146);
    final Offset ankleRight = Offset(center.dx + 48, center.dy + 146);
    final Offset handLeft = Offset(center.dx - 88, center.dy - 12);
    final Offset handRight = Offset(center.dx + 88, center.dy - 16);

    canvas.drawCircle(head, 20, bonePaint);
    canvas.drawLine(
      head.translate(0, 20),
      Offset(center.dx, center.dy - 8),
      bonePaint,
    );
    canvas.drawLine(shoulderLeft, shoulderRight, bonePaint);
    canvas.drawLine(shoulderLeft, handLeft, bonePaint);
    canvas.drawLine(shoulderRight, handRight, bonePaint);
    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy + 8),
      bonePaint,
    );
    canvas.drawLine(hipLeft, hipRight, bonePaint);
    canvas.drawLine(hipLeft, kneeLeft, bonePaint);
    canvas.drawLine(hipRight, kneeRight, bonePaint);
    canvas.drawLine(kneeLeft, ankleLeft, bonePaint);
    canvas.drawLine(kneeRight, ankleRight, bonePaint);
    canvas.drawLine(
      Offset(size.width * 0.2, center.dy + 8),
      Offset(size.width * 0.8, center.dy + 8),
      bonePaint,
    );

    for (final Offset point in [
      shoulderLeft,
      shoulderRight,
      hipLeft,
      hipRight,
      kneeLeft,
      kneeRight,
    ]) {
      canvas.drawCircle(point, 5, jointPaint);
    }

    final Paint badgePaint = Paint()
      ..color = AppPalette.glass2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 140, size.height - 74, 116, 30),
        const Radius.circular(999),
      ),
      badgePaint,
    );

    final TextPainter painter = TextPainter(
      text: const TextSpan(
        text: 'SIMULATOR PREVIEW',
        style: TextStyle(
          color: AppPalette.n300,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(size.width - 130, size.height - 66));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RecordingPill extends StatefulWidget {
  const RecordingPill({super.key, required this.timeLabel});

  final String timeLabel;

  @override
  State<RecordingPill> createState() => _RecordingPillState();
}

class _RecordingPillState extends State<RecordingPill> {
  bool _lit = true;

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
      } else {
        setState(() {
          _lit = !_lit;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      borderRadius: 999,
      backgroundColor: AppPalette.redGlass,
      borderColor: AppPalette.redBorder,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _lit
                  ? AppPalette.redBright
                  : AppPalette.redBright.withValues(alpha: 0.3),
              boxShadow: _lit
                  ? const [
                      BoxShadow(
                        color: AppPalette.redBright,
                        blurRadius: 8,
                        spreadRadius: 0.4,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'REC',
            style: TextStyle(
              color: Color(0xFFFF6680),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(width: 7),
          const Text('·', style: TextStyle(color: AppPalette.n600)),
          const SizedBox(width: 7),
          Text(
            widget.timeLabel,
            style: const TextStyle(
              color: AppPalette.n400,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingIntroBanner extends StatelessWidget {
  const _RecordingIntroBanner({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: 18,
      backgroundColor: AppPalette.glass2,
      borderColor: AppPalette.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello $userName',
            style: const TextStyle(
              color: AppPalette.n50,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "Let's get started.",
            style: TextStyle(
              color: AppPalette.n400,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepCounterPill extends StatelessWidget {
  const _RepCounterPill({required this.repCount});

  final int repCount;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 18,
      backgroundColor: AppPalette.glass2,
      borderColor: AppPalette.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPS',
            style: TextStyle(
              color: AppPalette.n500,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            repCount.toString().padLeft(2, '0'),
            style: const TextStyle(
              color: AppPalette.n50,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingWarningBar extends StatelessWidget {
  const _RecordingWarningBar({
    required this.text,
    required this.foreground,
    required this.background,
  });

  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      backgroundColor: background,
      borderColor: Colors.transparent,
      borderRadius: 16,
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _CuePillRow extends StatelessWidget {
  const _CuePillRow({required this.cues});

  final List<SessionCueSummary> cues;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(cues.length, (index) {
        final SessionCueSummary cue = cues[index];
        final bool isMuted = cue.state == CueState.neutral;
        final Color fill = isMuted
            ? const Color.fromRGBO(255, 255, 255, 0.08)
            : cue.state == CueState.pass
                ? AppPalette.passGlass
                : AppPalette.warnGlass;
        final Color textColor = isMuted
            ? const Color.fromRGBO(255, 255, 255, 0.35)
            : cue.state == CueState.pass
                ? AppPalette.passBright
                : AppPalette.warnBright;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == cues.length - 1 ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                cue.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class CueCard extends StatelessWidget {
  const CueCard({
    super.key,
    required this.label,
    required this.state,
    required this.onPressed,
  });

  final String label;
  final CueState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isWarn = state == CueState.warn;
    final bool isPass = state == CueState.pass;

    return VoidPressable(
      onTap: onPressed,
      borderRadius: 18,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        backgroundColor: isWarn
            ? AppPalette.warnGlass
            : isPass
            ? AppPalette.passGlass
            : AppPalette.glass1,
        borderColor: isWarn
            ? AppPalette.warnBorder
            : isPass
            ? AppPalette.passBorder
            : AppPalette.glassBorderSoft,
        child: Column(
          children: [
            Text(
              _iconForState(state, label),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isWarn
                    ? AppPalette.warnBright
                    : isPass
                    ? AppPalette.passBright
                    : AppPalette.n400,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _iconForState(CueState currentState, String cue) {
    if (currentState == CueState.warn) {
      return '⚠';
    }
    if (currentState == CueState.pass) {
      return '✓';
    }
    if (cue == 'Back flat') {
      return '📐';
    }
    if (cue == 'Hip hinge') {
      return '🦵';
    }
    return '🔒';
  }
}

class GlassStopButton extends StatelessWidget {
  const GlassStopButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return VoidPressable(
      onTap: onPressed,
      borderRadius: 999,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppPalette.glass2,
          border: Border.all(color: AppPalette.glassBorder),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.32),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppPalette.n300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class PreviewCardBackdrop extends StatelessWidget {
  const PreviewCardBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PreviewCardPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class PreviewCardPainter extends CustomPainter {
  const PreviewCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppPalette.red.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.28),
              radius: size.width * 0.4,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.28),
      size.width * 0.4,
      glowPaint,
    );

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppPalette.red.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    final Paint dottedPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppPalette.red.withValues(alpha: 0.24)
      ..strokeWidth = 1.4;

    final Offset center = Offset(size.width * 0.5, size.height * 0.52);
    canvas.drawCircle(Offset(center.dx, center.dy - 76), 13, linePaint);
    canvas.drawLine(
      Offset(center.dx, center.dy - 63),
      Offset(center.dx, center.dy - 10),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx - 34, center.dy - 48),
      Offset(center.dx + 34, center.dy - 48),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx - 34, center.dy - 48),
      Offset(center.dx - 48, center.dy - 6),
      linePaint,
    );
    _drawDashedLine(
      canvas,
      Offset(center.dx - 48, center.dy - 6),
      Offset(center.dx - 56, center.dy + 36),
      dottedPaint,
    );
    canvas.drawLine(
      Offset(center.dx + 34, center.dy - 48),
      Offset(center.dx + 48, center.dy - 6),
      linePaint,
    );
    _drawDashedLine(
      canvas,
      Offset(center.dx + 48, center.dy - 6),
      Offset(center.dx + 56, center.dy + 36),
      dottedPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 20, center.dy - 10),
      Offset(center.dx + 20, center.dy - 10),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx - 20, center.dy - 10),
      Offset(center.dx - 28, center.dy + 42),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx - 28, center.dy + 42),
      Offset(center.dx - 32, center.dy + 84),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx + 20, center.dy - 10),
      Offset(center.dx + 28, center.dy + 42),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx + 28, center.dy + 42),
      Offset(center.dx + 32, center.dy + 84),
      linePaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dash = 6;
    final double distance = (p2 - p1).distance;
    final Offset unit = (p2 - p1) / distance;
    double drawn = 0;
    while (drawn < distance) {
      final Offset start = p1 + unit * drawn;
      final double endStep = math.min(drawn + dash, distance);
      final Offset end = p1 + unit * endStep;
      canvas.drawLine(start, end, paint);
      drawn += dash * 1.6;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PreviewTag extends StatelessWidget {
  const PreviewTag({
    super.key,
    required this.leadingColor,
    required this.label,
    this.showDot = true,
  });

  final Color leadingColor;
  final String label;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      borderRadius: 999,
      backgroundColor: const Color.fromRGBO(6, 8, 16, 0.76),
      borderColor: AppPalette.glassBorder,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: leadingColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppPalette.n300,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class SuccessBadge extends StatelessWidget {
  const SuccessBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const VoidAchievementBadge(score: 84);
  }
}

class VoidAchievementBadge extends StatelessWidget {
  const VoidAchievementBadge({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return _AchievementPulse(
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VoidFormScoreRing(score: score, size: 112, showValue: false),
            const VoidWireframeSkeleton(size: 56),
          ],
        ),
      ),
    );
  }
}

class _AchievementPulse extends StatefulWidget {
  const _AchievementPulse({required this.child});

  final Widget child;

  @override
  State<_AchievementPulse> createState() => _AchievementPulseState();
}

class _AchievementPulseState extends State<_AchievementPulse> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _expanded ? 1.15 : 1,
        end: _expanded ? 1 : 1.15,
      ),
      duration: const Duration(milliseconds: 2500),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted) {
          setState(() {
            _expanded = !_expanded;
          });
        }
      },
      builder: (BuildContext context, double value, Widget? child) {
        return Transform.scale(scale: value, child: child);
      },
      child: widget.child,
    );
  }
}

class VoidFormScoreRing extends StatelessWidget {
  const VoidFormScoreRing({
    super.key,
    required this.score,
    this.size = 96,
    this.showValue = true,
  });

  final int score;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final int clampedScore = score.clamp(0, 100).toInt();

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: clampedScore / 100),
        duration: kVoidSlow,
        curve: kVoidEase,
        builder: (BuildContext context, double progress, Widget? child) {
          return CustomPaint(
            painter: _VoidFormScoreRingPainter(progress: progress),
            child: child,
          );
        },
        child: showValue
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$clampedScore',
                      style: const TextStyle(
                        color: AppPalette.n50,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const Text(
                      'FORM',
                      style: TextStyle(
                        color: AppPalette.n500,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }
}

class _VoidFormScoreRingPainter extends CustomPainter {
  const _VoidFormScoreRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.width / 2 - 6;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = AppPalette.violet.withValues(alpha: 0.18);
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = AppPalette.violetBright.withValues(alpha: 0.24);
    final Paint accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [AppPalette.violet, AppPalette.violetBright],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, basePaint);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, glowPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _VoidFormScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class VoidWireframeSkeleton extends StatelessWidget {
  const VoidWireframeSkeleton({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _voidWireframeSvg,
      width: size,
      height: size,
    );
  }
}

const String _voidWireframeSvg = '''
<svg width="120" height="120" viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
  <g stroke="#7B56C2" stroke-opacity="0.35" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
    <circle cx="60" cy="22" r="10.5"/>
    <path d="M60 33V57"/>
    <path d="M42 43H78"/>
    <path d="M42 43L32 67"/>
    <path d="M78 43L88 67"/>
    <path d="M52 57H68"/>
    <path d="M52 57L46 86"/>
    <path d="M68 57L74 86"/>
    <path d="M46 86L41 106"/>
    <path d="M74 86L79 106"/>
    <path d="M32 67L28 92"/>
    <path d="M88 67L92 92"/>
  </g>
</svg>
''';

class VoidSessionScoreCard extends StatelessWidget {
  const VoidSessionScoreCard({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      backgroundColor: AppPalette.violetGlass,
      borderColor: AppPalette.violetBorder,
      borderRadius: 20,
      child: Row(
        children: [
          VoidFormScoreRing(score: score, size: 82),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session score',
                  style: TextStyle(
                    color: AppPalette.n500,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Best rep quality',
                  style: TextStyle(
                    color: AppPalette.n50,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Violet is the achievement accent, so the score ring becomes the visual anchor for this outcome state.',
                  style: TextStyle(
                    color: AppPalette.n300,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = AppPalette.glass2,
    this.borderColor = AppPalette.glassBorder,
    this.borderRadius = 22,
    this.blur = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.35),
                blurRadius: 32,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: VoidPressable(
        onTap: onPressed,
        borderRadius: 24,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: AppPalette.n50,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(240, 241, 247, 0.12),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: AppPalette.voidColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.01,
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppPalette.glass2,
    this.borderColor = AppPalette.glassBorder,
    this.textColor = AppPalette.n100,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: VoidPressable(
        onTap: onPressed,
        borderRadius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.01,
            ),
          ),
        ),
      ),
    );
  }
}

class AppPalette {
  static const Color voidColor = Color(0xFF07080F);
  static const Color depth1 = Color(0xFF0B0D16);
  static const Color depth2 = Color(0xFF0F1120);
  static const Color depth3 = Color(0xFF141728);

  static const Color n50 = Color(0xFFF0F1F7);
  static const Color n100 = Color(0xFFDDDFE8);
  static const Color n200 = Color(0xFFB8BBCC);
  static const Color n300 = Color(0xFF8F95AE);
  static const Color n400 = Color(0xFF656B86);
  static const Color n500 = Color(0xFF474D6A);
  static const Color n600 = Color(0xFF313654);
  static const Color n700 = Color(0xFF242840);
  static const Color n800 = Color(0xFF1A1D2E);
  static const Color n900 = Color(0xFF12141E);

  static const Color glass1 = Color.fromRGBO(255, 255, 255, 0.028);
  static const Color glass2 = Color.fromRGBO(255, 255, 255, 0.052);
  static const Color glass3 = Color.fromRGBO(255, 255, 255, 0.080);
  static const Color glass4 = Color.fromRGBO(255, 255, 255, 0.115);
  static const Color glassBorderSoft = Color.fromRGBO(255, 255, 255, 0.06);
  static const Color glassBorder = Color.fromRGBO(255, 255, 255, 0.10);
  static const Color glassBorderStrong = Color.fromRGBO(255, 255, 255, 0.18);

  static const Color red = Color(0xFFE8002D);
  static const Color redBright = Color(0xFFFF3355);
  static const Color redGlass = Color.fromRGBO(232, 0, 45, 0.08);
  static const Color redBorder = Color.fromRGBO(232, 0, 45, 0.20);

  static const Color warnBright = Color(0xFFE08840);
  static const Color warnGlass = Color.fromRGBO(180, 90, 0, 0.10);
  static const Color warnBorder = Color.fromRGBO(220, 120, 0, 0.25);
  static const Color passBright = Color(0xFF00C47A);
  static const Color passGlass = Color.fromRGBO(0, 110, 70, 0.10);
  static const Color passBorder = Color.fromRGBO(0, 160, 100, 0.25);

  static const Color violet = Color(0xFF7B56C2);
  static const Color violetBright = Color(0xFF9B7AE0);
  static const Color violetHighlight = Color(0xFFC2A8FF);
  static const Color violetGlass = Color.fromRGBO(123, 86, 194, 0.10);
  static const Color violetBorder = Color.fromRGBO(123, 86, 194, 0.22);

  static const Color ember = Color(0xFFD45A1A);
  static const Color emberGlass = Color.fromRGBO(212, 90, 26, 0.10);
  static const Color emberBorder = Color.fromRGBO(212, 90, 26, 0.22);
  static const Color emberHighlight = Color(0xFFF07030);
}
