import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Internet-connection watcher: the app asks for net at startup, and without
/// it the [ConnectivityGate] shows a "Connect to the internet" message.
///
/// The probe has two stages: first Google's 204 check URL, and if that is
/// blocked, any HTTP response from the Meta API address is enough — a
/// response (even 401/404) proves there is a live connection.
class ConnectivityService extends ChangeNotifier {
  bool? _online;
  bool _checking = false;

  @visibleForTesting
  static bool? testOverride;

  /// null = not checked yet, true/false = measured state.
  bool? get online => testOverride ?? _online;

  bool get checking => _checking;

  static Future<bool> probeInternet({
    http.Client? client,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      try {
        final res = await c
            .get(Uri.parse('https://www.gstatic.com/generate_204'))
            .timeout(timeout);
        if (res.statusCode == 204) return true;
      } catch (_) {
        // Blocked or no net — fall through to the Meta-address backup probe.
      }
      try {
        await c.get(Uri.parse('https://api.meta.ai/v1')).timeout(timeout);
        return true;
      } catch (_) {
        return false;
      }
    } finally {
      if (owned) c.close();
    }
  }

  Future<bool> check({http.Client? client}) async {
    final forced = testOverride;
    if (forced != null) {
      _online = forced;
      notifyListeners();
      return forced;
    }
    if (_checking) return _online ?? false;
    _checking = true;
    notifyListeners();
    try {
      _online = await probeInternet(client: client);
      return _online!;
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  @visibleForTesting
  void resetForTest() {
    _online = null;
    _checking = false;
    testOverride = null;
  }
}

final connectivityService = ConnectivityService();
