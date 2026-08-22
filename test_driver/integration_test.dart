import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver para `flutter drive`: guarda cada screenshot del test en
/// `build/qa-shots/<nombre>.png` (o en QA_SHOTS_DIR si está definido).
Future<void> main() async {
  final dir = Platform.environment['QA_SHOTS_DIR'] ?? 'build/qa-shots';
  await Directory(dir).create(recursive: true);
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('$dir/$name.png');
      await file.writeAsBytes(bytes);
      // ignore: avoid_print
      print('[qa] screenshot → ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
