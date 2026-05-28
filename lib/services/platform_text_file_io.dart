import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  final directory = await getTemporaryDirectory();
  final file = File(p.join(directory.path, fileName));
  await file.writeAsString(content, encoding: utf8);
  await Share.shareXFiles(
    <XFile>[XFile(file.path, mimeType: mimeType, name: fileName)],
    text: fileName,
  );
}

Future<PlatformTextFile?> pickTextFile({
  List<String> allowedExtensions = const <String>['json'],
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: allowedExtensions.isEmpty ? FileType.any : FileType.custom,
    allowedExtensions: allowedExtensions.isEmpty ? null : allowedExtensions,
    withData: true,
  );

  if (result == null || result.files.isEmpty) {
    return null;
  }

  final picked = result.files.single;
  final String content;
  if (picked.bytes != null) {
    content = utf8.decode(picked.bytes!);
  } else if (picked.path != null) {
    content = await File(picked.path!).readAsString(encoding: utf8);
  } else {
    throw Exception('Datei konnte nicht gelesen werden.');
  }

  return PlatformTextFile(
    name: picked.name,
    content: content,
  );
}
