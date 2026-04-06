import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Returns the Encryptorium output directory.
/// On web, this throws an error since browsers don't support arbitrary file paths.
Future<Directory> getEncryptoriumDirectory() async {
  if (kIsWeb) {
    // Web doesn't support direct file system access via dart:io
    throw UnsupportedError(
      'File system access via path_provider is not supported on web. '
          'Use browser download APIs instead.',
    );
  }

  final appDir = await getApplicationDocumentsDirectory();
  final encryptoriumDir = Directory('${appDir.path}/encryptorium');

  if (!await encryptoriumDir.exists()) {
    await encryptoriumDir.create(recursive: true);
  }

  return encryptoriumDir;
}

/// Web-safe helper: returns a virtual directory name for display purposes only.
String getWebOutputDirectoryName() {
  return 'downloads/encryptorium';
}