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
  throw UnsupportedError('Datei-Export wird auf dieser Plattform nicht unterstützt.');
}

Future<PlatformTextFile?> pickTextFile({
  List<String> allowedExtensions = const <String>['json'],
}) async {
  throw UnsupportedError('Datei-Import wird auf dieser Plattform nicht unterstützt.');
}
