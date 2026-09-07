export 'platform_file_viewer_stub.dart'
    if (dart.library.html) 'platform_file_viewer_web.dart'
    if (dart.library.io) 'platform_file_viewer_io.dart';
