// Web-safe test detection: answers whether this code runs under
// `flutter test` (which sets FLUTTER_TEST=true in the test process).
// Used only to keep decorative infinite loops out of widget tests,
// where a repeating ticker would make pumpAndSettle time out.
import 'test_mode_stub.dart' if (dart.library.io) 'test_mode_io.dart' as impl;

/// True when running inside `flutter test`. Always false on web builds.
bool get isFlutterTest => impl.isFlutterTest;
