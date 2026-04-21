import 'package:video_player/video_player.dart';

import 'platform_video_controller_stub.dart'
    if (dart.library.io) 'platform_video_controller_io.dart' as impl;

VideoPlayerController? createVideoControllerForPath(String path) {
  return impl.createVideoControllerForPath(path);
}
