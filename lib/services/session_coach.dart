import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/curriculum.dart' show trackName;
import '../models/marathon.dart' show daysUntilReviewDue, depthForReps;
import '../models/room_palace.dart' show roomPalaceName;
import '../screens/benchmark.dart' show BenchmarkStore;
import '../utils/test_mode.dart';
import 'memory_store.dart';
import 'meta_ai_service.dart';

enum CoachItemType { roomReview, practiceGame, pathLesson }

enum CoachWhy { spacing, testing, weak, goal, fresh }

class CoachItem {
  final CoachItemType type;
  final String ref; // palace id | game id | 'next'
  final int minutes; // 1..6
  final CoachWhy why;
  const CoachItem({
    required this.type,
    required this.ref,
    required this.minutes,
    required this.why,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'ref': ref,
    'minutes': minutes,
    'why': why.name,
  };

  /// Never throws: unknown or missing fields fall back to safe defaults.
  factory CoachItem.fromJson(Map<String, dynamic> json) {
    final type = CoachItemType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => CoachItemType.pathLesson,
    );
    final why = CoachWhy.values.firstWhere(
      (e) => e.name == json['why'],
      orElse: () => CoachWhy.fresh,
    );
    return CoachItem(
      type: type,
      ref: (json['ref'] as String?)?.trim().isNotEmpty == true
          ? (json['ref'] as String).trim()
          : 'next',
      minutes: ((json['minutes'] as num?)?.toInt() ?? 3).clamp(1, 6),
      why: why,
    );
  }
}

class CoachStep {
  // one line of the visible trace
  final String kind; // 'tool' | 'reject' | 'accept' | 'fallback'
  final String label; // tool name or reason
  const CoachStep(this.kind, this.label);

  Map<String, dynamic> toJson() => {'kind': kind, 'label': label};

  /// Never throws: missing fields become an empty generic step.
  factory CoachStep.fromJson(Map<String, dynamic> json) => CoachStep(
    (json['kind'] as String?) ?? 'tool',
    (json['label'] as String?) ?? '',
  );
}

/// A recording of a REAL Session Coach agent run, created ONLY by the
/// debug export tool from a live run — never hand-written. While the
/// asset is missing [CoachRun.load] returns null and the card hides
/// the replay link, so the app behaves exactly as today.
class CoachRun {
  final DateTime recordedAt;
  final List<CoachStep> trace;
  final List<CoachItem> items;
  const CoachRun({
    required this.recordedAt,
    required this.trace,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    'v': 1,
    'recordedAt': recordedAt.toIso8601String(),
    'trace': [for (final s in trace) s.toJson()],
    'items': [for (final i in items) i.toJson()],
  };

  /// Never throws: malformed parts become empty lists.
  factory CoachRun.fromJson(Map<String, dynamic> json) {
    DateTime at;
    try {
      at =
          DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      at = DateTime.fromMillisecondsSinceEpoch(0);
    }
    List<CoachStep> stepsOf(Object? raw) {
      if (raw is! List) return const [];
      final out = <CoachStep>[];
      for (final e in raw) {
        try {
          if (e is Map<String, dynamic>) out.add(CoachStep.fromJson(e));
        } catch (_) {}
      }
      return out;
    }

    List<CoachItem> itemsOf(Object? raw) {
      if (raw is! List) return const [];
      final out = <CoachItem>[];
      for (final e in raw) {
        try {
          if (e is Map<String, dynamic>) out.add(CoachItem.fromJson(e));
        } catch (_) {}
      }
      return out;
    }

    return CoachRun(
      recordedAt: at,
      trace: stepsOf(json['trace']),
      items: itemsOf(json['items']),
    );
  }

  /// Loads the recorded run, or null when the asset is missing. Never
  /// throws. Test-fast: no asset lookup under flutter test.
  static Future<CoachRun?> load() async {
    if (isFlutterTest) return null;
    try {
      final raw = await rootBundle.loadString('assets/demo/coach_run.json');
      final parsed = jsonDecode(raw);
      if (parsed is! Map<String, dynamic>) return null;
      return CoachRun.fromJson(parsed);
    } catch (_) {
      return null;
    }
  }
}

class CoachResult {
  final List<CoachItem> items;
  final List<CoachStep> trace;
  final bool live; // true = Muse Spark planned it and the validator accepted
  const CoachResult({
    required this.items,
    required this.trace,
    required this.live,
  });
}

/// What the tools read. Built once per run from MemoryStore so the agent
/// and the validator see the same facts.
class CoachSnapshot {
  final List<({String id, String name, int dueInDays})> palaces;
  final int pathLessonsDue;
  final String leastPracticedGame; // one of kCoachGames
  final String dominantTrack; // e.g. 'spatial' or 'unknown'
  final int streak;
  final List<String> goalTitles; // max 3

