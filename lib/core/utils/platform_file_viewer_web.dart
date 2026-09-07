// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> openPlatformFile({
  required String fileUrl,
  required String fileName,
  required String fileType,
  Uint8List? bytes,
}) async {
  try {
    // 1. Decode data URI if bytes were not directly passed
    if ((bytes == null || bytes.isEmpty) && fileUrl.startsWith('data:')) {
      try {
        final comma = fileUrl.indexOf(',');
        if (comma != -1) {
          bytes = base64Decode(fileUrl.substring(comma + 1));
        }
      } catch (_) {}
    }

    String resourceUrl = fileUrl;
    final isPdf = fileType == 'pdf' || fileName.toLowerCase().endsWith('.pdf');
    final isImage = fileType == 'image' ||
        fileName.toLowerCase().endsWith('.jpg') ||
        fileName.toLowerCase().endsWith('.jpeg') ||
        fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.webp');

    // 2. If we have bytes, create a Blob URL for the actual file content
    if (bytes != null && bytes.isNotEmpty) {
      final mime = isPdf
          ? 'application/pdf'
          : (isImage ? 'image/jpeg' : 'application/octet-stream');
      final fileBlob = html.Blob([bytes], mime);
      resourceUrl = html.Url.createObjectUrlFromBlob(fileBlob);
    }

    if (resourceUrl.isEmpty) return false;

    // 3. Build a dedicated viewer HTML page with Title, prominent "Download" button, and embedded viewer
    final viewerHtml = _buildViewerHtml(
      resourceUrl: resourceUrl,
      fileName: fileName,
      isPdf: isPdf,
      isImage: isImage,
    );

    final htmlBlob = html.Blob([viewerHtml], 'text/html');
    final viewerUrl = html.Url.createObjectUrlFromBlob(htmlBlob);

    // 4. Open in a new tab WITHOUT the download attribute so it renders in the browser tab
    final anchor = html.AnchorElement(href: viewerUrl)
      ..target = '_blank'
      ..rel = 'noopener noreferrer';
    anchor.click();

    return true;
  } catch (e) {
    return false;
  }
}

String _buildViewerHtml({
  required String resourceUrl,
  required String fileName,
  required bool isPdf,
  required bool isImage,
}) {
  final escapedTitle = fileName
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String contentElement;
  if (isPdf) {
    contentElement = '<iframe class="content-frame" src="$resourceUrl" title="$escapedTitle"></iframe>';
  } else if (isImage) {
    contentElement = '''
      <div class="image-wrapper">
        <img src="$resourceUrl" alt="$escapedTitle" class="image-content" />
      </div>
    ''';
  } else {
    contentElement = '<iframe class="content-frame" src="$resourceUrl" title="$escapedTitle"></iframe>';
  }

  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$escapedTitle - Roshni RAMS Vault</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body, html { width: 100%; height: 100%; overflow: hidden; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: #0f172a; }
    .header-bar {
      height: 54px;
      background: #1e293b;
      border-bottom: 1px solid #334155;
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 20px;
      color: #f8fafc;
      box-shadow: 0 2px 10px rgba(0,0,0,0.3);
    }
    .title-group {
      display: flex;
      align-items: center;
      gap: 12px;
      overflow: hidden;
    }
    .badge-icon {
      font-size: 20px;
      line-height: 1;
    }
    .doc-title {
      font-size: 15px;
      font-weight: 600;
      color: #f8fafc;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      max-width: 60vw;
    }
    .action-group {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .download-btn {
      background: #2563eb;
      color: #ffffff;
      padding: 8px 18px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      text-decoration: none;
      display: inline-flex;
      align-items: center;
      gap: 8px;
      transition: background 0.15s, transform 0.1s;
    }
    .download-btn:hover {
      background: #1d4ed8;
      transform: translateY(-1px);
    }
    .download-btn svg {
      width: 16px;
      height: 16px;
      fill: currentColor;
    }
    .content-area {
      width: 100%;
      height: calc(100% - 54px);
      display: flex;
      align-items: center;
      justify-content: center;
      background: #334155;
    }
    .content-frame {
      width: 100%;
      height: 100%;
      border: none;
      background: #525659;
    }
    .image-wrapper {
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      overflow: auto;
    }
    .image-content {
      max-width: 95%;
      max-height: 95%;
      object-fit: contain;
      border-radius: 8px;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
    }
  </style>
</head>
<body>
  <header class="header-bar">
    <div class="title-group">
      <span class="badge-icon">${isPdf ? '📄' : (isImage ? '🖼️' : '📎')}</span>
      <h1 class="doc-title">$escapedTitle</h1>
    </div>
    <div class="action-group">
      <a href="$resourceUrl" download="$escapedTitle" class="download-btn">
        <svg viewBox="0 0 16 16"><path d="M.5 9.9a.5.5 0 0 1 .5.5v2.5a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-2.5a.5.5 0 0 1 1 0v2.5a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2v-2.5a.5.5 0 0 1 .5-.5z"/><path d="M7.646 11.854a.5.5 0 0 0 .708 0l3-3a.5.5 0 0 0-.708-.708L8.5 10.293V1.5a.5.5 0 0 0-1 0v8.793L5.354 8.146a.5.5 0 1 0-.708.708l3 3z"/></svg>
        Download Document
      </a>
    </div>
  </header>
  <main class="content-area">
    $contentElement
  </main>
</body>
</html>''';
}
