import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/interview.dart' show interviewQuestions;
import '../models/memory_verdict.dart';
import '../models/meta_image.dart';
import '../models/meta_segment.dart';
import '../models/meta_task.dart';
import '../models/palace_drill.dart';
import '../models/validated_tasks.dart'
    show localValidatedTask, paradigmPrompt, specForKind, validateTask;
import 'env_loader.dart';

/// Egy Meta-hívás naplóbejegyzése (verseny-demó megfigyelhetőség).
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

/// Best-effort Meta AI réteg a helyi generátorok mögött.
///
/// Valódi Meta Model API-hívások ([dev.meta.ai](https://dev.meta.ai/docs)):
/// fix cím `https://api.meta.ai/v1`, auth `Bearer MODEL_API_KEY`,
/// OpenAI-kompatibilis formátum.
///
/// - Feladat: `POST /chat/completions`, modell `muse-spark-1.3`.
/// - Kép: `POST /images/generations`, modell `muse-image-1.0`.
/// - Szegmentálás: `POST /responses`, modell `sam-3.1`.
///
/// - Ha nincs kulcs (sorrend: `apiKeyOverride` → `--dart-define`
///   `MODEL_API_KEY` (régebbi néven `META_API_KEY` is jó) → a gitignore-olt
///   `.env` fájl tartalma (sima `flutter run` esetén is) → a Beállításokban
///   elmentett kulcs), vagy nincs háló, vagy a szerver hibázik, a hívók
///   a mai helyi tartalmat kapják vissza `fallback: true` jelöléssel
///   (az app nem omlik össze).
/// - Minden kísérlet naplózódik ([lastCalls], perzisztálva is).
/// - Kulcs soha nem kerül `firebase_options.dart`-szerű fájlba vagy gitbe:
///   a `.env` fájlba írható be egyszer (gitignore-olt, sima indítás is
///   látja); vagy a Beállításokban adható meg egyszer (ez a készüléken marad).
class MetaAIService {
  static const String taskModel = 'muse-spark-1.3';
  static const String imageModel = 'muse-image-1.0';
  static const String segmentModel = 'sam-3.1';

  /// Fix Meta Model API-cím. Nem kell beállítani.
  static const String defaultBaseUrl = 'https://api.meta.ai/v1';

  /// Elsődleges kulcs (a Meta-dokumentáció szerinti név).
  static const String _apiKeyEnv = 'MODEL_API_KEY';

  /// Régebbi név, visszafelé kompatibilitásból elfogadott.
  static const String _legacyApiKeyEnv = 'META_API_KEY';

  /// Csak teszt/mock célra felülírható cím (élesben üres).
  static const String _baseUrlOverrideEnv = 'META_API_BASE_URL';

  static const _logKey = 'meta_call_log_v1';

  /// A Beállításokban beírt kulcs helye (csak a készüléken).
  static const _storedKeyKey = 'meta_api_key_v1';
  static const int logCap = 50;

  static const int httpTimeoutSec = 12;

  static final List<MetaCallEntry> _calls = [];

  /// Legutóbbi hívások (legfrissebb elöl).
  static List<MetaCallEntry> get lastCalls =>
      List<MetaCallEntry>.unmodifiable(_calls);

  /// Átadott kulcs (elsődleges, vagy a régebbi név).
  static String get apiKey {
    final key = const String.fromEnvironment(_apiKeyEnv, defaultValue: '');
    if (key.isNotEmpty) return key;
    return const String.fromEnvironment(_legacyApiKeyEnv, defaultValue: '');
  }

  /// Fix cím, hacsak teszt nem írja felül dart-define-nal.
  static String get baseUrl {
    final override = const String.fromEnvironment(
      _baseUrlOverrideEnv,
      defaultValue: '',
    );
    return override.isNotEmpty ? override : defaultBaseUrl;
  }

  static bool get configured => apiKey.isNotEmpty;

  /// A becsomagolt `.env` fájlból jövő kulcs (sima `flutter run` esetén).
  static String get bundledApiKey => EnvLoader.apiKey;

