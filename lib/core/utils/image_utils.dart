import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Returns an [ImageProvider] that handles both HTTP/HTTPS network URLs,
/// local files, and base64 encoded data URIs (data:image/...;base64,...).
/// Returns null if the URL is empty or invalid.
ImageProvider? getAppImageProvider(String? url) {
  if (url == null || url.trim().isEmpty) {
    return null;
  }
  final trimmed = url.trim();
  if (trimmed.startsWith('data:image')) {
    try {
      final commaIndex = trimmed.indexOf(',');
      final base64Data = commaIndex != -1 ? trimmed.substring(commaIndex + 1) : trimmed;
      return MemoryImage(base64Decode(base64Data));
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return null;
    }
  }
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return NetworkImage(trimmed);
  }
  if (!kIsWeb) {
    try {
      final filePath = trimmed.startsWith('file://') ? trimmed.replaceFirst('file://', '') : trimmed;
      final file = File(filePath);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (e) {
      debugPrint('Error loading local file image: $e');
    }
  }
  return null;
}