  const CoachSnapshot({
    required this.palaces,
    required this.pathLessonsDue,
    required this.leastPracticedGame,
    required this.dominantTrack,
    required this.streak,
    required this.goalTitles,
  });

  static Future<CoachSnapshot> load([DateTime? now]) async {
    final n = now ?? DateTime.now();
    final all = await MemoryStore.loadRoomPalaces();
    final ownCount = all.where((p) => !p.sample).length;
    final palaces = <({String id, String name, int dueInDays})>[];
    for (final p in all) {
      final raw = (p.card.due.difference(n).inHours / 24).ceil();
      palaces.add((
        id: p.id,
        name: roomPalaceName(p, 'en', ownCount),
        dueInDays: raw < 0 ? 0 : raw,
      ));
    }
    var pathLessonsDue = 0;
    final doneDates = await MemoryStore.loadLessonDoneDates();
    final reps = await MemoryStore.loadLessonReps();
    for (final k in doneDates.keys) {
      if (daysUntilReviewDue(
            lastDone: doneDates[k],
            depth: depthForReps(reps[k] ?? 1),
            now: n,
          ) <=
          0) {
        pathLessonsDue++;
      }
    }
    await BenchmarkStore.ensureLoaded();
    var least = kCoachGames.first;
    var leastCount = 1 << 30;
    for (final g in kCoachGames) {
      final count = BenchmarkStore.attempts[g]?.length ?? 0;
      if (count < leastCount) {
        leastCount = count;
        least = g;
      }
    }
    final kind = await MemoryStore.loadDominantKind();
    final dominantTrack = kind == null
        ? 'unknown'
        : trackName(kind).toLowerCase();
    final streak = (await MemoryStore.loadStreakState()).streak;
    final goalTitles = (await MemoryStore.loadUserGoals())
        .map((g) => g.title)
        .take(3)
        .toList();
    return CoachSnapshot(
      palaces: palaces,
      pathLessonsDue: pathLessonsDue,
      leastPracticedGame: least,
      dominantTrack: dominantTrack,
      streak: streak,
      goalTitles: goalTitles,
    );
  }
}

const kCoachGames = [
  'sequence',
  'number',
  'verbal',
  'visual',
  'order',
  'spatial',
];

class SessionCoach {
  static const tools = [
    {
      'type': 'function',
      'function': {
        'name': 'get_due_reviews',
        'description': 'Room-palace reviews and path lessons that are due today. Due items should come first: reviewing at the edge of forgetting is the spacing effect.',
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_learner_snapshot',
        'description': 'Dominant memory track, current streak, and the least-practiced practice game.',
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_goals',
        'description': "The learner's personal goal titles (max 3).",
        'parameters': {'type': 'object', 'properties': {}, 'required': []},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'submit_plan',
        'description': 'Submit today\'s plan. It is validated; if rejected you get the reason and must submit a corrected plan.',
        'parameters': {
          'type': 'object',
          'properties': {
            'items': {
              'type': 'array',
              'minItems': 1,
              'maxItems': 4,
              'items': {
                'type': 'object',
                'properties': {
                  'type': {
                    'type': 'string',
                    'enum': ['room_review', 'practice_game', 'path_lesson'],
                  },
                  'ref': {
                    'type': 'string',
                    'description': 'palace id for room_review, game id for practice_game, "next" for path_lesson',
                  },
                  'minutes': {'type': 'integer', 'minimum': 1, 'maximum': 6},
                  'why': {
                    'type': 'string',
                    'enum': ['spacing', 'testing', 'weak', 'goal', 'fresh'],
                  },
                },
                'required': ['type', 'ref', 'minutes'],
              },
            },
          },
          'required': ['items'],
        },
      },
    },
  ];