  /// Van-e bármilyen kulcs: indításkor átadott, `.env`-ből jövő vagy mentett.
  static Future<bool> hasAnyKey() async {
    if (apiKey.isNotEmpty || EnvLoader.apiKey.isNotEmpty) return true;
    return (await storedApiKey()).isNotEmpty;
  }

  /// A Beállításokban elmentett kulcs (üres, ha nincs).
  static Future<String> storedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getString(_storedKeyKey) ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  /// Kulcs mentése egyszer (innen sima `flutter run` is éles).
  static Future<void> setStoredApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_storedKeyKey);
    } else {
      await prefs.setString(_storedKeyKey, trimmed);
    }
  }

  /// Elmentett kulcs törlése.
  static Future<void> clearStoredApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storedKeyKey);
    } catch (_) {
      // Best-effort: törlési hiba nem állíthatja meg az appot.
    }
  }

  /// Effektív kulcs: felülírás → `--dart-define` → `.env` → elmentett.
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

  /// Napló betöltése a helyi tárolóból (beállítás-képernyőnek).
  static Future<List<MetaCallEntry>> loadLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_logKey) ?? const [];
      return [
        for (final e in raw)
          if (e.isNotEmpty)
            MetaCallEntry.fromJson(jsonDecode(e) as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _log(MetaCallEntry entry) async {
    _calls.insert(0, entry);
    if (_calls.length > logCap) {
      _calls.removeRange(logCap, _calls.length);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_logKey, [
        for (final e in _calls.take(logCap)) jsonEncode(e.toJson()),
      ]);
    } catch (_) {
      // A napló csak megfigyelhetőség: hiba esetén eldobjuk.
    }
  }

  static Map<String, String> _headers(String key) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $key',
  };

  // ── Feladat (Muse Spark, Chat Completions) ──────────────────────

  /// A Spark-nak küldött kérés törzse (tesztelhető, kulcs nélkül is).
  ///
  /// A modell NEM találhat ki feladatformátumot: a kérés a
  /// [paradigmPrompt] rögzített eljárását hordozza, a modell csak az
  /// inger-réseket tölti ki (mely számok, szavak, színek). A válasz
  /// [parseTaskContent] szerkezeti ellenőrzésén megy át; ami nem felel
  /// meg a paradigmának, azt a hívó eldobja és a helyi, ugyanazon
  /// paradigmát futtató generátor adja a feladatot.
  @visibleForTesting
  static Map<String, dynamic> taskRequestBody(MetaTaskRequest req) {
    final english = !req.locale.startsWith('hu');
    final localeName = req.locale.startsWith('hu') ? 'magyar' : req.locale;
    final hint = paradigmPrompt(req);
    if (english) {
      return {
        'model': taskModel,
        'temperature': 0.2,
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
    return {
      'model': taskModel,
      'temperature': 0.2,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'Te egy $localeName nyelvű memóriafeladat-inger kitöltő vagy. '
              'SOHA nem találsz ki feladatformátumot: csak a megadott '
              'paradigma inger-réseit töltöd ki. '
              'Mindig egyetlen érvényes JSON-objektumot adj vissza, '
              'magyarázó szöveg nélkül. A JSON kulcsai: '
              '"prompt" (rövid inger-cím), "items" (megjelenítendő elemek, '
              'sztringek listája), "stations" (csak térbelinél: rendezett '
              'állomásnevek az "items" elemeivel páronként), "question" '
              '(kérdés), "options" (pontosan 4 válaszlehetőség '
              'sztringként), "correct" (a helyes válasz 0-alapú indexe), '
              '"explanation" (rövid mnemotechnika-tipp), "paradigm" (a '
              'paradigma-azonosító visszhangja).',
        },
        {
          'role': 'user',
          'content':
              'Készíts egy "${req.kind}" típusú memóriafeladatot, '
              'nehézség ${req.difficulty.clamp(1, 5)} (1-5 skálán). $hint'
              '${req.seed.isEmpty ? '' : 'Mag: ${req.seed}. '}Válasz nyelve: $localeName.',
        },
      ],
    };
  }

  /// Kicsomagolja a Chat Completions-választ MetaTaskká.
  ///
  /// Visszatér `null`-lal, ha a válasz nem értelmezhető VAGY nem felel
  /// meg a kérés paradigmájának ([validateTask]) — ilyenkor a hívó a
  /// helyi, validált tartalékra esik vissza. A paradigma-bélyeget
  /// ([MetaTask.paradigm]) mindig a registry adja, nem a modell
  /// visszhangja, így az AI nem címkézheti át a saját találmányát.
  /// Nincs csendes "javítás": egy tartományon kívüli `correct` index
  /// levágása másik választ koronázna helyessé, mint amit a modell
  /// gondolt — az ilyen válasz megy a tartalékba, nem a gyerek elé.
  @visibleForTesting
  static MetaTask? parseTaskContent(String content, MetaTaskRequest req) {
    try {
      var text = content.trim();
      // A modell néha ```json ... ``` keretbe csomagol.
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

  static String _choicesText(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return '';
    final first = choices.first;
    if (first is! Map<String, dynamic>) return '';
    final message = first['message'];
    if (message is! Map<String, dynamic>) return '';
    return (message['content'] as String?) ?? '';
  }

  /// Feladat-generálás: Spark először, hiba esetén helyi tartalék.
  static Future<MetaTask> generateTask(
    MetaTaskRequest req, {
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final key = await _resolveKey(apiKeyOverride);
    final base = baseUrlOverride ?? baseUrl;
    if (key.isEmpty) {
      final t = _localTask(req);
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'task:${req.kind}',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: 'nincs kulcs (Beállításokban megadható), helyi tartalék',
        ),
      );
      return t;
    }
    // Saját klienst csak akkor nyitunk, ha a hívó nem adott: azt a
    // végén mindig be is zárjuk (socket-szivárgás ellen). Az átadott
    // (pl. teszt-) kliens a hívóé, azt nem bántjuk.
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await c
          .post(
            Uri.parse('$base/chat/completions'),
            headers: _headers(key),
            body: jsonEncode(taskRequestBody(req)),
          )
          .timeout(const Duration(seconds: httpTimeoutSec));
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
        }
      }
      throw StateError('HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('MetaAIService.generateTask tartalék: $e');
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

  // ── Domináns memóriatípus (Muse Spark, szöveges AI) ─────────

  /// Az interjú-válaszok szöveges összefoglalója a promptba.
  @visibleForTesting
  static String interviewAnswersText(List<InterviewAnswer> answers) {
    final byId = {for (final q in interviewQuestions) q.id: q};
    final sb = StringBuffer();
    for (final a in answers) {
      final q = byId[a.questionId];
      if (q == null) continue;
      sb.writeln('Q: ${q.prompt}');
      if (a.picked != null &&
          a.picked! >= 0 &&
          a.picked! < q.options.length) {
        sb.writeln('Picked: ${q.options[a.picked!].label}');
      }
      if (a.custom.trim().isNotEmpty) {
        sb.writeln('Custom: ${a.custom.trim()}');
      }
    }
    return sb.toString().trim();
  }

  /// A dominánstípus-elemzés kérés-törzse (tesztelhető, kulcs nélkül is).
  ///
  /// A modell nem írhatja felül a mért teljesítményt: egyértelmű
  /// győztesnél ([tiedTop] egy elemű) azt kell visszaadnia, holtverseny
  /// esetén pedig csak a holtversenyben állók közül választhat az
  /// interjú alapján (multitrait-multimethod logika, Campbell & Fiske
  /// 1959). Ez ugyanaz a korlát, mint a [resolveDominant] létrájának
  /// 4. foka.
  @visibleForTesting
  static Map<String, dynamic> interviewRequestBody({
    required List<int> scores,
    required String answersText,
    List<int>? tiedTop,
  }) {
    const kinds =
        'sensory, working, spatial, visual, episodic, semantic';
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
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a memory coach analyzing a memory-type assessment. '
              'The user finished 6 scored memory probes (0-100 each, kinds: '
              '$kinds) and answered 6 interview questions about HOW they '
              'remember. $tieRule'
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

  /// Domináns memóriatípus megállapítása: Spark először, hiba vagy
  /// hiányzó kulcs esetén a helyi [heuristicVerdict] tartalék.
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

    final key = await _resolveKey(apiKeyOverride);
    final base = baseUrlOverride ?? baseUrl;
    if (key.isEmpty) {
      await _log(
        MetaCallEntry(
          model: taskModel,
          kind: 'interview',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: 'nincs kulcs (Beállításokban megadható), helyi kiértékelés',
        ),
      );
      return local();
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await c
          .post(
            Uri.parse('$base/chat/completions'),
            headers: _headers(key),
            body: jsonEncode(
              interviewRequestBody(
                scores: scores,
                answersText: interviewAnswersText(answers),
                tiedTop: tiedTop,
              ),
            ),
          )
          .timeout(const Duration(seconds: httpTimeoutSec));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final verdict = parseVerdictContent(_choicesText(data));
          // Hard guard: an AI verdict outside the tied top would
          // override measured performance, so it is discarded and the
          // local ladder decides instead.
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
        }
      }
      throw StateError('HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('MetaAIService.analyzeMemoryType tartalék: $e');
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

  // ── Kép (Muse Image, Images API) ────────────────────────────────

  /// A kép-kérés törzse (OpenAI `images/generate` kompatibilis).
  @visibleForTesting
  static Map<String, dynamic> imageRequestBody(MetaImageRequest req) => {
    'model': imageModel,
    'prompt': req.style.isEmpty ? req.prompt : '${req.prompt} (${req.style})',
    'size': req.size,
  };

  /// Kicsomagolja az Images-választ (url vagy base64).
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

  /// Kép-generálás: Muse minta először, hiba esetén üres tartalék.
  static Future<MetaImage> generateImage(
    MetaImageRequest req, {
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final key = await _resolveKey(apiKeyOverride);
    final base = baseUrlOverride ?? baseUrl;
    if (key.isEmpty) {
      await _log(
        MetaCallEntry(
          model: imageModel,
          kind: 'image',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: 'nincs kulcs (Beállításokban megadható), helyi tartalék',
        ),
      );
      return MetaImage(
        promptHash: req.promptHash,
        cacheKey: req.cacheKey,
        createdAt: DateTime.now(),
      );
    }
    final c = client ?? http.Client();
    final owned = client == null;
    try {
      final res = await c
          .post(
            Uri.parse('$base/images/generations'),
            headers: _headers(key),
            body: jsonEncode(imageRequestBody(req)),
          )
          .timeout(const Duration(seconds: httpTimeoutSec));
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
            return MetaImage(
              url: url,
              promptHash: req.promptHash,
              cacheKey: req.cacheKey,
              model: imageModel,
              createdAt: DateTime.now(),
              fallback: false,
            );
          }
        }
      }
      throw StateError('HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('MetaAIService.generateImage tartalék: $e');
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

  // ── Szegmentálás (SAM 3.1, Responses API) ────────────────────────

  /// A szegmentálási kérés törzse (Responses API).
  @visibleForTesting
  static Map<String, dynamic> segmentRequestBody(MetaSegmentRequest req) {
    final hints = [
      for (final p in req.points) 'pont [${p.join(', ')}]',
      for (final b in req.boxes) 'doboz [${b.join(', ')}]',
    ].join('; ');
    return {
      'model': segmentModel,
      'input':
          'Szegmentáld a(z) "${req.imageRef}" képet (SAM 3.1). '
          '${hints.isEmpty ? 'Nevezd meg a fő objektumokat' : 'Jelöltek: $hints'} '
          'és adj vissza JSON-t "masks" (maszk-azonosítók listája) és '
          '"labels" (magyar címkék listája) kulcsokkal.',
    };
  }

  /// Kicsomagolja a Responses-választ (best-effort: szövegben keres JSON-t).
  @visibleForTesting
  static MetaSegment? parseSegmentOutput(Map<String, dynamic> data) {
    try {
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

  /// Térbeli szegmentálás (SAM 3.1): csak a Palace útvonal hívja.
  static Future<MetaSegment> segment(
    MetaSegmentRequest req, {
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final key = await _resolveKey(apiKeyOverride);
    final base = baseUrlOverride ?? baseUrl;
    if (key.isEmpty) {
      await _log(
        MetaCallEntry(
          model: segmentModel,
          kind: 'segment',
          at: DateTime.now(),
          success: true,
          fallback: true,
          note: 'nincs kulcs (Beállításokban megadható), üres maszk',
        ),
      );
      return MetaSegment(createdAt: DateTime.now());
    }
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
            return seg;
          }
        }
      }
      throw StateError('HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('MetaAIService.segment tartalék: $e');
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

  // ── Feladatdúsítás: mindhárom Meta-modell a leckékben ──────────

  /// Térbeli (loci) feladat dúsítása: Muse-palotakép + SAM-állomások.
  ///
  /// Élő kulccsal: a palota-illusztrációt a Muse, az állomások
  /// rendezett listáját a SAM 3.1 szegmentálás adja; a szavakat a Spark
  /// (vagy a helyi tartalék) adta. Kulcs nélkül a helyi útvonal
  /// állomásai maradnak — ugyanaz a validált loci-paradigma
  /// (Maguire et al. 2003; Dresler et al. 2017). Soha nem dob hibát:
  /// legrosszabb esetben a bemeneti feladatot adja vissza.
  static Future<MetaTask> enrichSpatialTask(
    MetaTask task, {
    required int difficulty,
    required String seed,
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
  }) async {
    final n = drillItemCount(difficulty);
    final count = task.items.isEmpty ? n : task.items.length;
    var out = task;
    if (out.stations.length != count) {
      out = out.copyWith(
        stations: stationsFromLabels(out.stations, seed, count),
      );
    }
    try {
      final route = routeForSeed(seed);
      final img = await generateImage(
        MetaImageRequest(prompt: palaceImagePrompt(route, difficulty)),
        client: client,
        apiKeyOverride: apiKeyOverride,
        baseUrlOverride: baseUrlOverride,
      );
      final seg = await segment(
        MetaSegmentRequest(imageRef: img.url.isEmpty ? 'palace:$route' : img.url),
        client: client,
        apiKeyOverride: apiKeyOverride,
        baseUrlOverride: baseUrlOverride,
      );
      final merged = seg.labels.isEmpty
          ? out.stations
          : stationsFromLabels(seg.labels, seed, count);
      out = out.copyWith(
        stations: merged,
        imageUrl: img.url.isEmpty ? out.imageUrl : img.url,
      );
    } catch (_) {
      // Best-effort: dúsítás nélkül is teljes értékű loci-gyakorlat.
    }
    return out;
  }

  /// Vizuális (képi) feladat dúsítása: Muse-jelenetkép.
  ///
  /// Élő kulccsal a jelenet illusztrációját is megmutatja az inger;
  /// nélküle a tanuló a leírásból alkotja meg a képet fejben — ez maga
  /// a kettős kódolás gyakorlása (Paivio; Shepard 1967; Standing 1973).
  /// Soha nem dob hibát.
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
      if (img.url.isNotEmpty) out = out.copyWith(imageUrl: img.url);
    } catch (_) {
      // Best-effort: kép nélkül is teljes értékű képi gyakorlat.
    }
    return out;
  }

  // ── Helyi tartalék: ugyanaz a validált paradigma, AI nélkül ────

  /// Deterministic local task inside the requested paradigm
  /// ([localValidatedTask]): the same fixed procedure the AI would fill,
  /// so online and offline users train on identical paradigms — the only
  /// difference is who picked the stimulus.
  static MetaTask _localTask(MetaTaskRequest req) => localValidatedTask(req);
}
