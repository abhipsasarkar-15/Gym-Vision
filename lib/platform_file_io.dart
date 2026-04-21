import 'dart:io';

Future<void> deleteLocalFileIfExists(String path) async {
  final File file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}

bool canUseLocalFileVideo(String path) => File(path).existsSync();