  static String _runTool(String name, CoachSnapshot s) {
    switch (name) {
      case 'get_due_reviews':
        return jsonEncode({
          'room_palaces': [
            for (final p in s.palaces)
              {'id': p.id, 'name': p.name, 'due_in_days': p.dueInDays},
          ],
          'path_lessons_due': s.pathLessonsDue,
          'valid_game_ids': kCoachGames,
        });
      case 'get_learner_snapshot':
        return jsonEncode({
          'dominant_track': s.dominantTrack,
          'streak': s.streak,
          'least_practiced_game': s.leastPracticedGame,
        });
      case 'get_goals':
        return jsonEncode({'goals': s.goalTitles});
      default:
        return jsonEncode({'error': 'unknown tool'});
    }
  }

  /// Returns null when the plan is OK, else a short English reason.
  @visibleForTesting
  static String? validatePlan(List<CoachItem> items, CoachSnapshot s) {
    if (items.isEmpty || items.length > 4) {
      return 'the plan must have 1-4 items';
    }
    final total = items.fold(0, (a, b) => a + b.minutes);
    if (total < 3 || total > 12) {
      return 'the plan must total 3-12 minutes';
    }
    final seen = <String>{};
    for (final it in items) {
      if (!seen.add('${it.type.name}:${it.ref}')) {
        return 'duplicate plan items are not allowed';
      }
    }
    for (final it in items) {
      if (it.type == CoachItemType.roomReview &&
          !s.palaces.any((p) => p.id == it.ref)) {
        return 'unknown palace id "${it.ref}"';
      }
      if (it.type == CoachItemType.practiceGame &&
          !kCoachGames.contains(it.ref)) {
        return 'unknown game id "${it.ref}"';
      }
      if (it.type == CoachItemType.pathLesson && it.ref != 'next') {
        return 'path lesson ref must be "next"';
      }
    }
    if (s.palaces.any((p) => p.dueInDays == 0)) {
      final hasDueReview = items.any(
        (it) =>
            it.type == CoachItemType.roomReview &&
            s.palaces.any((p) => p.id == it.ref && p.dueInDays == 0),
      );
      if (!hasDueReview) return 'a due palace review is missing';
    } else if (s.pathLessonsDue > 0) {
      final hasLesson = items.any((it) => it.type == CoachItemType.pathLesson);
      if (!hasLesson) return 'due path lessons are missing';
    }
    return null;
  }

