export 'platform_text_file_stub.dart'
    if (dart.library.html) 'platform_text_file_web.dart'
    if (dart.library.io) 'platform_text_file_io.dart';
