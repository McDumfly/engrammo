import 'dart:io' show Platform;

// The flutter tool sets FLUTTER_TEST=true in the `flutter test` process.
bool get isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';
