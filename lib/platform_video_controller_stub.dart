import 'package:video_player/video_player.dart';

VideoPlayerController? createVideoControllerForPath(String path) {
  final Uri? uri = Uri.tryParse(path);
  if (uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return VideoPlayerController.networkUrl(uri);
  }
  return null;
}
