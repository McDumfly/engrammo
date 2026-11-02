// Placeholder Firebase config for fresh clones.
// `tool/bootstrap.sh` copies this to lib/firebase_options.dart when the
// real (gitignored) file is missing. With it the app runs local-only:
// main.dart catches the UnsupportedError and skips Firebase.
// Real setup: see FIREBASE_SETUP.md.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'No Firebase config in this clone - running local-only. '
      'See FIREBASE_SETUP.md to connect your own project.',
    );
  }
}
