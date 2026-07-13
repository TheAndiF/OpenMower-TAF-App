import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class PlatformTextFile {
  const PlatformTextFile({required this.name, required this.content});

  final String name;
  final String content;
}

Future<void> saveTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/plain',
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = web.Blob(
    <web.BlobPart>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

Future<PlatformTextFile?> pickTextFile({
  List<String> allowedExtensions = const <String>['json'],
}) async {
  final completer = Completer<PlatformTextFile?>();
  final accept = allowedExtensions
      .map((extension) => extension.startsWith('.') ? extension : '.$extension')
      .join(',');
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept.isEmpty
        ? 'text/plain,application/json'
        : '$accept,text/plain,application/json';

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.item(0);
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = web.FileReader();
    reader.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;

      // package:web does not expose FileReader.onError as a Dart event stream.
      // A failed read is reported through FileReader.error when loadend fires.
      if (reader.error != null) {
        completer.completeError(Exception('Datei konnte nicht gelesen werden.'));
        return;
      }

      final result = reader.result?.dartify();
      if (result is String) {
        completer.complete(PlatformTextFile(name: file.name, content: result));
      } else {
        completer.completeError(Exception('Datei konnte nicht als Text gelesen werden.'));
      }
    });
    reader.readAsText(file);
  });

  input.click();
  return completer.future;
}
