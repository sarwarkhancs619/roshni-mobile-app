import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openPlatformFile({
  required String fileUrl,
  required String fileName,
  required String fileType,
  Uint8List? bytes,
}) async {
  try {
    // 1. Remote HTTP URL
    if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
      return await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
    }

    // 2. Decode data URI if bytes not explicitly passed
    if ((bytes == null || bytes.isEmpty) && fileUrl.startsWith('data:')) {
      try {
        final commaIndex = fileUrl.indexOf(',');
        if (commaIndex != -1) {
          final b64 = fileUrl.substring(commaIndex + 1);
          bytes = base64Decode(b64);
        }
      } catch (_) {}
    }

    // 3. Local file path from file://
    String? filePath;
    if (fileUrl.startsWith('file://')) {
      filePath = fileUrl.replaceFirst('file://', '');
      // On Windows: e.g. /C:/path -> C:/path
      if (Platform.isWindows && filePath.startsWith('/') && filePath.length > 2 && filePath[2] == ':') {
        filePath = filePath.substring(1);
      }
    }

    File? targetFile;
    if (filePath != null && filePath.isNotEmpty) {
      final f = File(filePath);
      if (await f.exists()) {
        targetFile = f;
      }
    }

    // 4. If target file doesn't exist on disk, write bytes to system temp
    if (targetFile == null && bytes != null && bytes.isNotEmpty) {
      try {
        final tempDir = Directory.systemTemp;
        final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final tempFile = File('${tempDir.path}${Platform.pathSeparator}$safeName');
        await tempFile.writeAsBytes(bytes);
        targetFile = tempFile;
      } catch (e) {
        debugPrint('Error writing temp file to open: $e');
      }
    }

    // 5. Open targetFile on native OS
    if (targetFile != null && await targetFile.exists()) {
      if (Platform.isWindows) {
        try {
          final res = await Process.run('cmd', ['/c', 'start', '""', targetFile.path], runInShell: true);
          if (res.exitCode == 0) return true;
        } catch (_) {}
        return await launchUrl(Uri.file(targetFile.path));
      } else if (Platform.isMacOS) {
        try {
          final res = await Process.run('open', [targetFile.path]);
          if (res.exitCode == 0) return true;
        } catch (_) {}
        return await launchUrl(Uri.file(targetFile.path));
      } else if (Platform.isLinux) {
        try {
          final res = await Process.run('xdg-open', [targetFile.path]);
          if (res.exitCode == 0) return true;
        } catch (_) {}
        return await launchUrl(Uri.file(targetFile.path));
      } else {
        // Android / iOS
        return await launchUrl(Uri.file(targetFile.path));
      }
    }
  } catch (e) {
    debugPrint('openPlatformFile IO error: $e');
    return false;
  }

  return false;
}
