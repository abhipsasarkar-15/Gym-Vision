import 'platform_file_stub.dart'
    if (dart.library.io) 'platform_file_io.dart' as impl;

Future<void> deleteLocalFileIfExists(String path) {
  return impl.deleteLocalFileIfExists(path);
}

bool canUseLocalFileVideo(String path) {
  return impl.canUseLocalFileVideo(path);
}
