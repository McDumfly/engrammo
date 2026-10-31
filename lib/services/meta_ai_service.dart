import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/claims_policy.dart'
    show levelExplainer, levelFootnote, verdictPromptGuard;
import '../models/dynamic_task.dart';
import '../models/interview.dart' show interviewQuestions;
import '../models/transfer_targets.dart' show transferTargetById;
import '../models/user_goals.dart';
import '../models/memory_verdict.dart';
import '../models/study_recommendation.dart';
import '../models/meta_image.dart';
import '../models/meta_segment.dart';
import '../models/meta_task.dart';
import '../models/palace_drill.dart';
import '../models/validated_tasks.dart'
    show localValidatedTask, paradigmPrompt, specForKind, validateTask;
import 'env_loader.dart';

class MetaCallEntry {
  final String model;
  final String kind;
  final DateTime at;
  final bool success;
  final bool fallback;
  final String note;

  const MetaCallEntry({
    required this.model,
    required this.kind,
    required this.at,
    required this.success,
    required this.fallback,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'model': model,
    'kind': kind,
    'at': at.toIso8601String(),
    'success': success,
    'fallback': fallback,
    'note': note,
  };

  factory MetaCallEntry.fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    return MetaCallEntry(
      model: (json['model'] as String?) ?? 'unknown',
      kind: (json['kind'] as String?) ?? 'task',
      at: at ?? DateTime.fromMillisecondsSinceEpoch(0),
      success: (json['success'] as bool?) ?? false,
      fallback: (json['fallback'] as bool?) ?? true,
      note: (json['note'] as String?) ?? '',
    );
  }
}

class CoachAnswer {
  final String text;
  final bool fallback;
  const CoachAnswer({required this.text, this.fallback = true});
}

class GoalAnalysisAnswer {
  final GoalAnalysis analysis;
  final bool fallback;
  const GoalAnalysisAnswer({required this.analysis, this.fallback = true});
}

class WordBatchAnswer {
  final List<String> words;
  final bool fallback;
  const WordBatchAnswer({required this.words, this.fallback = true});
}

class TranscriptAnswer {
  final String text;
  final bool fallback;
  const TranscriptAnswer({required this.text, this.fallback = true});
}

class WonderPreviewAnswer {
  final List<String> viewpoints;
  final bool fallback;
  const WonderPreviewAnswer({required this.viewpoints, this.fallback = true});
}

class MetaAIService {
  static const String taskModel = 'muse-spark-1.3-contributor';
  static const String imageModel = 'muse-image-1.0';
  static const String segmentModel = 'sam-3.1';
  static const String wonderModel = 'wonder-1.0';
  static const String voiceModel = 'voice-transcribe-1.0';
  static const String glimmerModel = 'glimmer-1.0';
  static const String sparkOpenModel = 'muse-spark-open-1.0';

  static const String defaultBaseUrl = 'https://api.meta.ai/v1';

  static const String _apiKeyEnv = 'MODEL_API_KEY';

  static const String _legacyApiKeyEnv = 'META_API_KEY';

  static const String _baseUrlOverrideEnv = 'META_API_BASE_URL';

  static const _logKey = 'meta_call_log_v1';

  static const _storedKeyKey = 'meta_api_key_v1';

  static final _secureStorage = FlutterSecureStorage();

  @visibleForTesting
  static Map<String, String>? secureStoreForTest;

  static final Map<String, String> _testMemoryStore = {};

  static bool get _useTestMemoryStore {
    try {
      return WidgetsBinding.instance is! WidgetsFlutterBinding;
    } catch (_) {
      return false;
    }
  }

  static Map<String, String>? _memoryStore() {
    if (secureStoreForTest != null) return secureStoreForTest;
    if (_useTestMemoryStore) return _testMemoryStore;
    return null;
  }

  static Future<String?> _secureRead(String key) async {
    final fake = _memoryStore();
    if (fake != null) return fake[key];
    return _secureStorage.read(key: key);
  }

  static Future<void> _secureWrite(String key, String value) async {
    final fake = _memoryStore();
    if (fake != null) {
      fake[key] = value;
      return;
    }
    await _secureStorage.write(key: key, value: value);
  }

  static Future<void> _secureDelete(String key) async {
    final fake = _memoryStore();
    if (fake != null) {
      fake.remove(key);
      return;
    }
    await _secureStorage.delete(key: key);
  }

  static const int logCap = 50;

  static const int httpTimeoutSec = 12;

  static const int imageTimeoutSec = 25;

  static const int coachMaxCompletionTokens = 1000;
  static const int glimmerMaxCompletionTokens = 200;
  static const int taskMaxCompletionTokens = 3000;
  static const int interviewMaxCompletionTokens = 2000;

  static final List<MetaCallEntry> _calls = [];
  static bool _logRestored = false;

  static List<MetaCallEntry> get lastCalls =>
      List<MetaCallEntry>.unmodifiable(_calls);

  /// Session-level image/segment caches: the same palace prompt or image
  /// must not cost a new Muse Image / SAM call every round. Keyed by
  /// [MetaImageRequest.cacheKey] and by image URL. Only successful,
  /// non-fallback results are stored; the cap keeps memory bounded.
  static const int imageCacheCap = 40;
  static final Map<String, MetaImage> _imageCache = {};
  static final Map<String, MetaSegment> _segmentCache = {};

  @visibleForTesting
  static void clearImageCaches() {
    _imageCache.clear();
    _segmentCache.clear();
  }

  static void _storeImage(MetaImageRequest req, MetaImage img) {
    if (img.url.isEmpty || img.fallback) return;
    if (_imageCache.length >= imageCacheCap &&
        !_imageCache.containsKey(req.cacheKey)) {
      _imageCache.remove(_imageCache.keys.first);
    }
    _imageCache[req.cacheKey] = img;
  }

  static void _storeSegment(String imageRef, MetaSegment seg) {
    if (seg.fallback) return;
    if (_segmentCache.length >= imageCacheCap &&
        !_segmentCache.containsKey(imageRef)) {
      _segmentCache.remove(_segmentCache.keys.first);
    }
    _segmentCache[imageRef] = seg;
  }

  static String get apiKey {
    final key = const String.fromEnvironment(_apiKeyEnv, defaultValue: '');
    if (key.isNotEmpty) return key;
    return const String.fromEnvironment(_legacyApiKeyEnv, defaultValue: '');
  }

  static String get baseUrl {
    final override = const String.fromEnvironment(
      _baseUrlOverrideEnv,
      defaultValue: '',
    );
    return override.isNotEmpty ? override : defaultBaseUrl;
  }

