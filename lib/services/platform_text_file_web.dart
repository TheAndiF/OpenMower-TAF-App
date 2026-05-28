import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

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
  final bytes = utf8.encode(content);
  final blob = html.Blob(<Object>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<PlatformTextFile?> pickTextFile({
  List<String> allowedExtensions = const <String>['json'],
}) async {
  final completer = Completer<PlatformTextFile?>();
  final accept = allowedExtensions
      .map((extension) => extension.startsWith('.') ? extension : '.$extension')
      .join(',');
  final input = html.FileUploadInputElement()
    ..accept = accept.isEmpty ? 'text/plain,application/json' : '$accept,text/plain,application/json';

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();
    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Datei konnte nicht gelesen werden.'));
      }
    });
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (!completer.isCompleted) {
        if (result is String) {
          completer.complete(PlatformTextFile(name: file.name, content: result));
        } else {
          completer.completeError(Exception('Datei konnte nicht als Text gelesen werden.'));
        }
      }
    });
    reader.readAsText(file);
  });

  input.click();
  return completer.future;
}