  @visibleForTesting
  static List<CoachItem>? parseItems(String argsJson) {
    try {
      final data = jsonDecode(argsJson);
      if (data is! Map<String, dynamic>) return null;
      final raw = data['items'];
      if (raw is! List) return null;
      final items = <CoachItem>[];
      for (final e in raw) {
        if (e is! Map<String, dynamic>) return null;
        final type = switch (e['type']) {
          'room_review' => CoachItemType.roomReview,
          'practice_game' => CoachItemType.practiceGame,
          'path_lesson' => CoachItemType.pathLesson,
          _ => null,
        };
        final why = switch (e['why']) {
          'spacing' => CoachWhy.spacing,
          'testing' => CoachWhy.testing,
          'weak' => CoachWhy.weak,
          'goal' => CoachWhy.goal,
          'fresh' => CoachWhy.fresh,
          _ => null,
        };
        if (type == null || why == null) return null;
        final ref = e['ref'];
        final minutes = e['minutes'];
        if (ref is! String || minutes is! num) return null;
        items.add(
          CoachItem(
            type: type,
            ref: ref,
            minutes: minutes.toInt().clamp(1, 6),
            why: why,
          ),
        );
      }
      return items;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static List<CoachItem> localPlan(CoachSnapshot s) {
    final items = <CoachItem>[];
    for (final p in s.palaces) {
      if (p.dueInDays == 0 && items.length < 2) {
        items.add(
          CoachItem(
            type: CoachItemType.roomReview,
            ref: p.id,
            minutes: 3,
            why: CoachWhy.spacing,
          ),
        );
      }
    }
    if (s.pathLessonsDue > 0) {
      items.add(
        const CoachItem(
          type: CoachItemType.pathLesson,
          ref: 'next',
          minutes: 4,
          why: CoachWhy.spacing,
        ),
      );
    } else {
      items.add(
        const CoachItem(
          type: CoachItemType.pathLesson,
          ref: 'next',
          minutes: 4,
          why: CoachWhy.fresh,
        ),
      );
    }
    items.add(
      CoachItem(
        type: CoachItemType.practiceGame,
        ref: s.leastPracticedGame,
        minutes: 3,
        why: CoachWhy.weak,
      ),
    );
    var total = items.fold(0, (a, b) => a + b.minutes);
    while (items.isNotEmpty && total > 12) {
      total -= items.removeLast().minutes;
    }
    return items;
  }

  // The UI renders the localized texts from the enums, so the prompt
  // itself stays language-neutral.
  static String _system(String locale) {
    return 'You plan a short memory-training session (3-12 minutes total) for one learner.\n'
        'Rules:\n'
        '1. Always call get_due_reviews first, then get_learner_snapshot. Call get_goals only if useful.\n'
        '2. Due room-palace reviews come first (spacing effect), then due path lessons, then one practice game for the least-practiced skill.\n'
        '3. Use only ids returned by the tools. path_lesson ref is always "next".\n'
        '4. 2-4 items, each 1-6 minutes.\n'
        '5. "why" must be one of: spacing, testing, weak, goal, fresh.\n'
        '6. Finish by calling submit_plan. If it is rejected, read the reason and submit a corrected plan.\n'
        'Do not write any prose answer.';
  }

  static Future<CoachResult> plan({
    String locale = 'en',
    DateTime? now,
    CoachSnapshot? snapshot, // tests inject this
    http.Client? client,
    String? apiKeyOverride,
    String? baseUrlOverride,
    void Function(CoachStep step)? onStep, // live UI updates
  }) async {
    final s = snapshot ?? await CoachSnapshot.load(now);
    final trace = <CoachStep>[];
    void add(CoachStep st) {
      trace.add(st);
      onStep?.call(st);
    }

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _system(locale)},
      {
        'role': 'user',
        'content': 'Plan my memory-training session for today. First inspect my data with the tools, then call submit_plan.',
      },
    ];
    var nudged = false;
    try {
      for (var turn = 1; turn <= 6; turn++) {
        final data = await MetaAIService.agentChat(
          {
            'model': MetaAIService.agentModel,
            'messages': messages,
            'tools': tools,
            'tool_choice': 'auto',
            'parallel_tool_calls': false,
            // 'low': enough to pick tools and fix a rejected plan, fast enough
            // for a live UI. Never 'none' (HTTP 400 on Spark).
            'reasoning_effort': 'low',
            // Reasoning tokens share this budget; _postChat doubles it once
            // on finish_reason 'length'.
            'max_completion_tokens': 2000,
          },
          kind: 'agent:turn$turn',
          client: client,
          apiKeyOverride: apiKeyOverride,
          baseUrlOverride: baseUrlOverride,
        );
        final choices = data['choices'];
        if (choices is! List || choices.isEmpty) {
          throw StateError('no choices');
        }
        final msg = Map<String, dynamic>.from(
          (choices.first as Map)['message'] as Map,
        );
        final calls = msg['tool_calls'];
        if (calls is! List || calls.isEmpty) {
          if (nudged) throw StateError('model never submitted a plan');
          nudged = true;
          messages.add(msg);
          messages.add({'role': 'user', 'content': 'Call submit_plan now.'});
          continue;
        }
        messages.add(msg); // full assistant message incl. tool_calls
        for (final raw in calls) {
          final call = Map<String, dynamic>.from(raw as Map);
          final id = call['id'] as String? ?? '';
          final fn = Map<String, dynamic>.from(call['function'] as Map);
          final name = fn['name'] as String? ?? '';
          final args = fn['arguments'] as String? ?? '{}';
          String result;
          if (name == 'submit_plan') {
            final items = parseItems(args);
            final reason = items == null
                ? 'malformed arguments'
                : validatePlan(items, s);
            if (reason == null) {
              add(const CoachStep('accept', 'submit_plan'));
              return CoachResult(items: items!, trace: trace, live: true);
            }
            add(CoachStep('reject', reason));
            result = jsonEncode({'accepted': false, 'reason': reason});
          } else {
            add(CoachStep('tool', name));
            result = _runTool(name, s);
          }
          messages.add({'role': 'tool', 'tool_call_id': id, 'content': result});
        }
      }
      throw StateError('turn budget exhausted');
    } catch (e) {
      debugPrint('SessionCoach fallback: $e');
      add(const CoachStep('fallback', 'local planner'));
      return CoachResult(items: localPlan(s), trace: trace, live: false);
    }
  }
}