  static String resolveBaseUrl([String? override]) {
    final raw = (override ?? baseUrl).trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw StateError(
        'Meta API base URL must be an absolute https URL '
        '(got: "$raw"). Refusing to send the API key over an '
        'insecure channel.',
      );
    }
    return raw;
  }

  static bool get configured => apiKey.isNotEmpty;

  static String get bundledApiKey => EnvLoader.apiKey;

  static Future<bool> hasAnyKey() async {
    if (apiKey.isNotEmpty || EnvLoader.apiKey.isNotEmpty) return true;
    return (await storedApiKey()).isNotEmpty;
  }

  /// True when cloud AI can actually run right now: an API key is on hand
  /// ([hasAnyKey]) AND the player switched cloud consent on ([cloudConsent]).
  /// Mirrors [_liveKey] without an override — the UI gate behind
  /// SAM-as-default messaging (camera room, lesson upgrade).
  static Future<bool> cloudReady() async {
    if (!await hasAnyKey()) return false;
    return cloudConsent();
  }

  static Future<String> storedApiKey() async {
    try {
      final current = (await _secureRead(_storedKeyKey) ?? '').trim();
      if (current.isNotEmpty) return current;
      final prefs = await SharedPreferences.getInstance();
      final legacy = (prefs.getString(_storedKeyKey) ?? '').trim();
      if (legacy.isEmpty) return '';
      await _secureWrite(_storedKeyKey, legacy);
      await prefs.remove(_storedKeyKey);
      return legacy;
    } catch (_) {
      return '';
    }
  }

  static Future<void> setStoredApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await _secureDelete(_storedKeyKey);
    } else {
      await _secureWrite(_storedKeyKey, trimmed);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storedKeyKey);
    } catch (_) {}
  }

  static Future<void> clearStoredApiKey() async {
    try {
      await _secureDelete(_storedKeyKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storedKeyKey);
    } catch (_) {}
  }

  static Future<bool> persistLaunchKeyIfPresent() async {
    try {
      final launch = apiKey.isNotEmpty ? apiKey : EnvLoader.apiKey;
      if (launch.isEmpty) return false;
      if ((await storedApiKey()) == launch) return false;
      await setStoredApiKey(launch);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String> effectiveApiKey({String? override}) async {
    if (override != null && override.trim().isNotEmpty) {
      return override.trim();
    }
    if (apiKey.isNotEmpty) return apiKey;
    if (EnvLoader.apiKey.isNotEmpty) return EnvLoader.apiKey;
    return storedApiKey();
  }

  static Future<String> _resolveKey(String? apiKeyOverride) =>
      effectiveApiKey(override: apiKeyOverride);

  static const _consentKey = 'settings_ai_cloud_consent_v1';

  @visibleForTesting
  static bool? consentForTest;

  static Future<bool> cloudConsent() async {
    final t = consentForTest;
    if (t != null) return t;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_consentKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setCloudConsent(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_consentKey, value);
    } catch (_) {}
  }

  static Future<String> _liveKey(String? apiKeyOverride) async {
    final key = await _resolveKey(apiKeyOverride);
    if (key.isEmpty) return '';
    return (await cloudConsent()) ? key : '';
  }

  static Future<String> _gatedOfflineNote(
    String? apiKeyOverride,
    String tail, [
    String? locale,
  ]) async {
    final code = locale ?? AppLocalizations.localeCode;
    final key = await _resolveKey(apiKeyOverride);
    if (key.isEmpty) {
      return trFor(code, 'ai_note_no_key', {'tail': tail});
    }
    return trFor(code, 'ai_note_consent_off', {'tail': tail});
  }

  static Future<List<MetaCallEntry>> loadLog() async {
    if (_logRestored) return lastCalls;
    _logRestored = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_logKey) ?? const [];
      // Elrontott bejegyzés nem dobhatja el a teljes naplót.
      for (final e in raw) {
        if (e.isEmpty) continue;
        try {
          _calls.add(MetaCallEntry.fromJson(jsonDecode(e) as Map<String, dynamic>));
        } catch (_) {}
      }
      if (_calls.length > logCap) {
        _calls.removeRange(logCap, _calls.length);
      }
    } catch (_) {}
    return lastCalls;
  }

  static Future<void> _log(MetaCallEntry entry) async {
    // Előbb visszaállítjuk a lemezen lévőt, különben az első naplózás
    // törölné az előző indítások bejegyzéseit.
    await loadLog();
    _calls.insert(0, entry);
    if (_calls.length > logCap) {
      _calls.removeRange(logCap, _calls.length);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_logKey, [
        for (final e in _calls.take(logCap)) jsonEncode(e.toJson()),
      ]);
    } catch (_) {}
  }

  static Map<String, String> _headers(String key) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $key',
  };

  @visibleForTesting
  static String paradigmPromptHu(MetaTaskRequest req) => paradigmPrompt(req);

  @visibleForTesting
  static Map<String, dynamic> taskRequestBody(MetaTaskRequest req) {
    final hint = paradigmPrompt(req);
    return {
      'model': taskModel,
      'temperature': 0.2,
      'reasoning_effort': 'low',
      'max_completion_tokens': taskMaxCompletionTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a memory-task stimulus filler. You NEVER invent a '
              'task format: you only fill the stimulus slots of the given '
              'paradigm. Always return a single valid JSON object, no '
              'explanation. Keys: "prompt" (short stimulus title), '
              '"items" (list of strings to show), "stations" (spatial '
              'only: ordered station names matching "items" one by one), '
              '"question", "options" (exactly 4 answer strings), '
              '"correct" (0-based index of the right answer), '
              '"explanation" (one mnemonic tip), "paradigm" (echo the '
              'paradigm id). Direct tone, short sentences.',
        },
        {
          'role': 'user',
          'content':
              'Make one "${req.kind}" memory task, difficulty '
              '${req.difficulty.clamp(1, 5)} on a 1-5 scale. $hint'
              '${req.seed.isEmpty ? '' : 'Seed: ${req.seed}. '}Answer language: English.',
        },
      ],
    };
  }

  @visibleForTesting
  static MetaTask? parseTaskContent(String content, MetaTaskRequest req) {
    try {
      var text = content.trim();
      if (text.startsWith('```')) {
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (start < 0 || end <= start) return null;
        text = text.substring(start, end + 1);
      }
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic>) return null;
      final options = [
        for (final e in (data['options'] as List? ?? const [])) e.toString(),
      ];
      final correct = (data['correct'] as num?)?.toInt() ?? -1;
      final items = [
        for (final e in (data['items'] as List? ?? const [])) e.toString(),
      ];
      final stations = [
        for (final e in (data['stations'] as List? ?? const [])) e.toString(),
      ];
      final spec = specForKind(req.kind);
      final candidate = MetaTask(
        prompt: (data['prompt'] as String?) ?? '',
        items: items,
        question: (data['question'] as String?) ?? '',
        options: options,
        correct: correct,
        explanation: (data['explanation'] as String?) ?? '',
        paradigm: spec.id,
        source: spec.source,
        stations: stations,
        model: taskModel,
        createdAt: DateTime.now(),
        fallback: false,
      );
      if (validateTask(req, candidate).isNotEmpty) return null;
      return candidate;
    } catch (_) {
      return null;
    }
  }

  static String _contentText(Object? content) {
    if (content is String) return content;
    if (content is List) {
      final sb = StringBuffer();
      for (final block in content) {
        if (block is String) {
          sb.write(block);
        } else if (block is Map) {
          final text = block['text'];
          if (text is String) {
            sb.write(text);
          } else if (text is Map && text['value'] is String) {
            sb.write(text['value'] as String);
          }
          final inner = block['content'];
          if (inner is String) sb.write(inner);
        }
      }
      return sb.toString();
    }
    return '';
  }

  static String _finishReason(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final reason = first['finish_reason'];
        if (reason is String && reason.isNotEmpty) return reason;
      }
    }
    return '';
  }

  static String _choicesText(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final text = first['text'];
        if (text is String && text.trim().isNotEmpty) return text;
        final message = first['message'];
        if (message is Map) {
          final content = _contentText(message['content']);
          if (content.trim().isNotEmpty) return content;
        }
        final delta = first['delta'];
        if (delta is Map) {
          final content = _contentText(delta['content']);
          if (content.trim().isNotEmpty) return content;
        }
      }
    }
    final outputText = data['output_text'];
    if (outputText is String && outputText.trim().isNotEmpty) {
      return outputText;
    }
    return '';
  }

  static String _snip(String body, [int max = 180]) {
    var t = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > max) t = '${t.substring(0, max)}…';
    return t;
  }

  static String _emptyChatNote(http.Response res, Map<String, dynamic> data) {
    final reason = _finishReason(data);
    final r = reason.isEmpty ? '' : ' (finish: $reason)';
    return 'HTTP ${res.statusCode} empty/unparseable content$r: '
        '${_snip(res.body)}';
  }

  static Future<http.Response> _postChat(
    http.Client c, {
    required String base,
    required String key,
    required Map<String, dynamic> body,
    required int timeoutSec,
  }) async {
    Future<http.Response> once(Map<String, dynamic> b) => c
        .post(
          Uri.parse('$base/chat/completions'),
          headers: _headers(key),
          body: jsonEncode(b),
        )
        .timeout(Duration(seconds: timeoutSec));
    // Átmeneti hibákra (időtúllépés, kapcsolódás, 429/5xx) egyszer, ~1 mp
    // múlva újrapróbálkozunk; a hívók a második hibát is fallbackre váltják.
    Future<http.Response> onceResilient(Map<String, dynamic> b) async {
      try {
        final res = await once(b);
        if (res.statusCode == 429 || res.statusCode >= 500) {
          await Future.delayed(const Duration(seconds: 1));
          try {
            return await once(b);
          } catch (_) {
            return res;
          }
        }
        return res;
      } on TimeoutException {
        await Future.delayed(const Duration(seconds: 1));
        return once(b);
      } on http.ClientException {
        await Future.delayed(const Duration(seconds: 1));
        return once(b);
      }
    }

    final first = await onceResilient(body);
    if (first.statusCode < 200 || first.statusCode >= 300) return first;
    Map<String, dynamic>? data;
    try {
      final parsed = jsonDecode(first.body);
      if (parsed is Map<String, dynamic>) data = parsed;
    } catch (_) {
      return first;
    }
    if (data == null ||
        _finishReason(data) != 'length' ||
        _choicesText(data).trim().isNotEmpty) {
      return first;
    }
    final retryBody = Map<String, dynamic>.of(body);
    final cap = (body['max_completion_tokens'] as num?)?.toInt() ?? 1000;
    retryBody['max_completion_tokens'] = cap * 2;
    try {
      return await once(retryBody);
    } catch (_) {
      return first;
    }
  }

  static Future<MetaTask> generateTask(
    MetaTaskRequest req, {
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      final t = _localTask(req);
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'task:${req.kind}',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: await _gatedOfflineNote(apiKeyOverride, 'local fallback'),
        ),
      );
      return t;
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: taskRequestBody(req),
        timeoutSec: httpTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final task = parseTaskContent(_choicesText(data), req);
          if (task != null) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'task:${req.kind}',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return task;
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.generateTask fallback: $e');
      final t = _localTask(req);
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'task:${req.kind}',
          at: DateTime.now(),
          success: false,
          fallback: true,
          note: e.toString(),
        ),
      );
      return t;
    } finally {
      if (owned) c.close();
    }
  }

  /// Request body for a pattern-span layout deal: the model fills ONLY
  /// the stimulus slots (which cells light up), never a new format.
  /// Same paradigm as the registry `pattern-span` (Luck & Vogel 1997;
  /// Cowan 2001); grid size is a parameter (3x3 canonical, 4x4 in
  /// practice), exactly [count] distinct cells on 0..[size]-1.
  @visibleForTesting
  static Map<String, dynamic> patternRequestBody({
    required int size,
    required int count,
    String seed = '',
  }) {
    final s = size == 16 ? 16 : 9;
    final c = count.clamp(2, s - 1);
    return {
      'model': taskModel,
      'temperature': 0.2,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': 300,
      'messages': [
        const {
          'role': 'system',
          'content':
              'You are a memory-task stimulus filler for the pattern-span '
              'paradigm (Luck & Vogel 1997; Cowan 2001). You NEVER invent a '
              'task format: you only pick which grid cells light up. Always '
              'return a single valid JSON object with exactly one key: '
              '"cells" (list of distinct cell indices, row by row from 0). '
              'No explanation, no other keys.',
        },
        {
          'role': 'user',
          'content':
              'Deal a pattern-span layout: grid of $s cells (indices '
              '0..${s - 1}), exactly $c distinct lit cells. Spread them so '
              'the lit set reads as one memorable shape, never a full row, '
              'column or block. ${seed.isEmpty ? '' : 'Seed: $seed. '}Answer '
              'with the JSON object only.',
        },
      ],
    };
  }

  /// Parses a dealt layout. Returns null on ANY violation (bad JSON,
  /// wrong count, duplicates, out-of-range cells): there is no silent
  /// repair, because clamping would crown cells the model did not mean.
  @visibleForTesting
  static Set<int>? parsePatternCells(
    String content, {
    required int size,
    required int count,
  }) {
    try {
      final s = size == 16 ? 16 : 9;
      final c = count.clamp(2, s - 1);
      var text = content.trim();
      if (text.startsWith('```')) {
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (start < 0 || end <= start) return null;
        text = text.substring(start, end + 1);
      }
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic>) return null;
      final raw = data['cells'];
      if (raw is! List) return null;
      final cells = <int>{};
      for (final e in raw) {
        final v = (e as num?)?.toInt();
        if (v == null || v < 0 || v >= s) return null;
        cells.add(v);
      }
      if (cells.length != c || raw.length != c) return null;
      return cells;
    } catch (_) {
      return null;
    }
  }

  /// Local pattern deal. Seeded (deterministic) when [seed] is non-empty,
  /// fresh random otherwise. Same slot the live model fills.
  static Set<int> localPatternCells({
    required int size,
    required int count,
    String seed = '',
    Random? random,
  }) {
    final s = size == 16 ? 16 : 9;
    final c = count.clamp(2, s - 1);
    final Random rnd;
    if (random != null) {
      rnd = random;
    } else if (seed.isEmpty) {
      rnd = Random();
    } else {
      var h = 0x811c9dc5;
      for (final cu in seed.codeUnits) {
        h ^= cu;
        h = (h * 0x01000193) & 0xffffffff;
      }
      rnd = Random(h);
    }
    final cells = <int>{};
    while (cells.length < c) {
      cells.add(rnd.nextInt(s));
    }
    return cells;
  }

  /// Lets Muse Spark deal one pattern-span layout with the EXACT cell
  /// count the grid needs. Returns the cells plus whether they came from
  /// the live model (`live: false` = local deal, offline or failed call).
  /// Never throws: failures fall back to [localPatternCells].
  static Future<({Set<int> cells, bool live})> generatePatternCells({
    required int size,
    required int count,
    String seed = '',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final s = size == 16 ? 16 : 9;
    final c = count.clamp(2, s - 1);
    Future<({Set<int> cells, bool live})> local({
      required bool success,
      required String note,
    }) async {
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'pattern',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return (
        cells: localPatternCells(size: s, count: c, seed: seed),
        live: false,
      );
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'local pattern'),
      );
    }
    final cl = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        cl,
        base: base,
        key: key,
        body: patternRequestBody(size: s, count: c, seed: seed),
        timeoutSec: httpTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final cells = parsePatternCells(
            _choicesText(data),
            size: s,
            count: c,
          );
          if (cells != null) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'pattern',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return (cells: cells, live: true);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.generatePatternCells fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) cl.close();
    }
  }

  @visibleForTesting
  static String interviewAnswersText(List<InterviewAnswer> answers) {
    final byId = {for (final q in interviewQuestions) q.id: q};
    final sb = StringBuffer();
    for (final a in answers) {
      final q = byId[a.questionId];
      if (q == null) continue;
      sb.writeln('Q: ${enText(q.promptKey)}');
      if (a.picked != null && a.picked! >= 0 && a.picked! < q.options.length) {
        sb.writeln('Picked: ${enText(q.options[a.picked!].labelKey)}');
      }
      if (a.custom.trim().isNotEmpty) {
        sb.writeln('Custom: ${a.custom.trim()}');
      }
    }
    return sb.toString().trim();
  }

  @visibleForTesting
  static Map<String, dynamic> interviewRequestBody({
    required List<int> scores,
    required String answersText,
    List<int>? tiedTop,
  }) {
    const kinds = 'sensory, working, spatial, visual, episodic, semantic';
    final tieRule = tiedTop == null || tiedTop.isEmpty
        ? 'Decide their dominant memory type from BOTH legs: '
              'test scores first, interview answers to break ties and to '
              'describe their natural strategy. '
        : tiedTop.length == 1
        ? 'The test scores have a CLEAR winner (index ${tiedTop.first}). '
              'You MUST return that index as "dominant"; use the interview '
              'answers only to describe their natural strategy in '
              '"rationale". '
        : 'The test scores are TIED at the top between indices '
              '${tiedTop.join(', ')}. You MUST pick "dominant" from ONLY '
              'those tied indices, using the interview answers to break the '
              'tie. Never pick an index outside the tied set. ';
    return {
      'model': taskModel,
      'temperature': 0.3,
      'reasoning_effort': 'low',
      'max_completion_tokens': interviewMaxCompletionTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a memory coach analyzing a memory-type assessment. '
              'The user finished 6 scored memory probes (0-100 each, kinds: '
              '$kinds) and answered 6 interview questions about HOW they '
              'remember. $tieRule'
              '$verdictPromptGuard '
              'Always return a single '
              'valid JSON object, no explanation. Keys: "dominant" (kind '
              'index 0-5, order: $kinds), "confidence" (0-1), '
              '"rationale" (1-2 direct English sentences for the user).',
        },
        {
          'role': 'user',
          'content':
              'Test scores (sensory, working, spatial, visual, episodic, '
              'semantic): ${scores.join(', ')}.\nInterview answers:\n$answersText',
        },
      ],
    };
  }

  static Future<MemoryVerdict> analyzeMemoryType({
    required List<int> scores,
    required List<InterviewAnswer> answers,
    List<int>? hardHits,
    List<int>? tiedTop,
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    MemoryVerdict local() =>
        heuristicVerdict(scores: scores, answers: answers, hardHits: hardHits);

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'interview',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: await _gatedOfflineNote(apiKeyOverride, 'local scoring'),
        ),
      );
      return local();
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: interviewRequestBody(
          scores: scores,
          answersText: interviewAnswersText(answers),
          tiedTop: tiedTop,
        ),
        timeoutSec: httpTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final verdict = parseVerdictContent(_choicesText(data));
          final outsideTie =
              verdict != null &&
              tiedTop != null &&
              tiedTop.isNotEmpty &&
              !tiedTop.contains(verdict.kind);
          if (verdict != null && !outsideTie) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'interview',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return verdict;
          }
          if (outsideTie) throw StateError('AI verdict outside tied top');
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.analyzeMemoryType fallback: $e');
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'interview',
          at: DateTime.now(),
          success: false,
          fallback: true,
          note: e.toString(),
        ),
      );
      return local();
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> studyRequestBody({
    required List<int> scores,
    required String answersText,
    List<int>? tiedTop,
  }) {
    const kinds = 'sensory, working, spatial, visual, episodic, semantic';
    final tieRule = tiedTop == null || tiedTop.isEmpty
        ? 'Recommend ONE track (0-5) for the user to START learning, from '
              'test scores first and interview answers second. '
        : tiedTop.length == 1
        ? 'The test scores have a CLEAR winner (index ${tiedTop.first}). '
              'You MUST recommend that index as "track"; use the interview '
              'answers only to explain why in "rationale". '
        : 'The test scores are TIED at the top between indices '
              '${tiedTop.join(', ')}. You MUST recommend "track" from ONLY '
              'those tied indices, using the interview answers to break the '
              'tie. Never pick an index outside the tied set. ';
    return {
      'model': taskModel,
      'temperature': 0.3,
      'reasoning_effort': 'low',
      'max_completion_tokens': interviewMaxCompletionTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a memory coach closing a memory-type assessment. '
              'The user finished 6 scored memory probes (0-100 each, kinds: '
              '$kinds) and answered interview questions about HOW they '
              'remember. $tieRule'
              '$verdictPromptGuard '
              'Always return a single '
              'valid JSON object, no explanation. Keys: "track" (kind '
              'index 0-5, order: $kinds), "rationale" (1-2 direct English '
              'sentences for the user: why start here, and which weakest '
              'area to train second).',
        },
        {
          'role': 'user',
          'content':
              'Test scores (sensory, working, spatial, visual, episodic, '
              'semantic): ${scores.join(', ')}.\nInterview answers:\n$answersText',
        },
      ],
    };
  }

  static Future<StudyRecommendation> recommendStudyTrack({
    required List<int> scores,
    required List<InterviewAnswer> answers,
    List<int>? hardHits,
    List<int>? latenciesMs,
    List<int>? tiedTop,
    int? interviewKind,
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    StudyRecommendation local() => heuristicStudyRecommendation(
      scores: scores,
      hardHits: hardHits,
      latenciesMs: latenciesMs,
      interviewKind: interviewKind,
    );

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'study-choice',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: await _gatedOfflineNote(apiKeyOverride, 'local recommendation'),
        ),
      );
      return local();
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: studyRequestBody(
          scores: scores,
          answersText: interviewAnswersText(answers),
          tiedTop: tiedTop,
        ),
        timeoutSec: httpTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final rec = parseStudyRecommendationContent(_choicesText(data));
          final outsideTie =
              rec != null &&
              tiedTop != null &&
              tiedTop.isNotEmpty &&
              !tiedTop.contains(rec.track);
          if (rec != null && !outsideTie) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'study-choice',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return rec;
          }
          if (outsideTie) throw StateError('AI study choice outside tied top');
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.recommendStudyTrack fallback: $e');
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'study-choice',
          at: DateTime.now(),
          success: false,
          fallback: true,
          note: e.toString(),
        ),
      );
      return local();
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> imageRequestBody(MetaImageRequest req) => {
    'model': imageModel,
    'prompt': req.style.isEmpty ? req.prompt : '${req.prompt} (${req.style})',
    'size': req.size,
  };

  @visibleForTesting
  static String parseImageUrl(Map<String, dynamic> data) {
    final list = data['data'];
    if (list is! List || list.isEmpty) return '';
    final first = list.first;
    if (first is! Map<String, dynamic>) return '';
    final url = (first['url'] as String?) ?? '';
    if (url.isNotEmpty) return url;
    final b64 = (first['b64_json'] as String?) ?? '';
    if (b64.isEmpty) return '';
    return 'data:image/png;base64,$b64';
  }

  static Future<MetaImage> generateImage(
    MetaImageRequest req, {
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      await _log(
        MetaCallEntry(
          model: imageModel,
          kind: 'image',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: await _gatedOfflineNote(apiKeyOverride, 'local fallback'),
        ),
      );
      return MetaImage(
        promptHash: req.promptHash,
        cacheKey: req.cacheKey,
        createdAt: DateTime.now(),
      );
    }
    final cached = _imageCache[req.cacheKey];
    if (cached != null) return cached;
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await c
          .post(
            Uri.parse('$base/images/generations'),
            headers: _headers(key),
            body: jsonEncode(imageRequestBody(req)),
          )
          .timeout(const Duration(seconds: imageTimeoutSec));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final url = parseImageUrl(data);
          if (url.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: imageModel,
                kind: 'image',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            final img = MetaImage(
              url: url,
              promptHash: req.promptHash,
              cacheKey: req.cacheKey,
              model: imageModel,
              createdAt: DateTime.now(),
              fallback: false,
            );
            _storeImage(req, img);
            return img;
          }
          throw StateError(
            'HTTP ${res.statusCode} empty/unparseable content: ${_snip(res.body)}',
          );
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.generateImage fallback: $e');
      await _log(
        MetaCallEntry(
          model: imageModel,
          kind: 'image',
          at: DateTime.now(),
          success: false,
          fallback: true,
          note: e.toString(),
        ),
      );
      return MetaImage(
        promptHash: req.promptHash,
        cacheKey: req.cacheKey,
        createdAt: DateTime.now(),
      );
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static bool isImageRef(String ref) {
    final t = ref.trim();
    return t.startsWith('http://') ||
        t.startsWith('https://') ||
        t.startsWith('data:image');
  }

  @visibleForTesting
  static Map<String, dynamic> segmentRequestBody(MetaSegmentRequest req) {
    final hints = [
      for (final p in req.points) 'point [${p.join(', ')}]',
      for (final b in req.boxes) 'box [${b.join(', ')}]',
    ].join('; ');
    final text =
        'Segment the image "${req.imageRef}" (SAM 3.1). '
        '${hints.isEmpty ? 'Name the main objects' : 'Candidates: $hints'} '
        'and return JSON with keys "masks" (list of mask ids) and '
        '"labels" (list of English labels).';
    final ref = req.imageRef.trim();
    if (isImageRef(ref)) {
      return {
        'model': segmentModel,
        'input': [
          {
            'role': 'user',
            'content': [
              {'type': 'input_text', 'text': text},
              {'type': 'input_image', 'image_url': ref},
            ],
          },
        ],
      };
    }
    return {'model': segmentModel, 'input': text};
  }

  @visibleForTesting
  static MetaSegment? parseSegmentOutput(Map<String, dynamic> data) {
    try {
      if (data['masks'] is List || data['labels'] is List) {
        final masks = [
          for (final e in (data['masks'] as List? ?? const [])) e.toString(),
        ];
        final labels = [
          for (final e in (data['labels'] as List? ?? const [])) e.toString(),
        ];
        if (masks.isEmpty && labels.isEmpty) return null;
        return MetaSegment(
          masks: masks,
          labels: labels,
          model: segmentModel,
          createdAt: DateTime.now(),
          fallback: false,
        );
      }
      final texts = StringBuffer();
      final output = data['output'];
      if (output is List) {
        for (final item in output) {
          if (item is! Map<String, dynamic>) continue;
          final content = item['content'];
          if (content is! List) continue;
          for (final block in content) {
            if (block is! Map<String, dynamic>) continue;
            final t = block['text'];
            if (t is String) texts.write(t);
          }
        }
      }
      final raw = texts.toString().trim();
      if (raw.isEmpty) return null;
      var jsonText = raw;
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) jsonText = raw.substring(start, end + 1);
      final parsed = jsonDecode(jsonText);
      if (parsed is! Map<String, dynamic>) return null;
      final masks = [
        for (final e in (parsed['masks'] as List? ?? const [])) e.toString(),
      ];
      final labels = [
        for (final e in (parsed['labels'] as List? ?? const [])) e.toString(),
      ];
      if (masks.isEmpty && labels.isEmpty) return null;
      return MetaSegment(
        masks: masks,
        labels: labels,
        model: segmentModel,
        createdAt: DateTime.now(),
        fallback: false,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<MetaSegment> segment(
    MetaSegmentRequest req, {
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      await _log(
        MetaCallEntry(
          model: segmentModel,
          kind: 'segment',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: await _gatedOfflineNote(apiKeyOverride, 'empty mask'),
        ),
      );
      return MetaSegment(createdAt: DateTime.now());
    }
    if (!isImageRef(req.imageRef)) {
      await _log(
        MetaCallEntry(
          model: segmentModel,
          kind: 'segment',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: 'no real image (only "${req.imageRef}"), local stations',
        ),
      );
      return MetaSegment(createdAt: DateTime.now());
    }
    final cached = _segmentCache[req.imageRef];
    if (cached != null) return cached;
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await c
          .post(
            Uri.parse('$base/responses'),
            headers: _headers(key),
            body: jsonEncode(segmentRequestBody(req)),
          )
          .timeout(const Duration(seconds: httpTimeoutSec));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final seg = parseSegmentOutput(data);
          if (seg != null) {
            await _log(
              MetaCallEntry(
                model: segmentModel,
                kind: 'segment',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            _storeSegment(req.imageRef, seg);
            return seg;
          }
          throw StateError(
            'HTTP ${res.statusCode} empty/unparseable content: ${_snip(res.body)}',
          );
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.segment fallback: $e');
      await _log(
        MetaCallEntry(
          model: segmentModel,
          kind: 'segment',
          at: DateTime.now(),
          success: false,
          fallback: true,
          note: e.toString(),
        ),
      );
      return MetaSegment(createdAt: DateTime.now());
    } finally {
      if (owned) c.close();
    }
  }

  static Future<MetaTask> enrichSpatialTask(
    MetaTask task, {
    required int difficulty,
    required String seed,
    String scene = '',
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final n = drillItemCount(difficulty);
    final count = task.items.isEmpty ? n : task.items.length;
    var out = task;
    if (out.stations.length != count) {
      out = out.copyWith(
        stations: stationsFromLabels(out.stations, seed, count, locale),
      );
    }
    try {
      final route = routeForSeed(seed, locale);
      final img = await generateImage(
        MetaImageRequest(
          prompt: palaceImagePrompt(route, difficulty, locale, scene),
        ),
        client: client,
        apiKeyOverride: apiKeyOverride,
        baseUrlOverride: baseUrlOverride,
      );
      // SAM only ever sees a real picture: the freshly painted palace, or —
      // when generation failed — the task's existing image. A synthetic
      // 'palace:…' ref would short-circuit to an empty fallback, so skip
      // the call instead of logging a phantom segmentation.
      final ref = img.url.isEmpty ? out.imageUrl : img.url;
      final seg = isImageRef(ref)
          ? await segment(
              MetaSegmentRequest(imageRef: ref),
              client: client,
              apiKeyOverride: apiKeyOverride,
              baseUrlOverride: baseUrlOverride,
            )
          : MetaSegment(createdAt: DateTime.now());
      final merged = seg.labels.isEmpty
          ? out.stations
          : stationsFromLabels(seg.labels, seed, count, locale);
      out = out.copyWith(
        stations: merged,
        imageUrl: img.url.isEmpty ? out.imageUrl : img.url,
        samLabels: seg.labels.isEmpty ? out.samLabels : seg.labels,
        samModel: seg.labels.isEmpty ? out.samModel : seg.model,
      );
    } catch (_) {}
    return out;
  }

  static Future<MetaTask> enrichVisualTask(
    MetaTask task, {
    required String seed,
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    var out = task;
    try {
      final prompt = out.items.isEmpty
          ? pictureImagePrompt(sceneForSeed(seed))
          : 'Vivid, detailed illustration showing '
                '${out.items.take(5).join(', ')}, storybook style, '
                'sharp details';
      final img = await generateImage(
        MetaImageRequest(prompt: prompt),
        client: client,
        apiKeyOverride: apiKeyOverride,
        baseUrlOverride: baseUrlOverride,
      );
      if (img.url.isEmpty) {
        // Fresh paint failed: still segment the task's existing picture so
        // SAM stays the default wherever a real image already exists.
        if (isImageRef(out.imageUrl)) {
          final seg = await segment(
            MetaSegmentRequest(imageRef: out.imageUrl),
            client: client,
            apiKeyOverride: apiKeyOverride,
            baseUrlOverride: baseUrlOverride,
          );
          if (seg.labels.isNotEmpty) {
            out = out.copyWith(
              stations: seg.labels,
              samLabels: seg.labels,
              samModel: seg.model,
            );
          }
        }
        return out;
      }
      out = out.copyWith(imageUrl: img.url);
      final seg = await segment(
        MetaSegmentRequest(imageRef: img.url),
        client: client,
        apiKeyOverride: apiKeyOverride,
        baseUrlOverride: baseUrlOverride,
      );
      if (seg.labels.isNotEmpty) {
        out = out.copyWith(
          stations: seg.labels,
          samLabels: seg.labels,
          samModel: seg.model,
        );
      }
    } catch (_) {}
    return out;
  }

  /// Generates a Muse Image illustration plus SAM detail labels for every
  /// [DynamicBlock] that carries an [DynamicBlock.imagePrompt] but no image
  /// yet. Used by the own-material branch of the Palace Builder lessons so
  /// the player's own rooms and routes also get real pictures. Blocks
  /// without a prompt are returned untouched; failures keep the block.
  static Future<DynamicTask> enrichDynamicTask(
    DynamicTask task, {
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    var changed = false;
    final blocks = <DynamicBlock>[];
    for (final b in task.blocks) {
      // Blocks that already carry a picture get SAM labels too: SAM runs
      // wherever a real image exists instead of only on fresh paints.
      if (b.imageUrl.isNotEmpty) {
        if (b.samLabels.isNotEmpty || !isImageRef(b.imageUrl)) {
          blocks.add(b);
          continue;
        }
        try {
          final seg = await segment(
            MetaSegmentRequest(imageRef: b.imageUrl),
            client: client,
            apiKeyOverride: apiKeyOverride,
            baseUrlOverride: baseUrlOverride,
          );
          if (seg.labels.isEmpty) {
            blocks.add(b);
            continue;
          }
          changed = true;
          blocks.add(b.copyWith(samLabels: seg.labels));
        } catch (_) {
          blocks.add(b);
        }
        continue;
      }
      if (b.imagePrompt.trim().isEmpty) {
        blocks.add(b);
        continue;
      }
      try {
        final img = await generateImage(
          MetaImageRequest(prompt: b.imagePrompt),
          client: client,
          apiKeyOverride: apiKeyOverride,
          baseUrlOverride: baseUrlOverride,
        );
        if (img.url.isEmpty) {
          blocks.add(b);
          continue;
        }
        final seg = await segment(
          MetaSegmentRequest(imageRef: img.url),
          client: client,
          apiKeyOverride: apiKeyOverride,
          baseUrlOverride: baseUrlOverride,
        );
        changed = true;
        blocks.add(
          b.copyWith(
            imageUrl: img.url,
            samLabels: seg.labels.isEmpty ? b.samLabels : seg.labels,
          ),
        );
      } catch (_) {
        blocks.add(b);
      }
    }
    if (!changed) return task;
    return task.copyWith(blocks: blocks);
  }

  @visibleForTesting
  static Map<String, dynamic> coachRequestBody({
    required String question,
    String topic = 'general',
    String context = '',
  }) {
    final where = context.trim().isEmpty ? '' : 'The user is here: $context. ';
    return {
      'model': taskModel,
      'temperature': 0.4,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the friendly memory coach inside the Engrammo app. '
              'Explain memory techniques and the current screen in plain '
              'words. Answer in the SAME language the user writes in. '
              'Keep it short: at most 4 sentences or a small list. '
              'Never give medical advice, never diagnose, never promise '
              'grades, IQ gains or job performance. '
              'Help topic: $topic. $where'
              'App facts you may use: every station plays 2-5 short '
              'drills, the very first ones gently with immediate '
              'questions; finishing always earns 1-3 stars; stars unlock '
              'the next stations; daily training builds a streak; '
              'engrams are the single currency and can repair a broken '
              'streak; memory level is the 6 assessment scores (0-100 '
              'each) averaged, then mapped to levels 1-11 as level = '
              'average / 10 + 1 — winning duels and finishing lessons '
              'grow the scores, so practice raises the level.',
        },
        {'role': 'user', 'content': question},
      ],
    };
  }

  static String localCoachAnswer(String question, {String topic = 'general'}) {
    final q = question.toLowerCase();
    if (_isGreeting(q)) {
      return tr('coach_greeting');
    }
    if (q.contains('thank') ||
        q.contains('thx') ||
        q.contains('kösz') ||
        q.contains('koszi') ||
        q.contains('köszi') ||
        q.contains('hálás')) {
      return tr('coach_thanks');
    }
    if (q.contains('unlock') ||
        q.contains('next station') ||
        q.contains('locked') ||
        q.contains('open the next') ||
        q.contains('felold') ||
        q.contains('zár') ||
        q.contains('következő állomás')) {
      return tr('coach_unlock');
    }
    if (q.contains('api key') ||
        q.contains('ai key') ||
        q.contains('model_api_key') ||
        q.contains('kulcs')) {
      return tr('coach_key');
    }
    if (q.contains('theme') ||
        q.contains('dark mode') ||
        q.contains('téma') ||
        q.contains('sötét mód')) {
      return tr('coach_theme');
    }
    if (q.contains('sign out') ||
        q.contains('signout') ||
        q.contains('log out') ||
        q.contains('logout') ||
        q.contains('kijelentkez')) {
      return tr('coach_signout');
    }
    if (q.contains('streak') || q.contains('széria') || q.contains('sorozat')) {
      return tr('coach_streak');
    }
    if (q.contains('engram')) {
      return tr('coach_engram');
    }
    if ((q.contains('star') || q.contains('csillag')) &&
        !q.contains('practice') &&
        !q.contains('game') &&
        !q.contains('gyakorl')) {
      return tr('coach_stars');
    }
    if (q.contains('level') || q.contains('szint')) {
      return '$levelExplainer $levelFootnote';
    }
    if (q.contains('palace') ||
        q.contains('loci') ||
        q.contains('palota') ||
        q.contains('spatial') ||
        q.contains('térbeli')) {
      return tr('coach_palace');
    }
    if (q.contains('chunk') ||
        q.contains('digit') ||
        q.contains('number') ||
        q.contains('szám')) {
      return tr('coach_chunk');
    }
    if (q.contains('delay') ||
        q.contains('later') ||
        q.contains('late') ||
        q.contains('hold') ||
        q.contains('kés') ||
        q.contains('később')) {
      return tr('coach_delay');
    }
    if (q.contains('assess') ||
        q.contains('test') ||
        q.contains('type') ||
        q.contains('dominant') ||
        q.contains('felmér') ||
        q.contains('teszt') ||
        q.contains('típus')) {
      return tr('coach_assess');
    }
    if (q.contains('battle') ||
        q.contains('arena') ||
        q.contains('duel') ||
        q.contains('rating') ||
        q.contains('csata') ||
        q.contains('párbaj')) {
      return tr('coach_battle');
    }
    if (q.contains('benchmark') ||
        q.contains('practice') ||
        q.contains('game') ||
        q.contains('gyakorl') ||
        q.contains('játék')) {
      return tr('coach_benchmark');
    }
    if (q.contains('league') ||
        q.contains('liga') ||
        q.contains('rangsor') ||
        q.contains('rank') ||
        q.contains('climb')) {
      return tr('coach_league');
    }
    if (q.contains('technique') ||
        q.contains('technika') ||
        q.contains('explain') ||
        q.contains('simply') ||
        q.contains('magyaráz')) {
      return tr('coach_technique');
    }
    if (q.contains('example') || q.contains('példa') || q.contains('pl.')) {
      return tr('coach_example');
    }
    if (q.contains('goal') ||
        q.contains('my own') ||
        q.contains('own material') ||
        q.contains('remember this') ||
        q.contains('memorize') ||
        q.contains('cél') ||
        q.contains('celom') ||
        q.contains('célom') ||
        q.contains('megjegyez') ||
        q.contains('saját anyag') ||
        q.contains('sajat anyag')) {
      return tr('coach_goals');
    }
    if (q.contains('what do i do') ||
        q.contains('what to tap') ||
        q.contains('what to do') ||
        q.contains('where do i') ||
        q.contains('how do i start') ||
        q.contains('help') ||
        q.contains('stuck') ||
        q.contains('mit csináljak') ||
        q.contains('elakadt') ||
        q.contains('hogyan tovább') ||
        q.contains('hova koppints')) {
      if (topic == 'path') {
        return tr('coach_doit_path');
      }
      if (topic == 'assessment') {
        return tr('coach_doit_assess');
      }
      return tr('coach_doit_default');
    }
    if (topic == 'lesson') {
      return tr('coach_doit_default');
    }
    if (topic == 'assessment') {
      return tr('coach_assess');
    }
    if (topic == 'path') {
      return tr('coach_topic_path');
    }
    if (topic == 'goals') {
      return tr('coach_topic_goals');
    }
    return tr('coach_fallback');
  }

  static bool _isGreeting(String lower) {
    final t = lower.trim();
    if (t.isEmpty || t.length > 24) return false;
    final core = t
        .replaceAll(RegExp('[^a-z]'), '')
        .replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
    if (core.isEmpty || core.length > 12) return false;
    const greetings = {'he', 'hey', 'hi', 'hello', 'helo', 'yo'};
    return greetings.contains(core);
  }

  static const int coachTimeoutSec = 8;

  static Future<CoachAnswer> askCoach(
    String question, {
    String topic = 'general',
    String context = '',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final q = question.trim();
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: q.isEmpty
            ? localCoachAnswer('help', topic: topic)
            : localCoachAnswer(q, topic: topic),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'coach:$topic',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    if (q.isEmpty) return local(success: true, note: 'empty question');
    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'built-in answer'),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: coachRequestBody(question: q, topic: topic, context: context),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'coach:$topic',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.askCoach fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> teacherRequestBody({
    required String targetId,
    String userMaterial = '',
    String forgotNote = '',
    String locale = 'en',
    String customLabel = '',
    String customStrategy = '',
  }) {
    final target = transferTargetById(targetId);
    var strategy = target?.strategy ?? 'retrieval practice with feedback';
    var label = target?.label ?? 'memory';
    if (isCustomGoalTarget(targetId)) {
      if (customStrategy.trim().isNotEmpty) strategy = customStrategy.trim();
      if (customLabel.trim().isNotEmpty) {
        label = customLabel.trim();
      } else {
        label = 'personal goal';
      }
    }
    final material = userMaterial.trim().isEmpty
        ? 'No user material given; use one everyday example.'
        : 'User material (verbatim, build the example on THIS): '
              '"${userMaterial.trim()}".';
    final forgot = forgotNote.trim().isEmpty
        ? ''
        : 'They say they forgot THIS before: "${forgotNote.trim()}". '
              'Name the likely cause and the fix in one sentence each.';
    return {
      'model': taskModel,
      'temperature': 0.4,
      'reasoning_effort': 'low',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the friendly memory teacher inside the Engrammo app. '
              'Teach ONE strategy for $label in plain words: what to do, '
              'one worked example, then why it works in one sentence. '
              'Answer in the SAME language the user writes in. At most 6 '
              'sentences or a small list. Never give medical advice, never '
              'diagnose, never promise grades, IQ gains or job performance. '
              'Strategy to teach: $strategy $material $forgot',
        },
        {'role': 'user', 'content': 'Teach me how to remember my $label.'},
      ],
    };
  }

  static String localTeacherAnswer(
    String targetId, {
    String userMaterial = '',
    String customLabel = '',
    String customStrategy = '',
    String locale = 'en',
  }) {
    final target = transferTargetById(targetId);
    var strategy =
        target?.strategyIn(locale) ??
        trFor(locale, 'ai_teacher_default_strategy');
    var label =
        target?.labelIn(locale) ?? trFor(locale, 'ai_teacher_default_label');
    if (isCustomGoalTarget(targetId)) {
      if (customStrategy.trim().isNotEmpty) strategy = customStrategy.trim();
      label = customLabel.trim().isEmpty
          ? trFor(locale, 'ai_teacher_default_label')
          : customLabel.trim();
    }
    strategy = strategy.trimRight();
    if (strategy.endsWith('.')) {
      strategy = strategy.substring(0, strategy.length - 1);
    }
    final material = userMaterial.trim().isEmpty
        ? ''
        : trFor(locale, 'ai_teacher_material', {
            'material': userMaterial.trim(),
          });
    return trFor(locale, 'ai_teacher_how', {
      'label': label,
      'strategy': strategy,
      'material': material,
    });
  }

  static Future<CoachAnswer> explainTechnique({
    required String targetId,
    String userMaterial = '',
    String forgotNote = '',
    String locale = 'en',
    String customLabel = '',
    String customStrategy = '',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localTeacherAnswer(
          targetId,
          userMaterial: userMaterial,
          customLabel: customLabel,
          customStrategy: customStrategy,
          locale: locale,
        ),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'teacher:$targetId',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(
          apiKeyOverride,
          'built-in explanation',
          locale,
        ),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: teacherRequestBody(
          targetId: targetId,
          userMaterial: userMaterial,
          forgotNote: forgotNote,
          locale: locale,
          customLabel: customLabel,
          customStrategy: customStrategy,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'teacher:$targetId',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.explainTechnique fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> dynamicTaskRequestBody(DynamicTaskRequest req) {
    return {
      'model': taskModel,
      'temperature': 0.2,
      'reasoning_effort': 'low',
      'max_completion_tokens': taskMaxCompletionTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a memory-task builder inside the Engrammo app. You '
              'NEVER invent a free format: you only fill the fixed UI-block '
              'schema. Always return a single valid JSON object, no '
              'explanation. Keys: "title", "instructions", "blocks" (each '
              'block: "type", "id", "label", optional "hint", "options", '
              '"answer").',
        },
        {'role': 'user', 'content': dynamicTaskPrompt(req)},
      ],
    };
  }

  @visibleForTesting
  static DynamicTask? parseDynamicTaskContent(
    String content,
    DynamicTaskRequest req,
  ) {
    try {
      var text = content.trim();
      if (text.startsWith('```')) {
        final start = text.indexOf('{');
        final end = text.lastIndexOf('}');
        if (start < 0 || end <= start) return null;
        text = text.substring(start, end + 1);
      }
      final data = jsonDecode(text);
      if (data is! Map<String, dynamic>) return null;
      final blocks = <DynamicBlock>[];
      for (final e in (data['blocks'] as List? ?? const [])) {
        if (e is Map<String, dynamic>) blocks.add(DynamicBlock.fromJson(e));
      }
      final candidate = DynamicTask(
        id: 'ai:${req.targetId}:${req.seed}',
        title: (data['title'] as String?) ?? '',
        instructions: (data['instructions'] as String?) ?? '',
        targetId: req.targetId,
        blocks: blocks,
        source: req.effectiveSource,
        model: taskModel,
        createdAt: DateTime.now(),
        fallback: false,
      );
      if (validateDynamicTask(req, candidate).isNotEmpty) return null;
      return candidate;
    } catch (_) {
      return null;
    }
  }

  static Future<DynamicTask> buildDynamicTask(
    DynamicTaskRequest req, {
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      final t = localDynamicTask(req);
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'build:${req.targetId}',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: await _gatedOfflineNote(apiKeyOverride, 'local fallback'),
        ),
      );
      return t;
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: dynamicTaskRequestBody(req),
        timeoutSec: httpTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final task = parseDynamicTaskContent(_choicesText(data), req);
          if (task != null) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'build:${req.targetId}',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return task;
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.buildDynamicTask fallback: $e');
      final t = localDynamicTask(req);
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'build:${req.targetId}',
          at: DateTime.now(),
          success: false,
          fallback: true,
          note: e.toString(),
        ),
      );
      return t;
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> diagnoseRequestBody({
    required String targetId,
    required String forgotNote,
    String locale = 'en',
    String customLabel = '',
    String customStrategy = '',
  }) {
    final target = transferTargetById(targetId);
    var strategy = target?.strategy ?? 'retrieval practice with feedback';
    var label = target?.label ?? 'memory';
    if (isCustomGoalTarget(targetId)) {
      if (customStrategy.trim().isNotEmpty) strategy = customStrategy.trim();
      if (customLabel.trim().isNotEmpty) {
        label = customLabel.trim();
      } else {
        label = 'personal goal';
      }
    }
    return {
      'model': taskModel,
      'temperature': 0.4,
      'reasoning_effort': 'low',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the friendly memory coach inside the Engrammo app. '
              'The user could not remember THIS about $label: '
              '"$forgotNote". In at most 4 sentences: name the most likely '
              'cause (missed encoding, interference, no cue, no review), '
              'then give ONE concrete fix using this strategy: $strategy '
              'Answer in the SAME language the user writes in. '
              '$verdictPromptGuard',
        },
        {'role': 'user', 'content': 'I could not remember: $forgotNote'},
      ],
    };
  }

  static String localDiagnoseAnswer(
    String targetId,
    String forgotNote, {
    String customStrategy = '',
    String locale = 'en',
  }) {
    final what = forgotNote.trim().isEmpty
        ? trFor(locale, 'ai_diagnose_what')
        : '"${forgotNote.trim()}"';
    if (isCustomGoalTarget(targetId) && customStrategy.trim().isNotEmpty) {
      return trFor(locale, 'ai_diagnose_custom', {
        'what': what,
        'strategy': customStrategy.trim(),
      });
    }
    switch (targetId) {
      case 'names':
      case 'faces':
        return trFor(locale, 'ai_diagnose_names', {'what': what});
      case 'numbers-codes':
      case 'phone-numbers':
      case 'birthdays':
      case 'years-dates':
        return trFor(locale, 'ai_diagnose_numbers', {'what': what});
      case 'deadlines':
      case 'todos-errands':
        return trFor(locale, 'ai_diagnose_deadlines', {'what': what});
      case 'poems-verses':
        return trFor(locale, 'ai_diagnose_poems', {'what': what});
      case 'whole-day':
        return trFor(locale, 'ai_diagnose_wholeday', {'what': what});
      default:
        return trFor(locale, 'ai_diagnose_default', {'what': what});
    }
  }

  static Future<CoachAnswer> diagnoseForgetting({
    required String targetId,
    required String forgotNote,
    String locale = 'en',
    String customLabel = '',
    String customStrategy = '',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localDiagnoseAnswer(
          targetId,
          forgotNote,
          customStrategy: customStrategy,
          locale: locale,
        ),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'diagnose:$targetId',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    if (forgotNote.trim().isEmpty) {
      return local(success: true, note: 'empty description');
    }
    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(
          apiKeyOverride,
          'built-in diagnose',
          locale,
        ),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: diagnoseRequestBody(
          targetId: targetId,
          forgotNote: forgotNote.trim(),
          locale: locale,
          customLabel: customLabel,
          customStrategy: customStrategy,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'diagnose:$targetId',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.diagnoseForgetting fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> goalAnalysisRequestBody({
    required String title,
    String details = '',
    String material = '',
    String locale = 'en',
  }) {
    return {
      'model': taskModel,
      'temperature': 0.2,
      'reasoning_effort': 'low',
      'max_completion_tokens': interviewMaxCompletionTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a memory-science classifier inside the Engrammo app. '
              'You NEVER invent a procedure: you only map the wish onto the '
              'given tracks, strategies, and paradigm ids. Always return a '
              'single valid JSON object, no explanation. Keys: "track", '
              '"strategy", "paradigms", "source", "plan", "difficulty". '
              '$verdictPromptGuard',
        },
        {
          'role': 'user',
          'content': goalAnalysisPrompt(
            title: title,
            details: details,
            material: material,
            locale: locale,
          ),
        },
      ],
    };
  }

  static Future<GoalAnalysisAnswer> analyzeGoal({
    required String title,
    String details = '',
    String material = '',
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<GoalAnalysisAnswer> local({required bool success, String note = ''}) async {
      final answer = GoalAnalysisAnswer(
        analysis: localGoalAnalysis(
          title: title,
          details: details,
          material: material,
          locale: locale,
        ),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'goal:analyze',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    if (title.trim().isEmpty) {
      return local(success: true, note: 'empty title');
    }
    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'offline match', locale),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: goalAnalysisRequestBody(
          title: title,
          details: details,
          material: material,
          locale: locale,
        ),
        timeoutSec: httpTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final analysis = parseGoalAnalysisContent(_choicesText(data));
          if (analysis != null) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'goal:analyze',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return GoalAnalysisAnswer(analysis: analysis, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.analyzeGoal fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  static MetaTask _localTask(MetaTaskRequest req) => localValidatedTask(req);

  @visibleForTesting
  static Map<String, dynamic> recapRequestBody({
    required int correct,
    required int total,
    required String trackLabel,
    String locale = 'en',
  }) {
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    return {
      'model': taskModel,
      'temperature': 0.5,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the friendly memory coach inside the Engrammo app. '
              'The user just finished a $trackLabel session: $correct correct '
              'out of $total. In at most 3 short sentences: celebrate the '
              'ratio honestly, name the most likely cause of the misses (if '
              'any), and give ONE concrete next step (what to practice, when '
              'to recall again). Answer in $lang. Never give medical advice, '
              'never diagnose, never promise grades, IQ gains or job '
              'performance.',
        },
        {
          'role': 'user',
          'content': 'How did I do: $correct of $total on $trackLabel?',
        },
      ],
    };
  }

  static String localSessionRecap({
    required int correct,
    required int total,
    required String trackLabel,
    String locale = 'en',
  }) {
    final key = total <= 0 || correct >= total
        ? 'ai_recap_good'
        : correct * 2 >= total
        ? 'ai_recap_mid'
        : 'ai_recap_low';
    return trFor(locale, key, {
      'correct': correct,
      'total': total,
      'track': trackLabel,
    });
  }

  static Future<CoachAnswer> sessionRecap({
    required int correct,
    required int total,
    required String trackLabel,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localSessionRecap(
          correct: correct,
          total: total,
          trackLabel: trackLabel,
          locale: locale,
        ),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'recap',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'built-in recap', locale),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: recapRequestBody(
          correct: correct,
          total: total,
          trackLabel: trackLabel,
          locale: locale,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'recap',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.sessionRecap fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> practiceTipRequestBody({
    required String gameId,
    required int level,
    String locale = 'en',
  }) {
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    return {
      'model': taskModel,
      'temperature': 0.5,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the friendly memory coach inside the Engrammo app. '
              'The user just played the "$gameId" memory practice game and '
              'reached level $level. Give ONE concrete, game-specific '
              'technique tip for the next round, in at most 2 short '
              'sentences. Answer in $lang. Never give medical advice, never '
              'diagnose, never promise grades, IQ gains or job performance.',
        },
        {'role': 'user', 'content': 'One tip for "$gameId" at level $level?'},
      ],
    };
  }

  static String localPracticeTip(
    String gameId,
    int level, [
    String locale = 'en',
  ]) {
    const known = {
      'sequence',
      'number',
      'verbal',
      'visual',
      'order',
      'spatial',
    };
    final key = known.contains(gameId) ? 'ai_tip_$gameId' : 'ai_tip_default';
    return trFor(locale, key, {'n': level});
  }

  static Future<CoachAnswer> practiceTip({
    required String gameId,
    required int level,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localPracticeTip(gameId, level, locale),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'tip:$gameId',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'built-in tip', locale),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: practiceTipRequestBody(
          gameId: gameId,
          level: level,
          locale: locale,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'tip:$gameId',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.practiceTip fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> duelHypeRequestBody({
    required String foeName,
    required String kindLabel,
    String locale = 'en',
  }) {
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    return {
      'model': taskModel,
      'temperature': 0.7,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the hype announcer of the Engrammo memory arena. '
              'The user is about to duel "$foeName" in $kindLabel memory. '
              'Write ONE short, playful hype line (at most 2 sentences) that '
              'names the foe and fires the user up. Answer in $lang. Never '
              'give medical advice, never diagnose, never promise grades, '
              'IQ gains or job performance.',
        },
        {
          'role': 'user',
          'content': 'Hype me up against "$foeName" ($kindLabel)!',
        },
      ],
    };
  }

  static String localDuelHype(
    String foeName,
    String kindLabel, [
    String locale = 'en',
  ]) {
    return trFor(locale, 'duel_hype_default', {
      'foe': foeName,
      'kind': kindLabel,
    });
  }

  static Future<CoachAnswer> duelHype({
    required String foeName,
    required String kindLabel,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localDuelHype(foeName, kindLabel, locale),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'hype',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'built-in hype', locale),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: duelHypeRequestBody(
          foeName: foeName,
          kindLabel: kindLabel,
          locale: locale,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'hype',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.duelHype fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> duelRoundRequestBody({
    required String paradigm,
    required bool correct,
    String locale = 'en',
  }) {
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    final outcome = correct ? 'answered correctly' : 'missed the answer';
    return {
      'model': taskModel,
      'temperature': 0.5,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the commentator of the Engrammo memory arena. The user '
              'just $outcome on a $paradigm round. Write ONE short ringside '
              'line (at most 2 sentences): celebrate a hit with one '
              'technique cue for the next round, or soften a miss with one '
              'concrete fix. Answer in $lang. Never give medical advice, '
              'never diagnose, never promise grades, IQ gains or job '
              'performance.',
        },
        {'role': 'user', 'content': 'One line on this $paradigm round?'},
      ],
    };
  }

  static String localDuelRound(bool correct, [String locale = 'en']) {
    return trFor(locale, correct ? 'duel_round_good' : 'duel_round_miss');
  }

  static Future<CoachAnswer> duelRoundComment({
    required String paradigm,
    required bool correct,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localDuelRound(correct, locale),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'round',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(
          apiKeyOverride,
          'built-in round note',
          locale,
        ),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: duelRoundRequestBody(
          paradigm: paradigm,
          correct: correct,
          locale: locale,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'round',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.duelRoundComment fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> duelScoutRequestBody({
    required String kindLabel,
    required int rating,
    required int wins,
    required int matches,
    String locale = 'en',
  }) {
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    return {
      'model': taskModel,
      'temperature': 0.5,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the scout of the Engrammo memory arena. The user '
              '(rating $rating, $wins wins in $matches duels) is about to '
              'queue for a $kindLabel duel. Write ONE short briefing (at '
              'most 2 sentences): one $kindLabel-specific technique cue plus '
              'one honest nudge based on their record. Answer in $lang. '
              'Never give medical advice, never diagnose, never promise '
              'grades, IQ gains or job performance.',
        },
        {'role': 'user', 'content': 'Scout my next $kindLabel duel!'},
      ],
    };
  }

  static String localDuelScout({
    required String kindLabel,
    required int wins,
    required int matches,
    String locale = 'en',
  }) {
    if (matches <= 0) {
      return trFor(locale, 'duel_scout_first', {'kind': kindLabel});
    }
    return trFor(locale, 'duel_scout_default', {
      'kind': kindLabel,
      'w': wins,
      'm': matches,
    });
  }

  static Future<CoachAnswer> duelScout({
    required String kindLabel,
    required int rating,
    required int wins,
    required int matches,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localDuelScout(
          kindLabel: kindLabel,
          wins: wins,
          matches: matches,
          locale: locale,
        ),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'scout',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'built-in scout', locale),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: duelScoutRequestBody(
          kindLabel: kindLabel,
          rating: rating,
          wins: wins,
          matches: matches,
          locale: locale,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'scout',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.duelScout fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> wordBatchRequestBody({
    required int count,
    List<String> avoid = const [],
    String locale = 'en',
  }) {
    final n = count.clamp(1, 24);
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    final avoidLine = avoid.isEmpty
        ? ''
        : 'Never repeat any of these: ${avoid.take(60).join(', ')}.';
    return {
      'model': taskModel,
      'temperature': 0.9,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a word-list filler inside the Engrammo memory app. '
              'Always return a single valid JSON object, no explanation. '
              'Key: "words" (a list of exactly $n single-word, everyday '
              'concrete nouns a child knows — apple, bridge, lamp — no '
              'proper nouns, no repeats, no multi-word entries). '
              'Answer language: $lang. $avoidLine',
        },
        {'role': 'user', 'content': 'Give exactly $n fresh $lang nouns.'},
      ],
    };
  }

  /// Parses a word batch from model output. Accepts `{"words": [...]}` or
  /// a bare `[...]`, with or without code fences. Drops multi-word,
  /// too-short, too-long and duplicated entries.
  @visibleForTesting
  static List<String> parseWordBatch(String content, {int max = 24}) {
    try {
      var text = content.trim();
      if (text.startsWith('```')) {
        final start = text.indexOf('[');
        final brace = text.indexOf('{');
        int from = -1;
        int to = -1;
        if (brace >= 0 && (brace < start || start < 0)) {
          from = brace;
          to = text.lastIndexOf('}');
        } else if (start >= 0) {
          from = start;
          to = text.lastIndexOf(']');
        }
        if (from < 0 || to <= from) return const [];
        text = text.substring(from, to + 1);
      }
      final data = jsonDecode(text);
      final raw = data is List
          ? data
          : data is Map<String, dynamic>
          ? (data['words'] as List? ?? const [])
          : const [];
      final seen = <String>{};
      final out = <String>[];
      for (final e in raw) {
        final w = e.toString().trim();
        if (w.length < 2 || w.length > 24) continue;
        if (w.contains(RegExp(r'\s'))) continue;
        if (!seen.add(w.toLowerCase())) continue;
        out.add(w);
        if (out.length >= max.clamp(1, 48)) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Fresh words for the verbal game, straight from Muse Spark. Never
  /// throws: offline it returns local nouns the player has not seen yet.
  static Future<WordBatchAnswer> fetchWordBatch({
    required int count,
    List<String> avoid = const [],
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<WordBatchAnswer> local({required bool success, String note = ''}) async {
      final banned = {for (final w in avoid) w.trim().toLowerCase()};
      final pool = [
        for (final w in allConcreteNounsFor(locale))
          if (w.trim().length >= 2 &&
              w.trim().length <= 24 &&
              !w.contains(' ') &&
              !banned.contains(w.trim().toLowerCase()))
            w.trim(),
      ]..shuffle();
      final answer = WordBatchAnswer(
        words: pool.take(count.clamp(1, 24)).toList(),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'words',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'local nouns', locale),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: wordBatchRequestBody(count: count, avoid: avoid, locale: locale),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final words = parseWordBatch(_choicesText(data));
          if (words.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'words',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return WordBatchAnswer(words: words, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.fetchWordBatch fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> gameRecapRequestBody({
    required String gameId,
    required int score,
    required int best,
    String locale = 'en',
  }) {
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    return {
      'model': taskModel,
      'temperature': 0.5,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the friendly memory coach inside the Engrammo app. '
              'The user just finished the "$gameId" practice game with '
              'score $score (personal best $best). In at most 3 short '
              'sentences: judge the run honestly against the best, name '
              'the most likely cause of the misses (if any), and give ONE '
              'concrete next step. Answer in $lang. Never give medical '
              'advice, never diagnose, never promise grades, IQ gains or '
              'job performance.',
        },
        {
          'role': 'user',
          'content': 'Verdict on my "$gameId" run: $score (best $best)?',
        },
      ],
    };
  }

  static String localGameRecap({
    required String gameId,
    required int score,
    required int best,
    String locale = 'en',
  }) {
    final key = score > 0 && score >= best
        ? 'ai_verdict_good'
        : score * 2 >= best && best > 0
        ? 'ai_verdict_mid'
        : 'ai_verdict_low';
    return trFor(locale, key, {'game': gameId, 'score': score, 'best': best});
  }

  /// End-of-run verdict from the text model (Muse Spark). Never throws:
  /// offline it returns the built-in verdict template.
  static Future<CoachAnswer> gameRecap({
    required String gameId,
    required int score,
    required int best,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localGameRecap(
          gameId: gameId,
          score: score,
          best: best,
          locale: locale,
        ),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'verdict:$gameId',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(
          apiKeyOverride,
          'built-in verdict',
          locale,
        ),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: gameRecapRequestBody(
          gameId: gameId,
          score: score,
          best: best,
          locale: locale,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: taskModel,
                kind: 'verdict:$gameId',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.gameRecap fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> wonderPreviewRequestBody({
    required String route,
    required List<String> stations,
    String locale = 'en',
  }) {
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    return {
      'model': wonderModel,
      'temperature': 0.7,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the Wonder world-model inside the Engrammo memory app. '
              'The player walks a memory palace called "$route" with these '
              'stations in order: ${stations.join(', ')}. Always return a '
              'single valid JSON object, no explanation. Key: "viewpoints" '
              '(a list of exactly ${stations.length} short first-person '
              'viewpoint captions, one per station in walking order, each '
              'at most 10 words). Answer language: $lang.',
        },
        {'role': 'user', 'content': 'Preview my walk through "$route".'},
      ],
    };
  }

  /// Parses Wonder viewpoints. Accepts `{"viewpoints": [...]}` or a bare
  /// `[...]`, with or without code fences. Drops empty entries.
  @visibleForTesting
  static List<String> parseWonderPreview(String content, {int max = 10}) {
    try {
      var text = content.trim();
      if (text.startsWith('```')) {
        final start = text.indexOf('[');
        final brace = text.indexOf('{');
        int from = -1;
        int to = -1;
        if (brace >= 0 && (brace < start || start < 0)) {
          from = brace;
          to = text.lastIndexOf('}');
        } else if (start >= 0) {
          from = start;
          to = text.lastIndexOf(']');
        }
        if (from < 0 || to <= from) return const [];
        text = text.substring(from, to + 1);
      }
      final data = jsonDecode(text);
      final raw = data is List
          ? data
          : data is Map<String, dynamic>
          ? (data['viewpoints'] as List? ?? const [])
          : const [];
      final out = <String>[];
      for (final e in raw) {
        final v = e.toString().trim();
        if (v.isEmpty) continue;
        out.add(v);
        if (out.length >= max.clamp(1, 12)) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static String localWonderCaption(String station, [String locale = 'en']) =>
      trFor(locale, 'wonder_fallback_view', {'station': station});

  /// Ordered Wonder viewpoints for a palace walk. Never throws: offline
  /// it returns one local caption per station. A live answer is only
  /// accepted when it covers every station, so captions can never
  /// misalign with the walk.
  static Future<WonderPreviewAnswer> wonderRoutePreview({
    required String route,
    required List<String> stations,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<WonderPreviewAnswer> local({required bool success, String note = ''}) async {
      final answer = WonderPreviewAnswer(
        viewpoints: [for (final s in stations) localWonderCaption(s, locale)],
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: wonderModel,
          kind: 'wonder:route',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(
          apiKeyOverride,
          'local viewpoints',
          locale,
        ),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: wonderPreviewRequestBody(
          route: route,
          stations: stations,
          locale: locale,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final views = parseWonderPreview(_choicesText(data));
          if (views.length == stations.length && views.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: wonderModel,
                kind: 'wonder:route',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return WonderPreviewAnswer(viewpoints: views, fallback: false);
          }
          throw StateError(
            'Wonder returned ${views.length} viewpoints '
            'for ${stations.length} stations',
          );
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.wonderRoutePreview fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static bool isAudioRef(String ref) => ref.trim().startsWith('data:audio');

  @visibleForTesting
  static Map<String, dynamic> transcribeRequestBody({
    required String audioDataUrl,
    String locale = 'en',
  }) => {
    'model': voiceModel,
    'audio': audioDataUrl,
    'language': locale == 'hu' ? 'hu' : 'en',
  };

  @visibleForTesting
  static String parseTranscript(Map<String, dynamic> data) =>
      (data['text'] as String? ?? '').trim();

  /// Transcribes a short voice answer with Voice Transcribe. Never throws
  /// and never invents speech: without audio, key, consent or a usable
  /// answer it returns empty text with the fallback flag set.
  static Future<TranscriptAnswer> transcribe({
    required String audioDataUrl,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<TranscriptAnswer> local({required bool success, String note = ''}) async {
      await _log(
        MetaCallEntry(
          model: voiceModel,
          kind: 'voice',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return const TranscriptAnswer(text: '', fallback: true);
    }

    if (!isAudioRef(audioDataUrl)) {
      return local(success: true, note: 'no audio payload');
    }
    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(
          apiKeyOverride,
          'empty transcript',
          locale,
        ),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await c
          .post(
            Uri.parse('$base/audio/transcriptions'),
            headers: _headers(key),
            body: jsonEncode(
              transcribeRequestBody(audioDataUrl: audioDataUrl, locale: locale),
            ),
          )
          .timeout(const Duration(seconds: httpTimeoutSec));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = parseTranscript(data);
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: voiceModel,
                kind: 'voice',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return TranscriptAnswer(text: text, fallback: false);
          }
          throw StateError(
            'HTTP ${res.statusCode} empty transcript: ${_snip(res.body)}',
          );
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.transcribe fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> glimmerTakeRequestBody({
    required String gameId,
    required int score,
    required int best,
    String locale = 'en',
  }) {
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    return {
      'model': glimmerModel,
      'temperature': 0.6,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': glimmerMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are Glimmer, the instant memory-coach inside the Engrammo '
              'app. The user scored $score (personal best $best) in the '
              '"$gameId" practice game. Reply with ONE punchy sentence, at '
              'most 15 words. Answer in $lang. Never give medical advice, '
              'never diagnose, never promise grades, IQ gains or job '
              'performance.',
        },
        {'role': 'user', 'content': 'One line on $score (best $best)?'},
      ],
    };
  }

  static String localGlimmerTake({
    required int score,
    required int best,
    String locale = 'en',
  }) {
    final key = score > 0 && score >= best
        ? 'ai_glimmer_good'
        : score * 2 >= best && best > 0
        ? 'ai_glimmer_mid'
        : 'ai_glimmer_low';
    return trFor(locale, key, {'score': score});
  }

  /// Glimmer's instant one-line take on a finished run. Never throws:
  /// offline it returns the built-in one-liner.
  static Future<CoachAnswer> glimmerTake({
    required String gameId,
    required int score,
    required int best,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localGlimmerTake(score: score, best: best, locale: locale),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: glimmerModel,
          kind: 'glimmer:$gameId',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'built-in take', locale),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: glimmerTakeRequestBody(
          gameId: gameId,
          score: score,
          best: best,
          locale: locale,
        ),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: glimmerModel,
                kind: 'glimmer:$gameId',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.glimmerTake fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }

  @visibleForTesting
  static Map<String, dynamic> openTipRequestBody({
    required String gameId,
    required int level,
    String locale = 'en',
  }) {
    final lang = locale == 'hu' ? 'Hungarian' : 'English';
    return {
      'model': sparkOpenModel,
      'temperature': 0.5,
      'reasoning_effort': 'minimal',
      'max_completion_tokens': coachMaxCompletionTokens,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are the friendly memory coach inside the Engrammo app. '
              'The user just played the "$gameId" memory practice game and '
              'reached level $level. Give ONE concrete, game-specific '
              'technique tip for the next round, in at most 2 short '
              'sentences. Answer in $lang. Never give medical advice, never '
              'diagnose, never promise grades, IQ gains or job performance.',
        },
        {'role': 'user', 'content': 'One tip for "$gameId" at level $level?'},
      ],
    };
  }

  /// Practice tips from the open model (Muse Spark Open). Same built-in
  /// tips offline as the classic tip call; only the live model differs.
  static Future<CoachAnswer> openPracticeTip({
    required String gameId,
    required int level,
    String locale = 'en',
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    Future<CoachAnswer> local({required bool success, String note = ''}) async {
      final answer = CoachAnswer(
        text: localPracticeTip(gameId, level, locale),
        fallback: true,
      );
      await _log(
        MetaCallEntry(
          model: sparkOpenModel,
          kind: 'opentip:$gameId',
          at: DateTime.now(),
          success: success,
          fallback: true,
          note: note,
        ),
      );
      return answer;
    }

    final key = await _liveKey(apiKeyOverride);
    final base = resolveBaseUrl(baseUrlOverride);
    if (key.isEmpty) {
      return local(
        success: true,
        note: await _gatedOfflineNote(apiKeyOverride, 'built-in tip', locale),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await _postChat(
        c,
        base: base,
        key: key,
        body: openTipRequestBody(gameId: gameId, level: level, locale: locale),
        timeoutSec: coachTimeoutSec,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final text = _choicesText(data).trim();
          if (text.isNotEmpty) {
            await _log(
              MetaCallEntry(
                model: sparkOpenModel,
                kind: 'opentip:$gameId',
                at: DateTime.now(),
                success: true,
                fallback: false,
              ),
            );
            return CoachAnswer(text: text, fallback: false);
          }
          throw StateError(_emptyChatNote(res, data));
        }
      }
      throw StateError('HTTP ${res.statusCode}: ${_snip(res.body)}');
    } catch (e) {
      debugPrint('MetaAIService.openPracticeTip fallback: $e');
      return local(success: false, note: e.toString());
    } finally {
      if (owned) c.close();
    }
  }
}
