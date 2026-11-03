import 'dart:convert';

import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/services/session_coach.dart';
import 'package:engrammo/widgets/session_coach_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

CoachSnapshot _snap({
  List<({String id, String name, int dueInDays})> palaces = const [],
  int pathLessonsDue = 0,
  String least = 'sequence',
}) => CoachSnapshot(
  palaces: palaces,
  pathLessonsDue: pathLessonsDue,
  leastPracticedGame: least,
  dominantTrack: 'spatial',
  streak: 2,
  goalTitles: const [],
);

CoachItem _item(CoachItemType type, String ref, int minutes, CoachWhy why) =>
    CoachItem(type: type, ref: ref, minutes: minutes, why: why);

Map<String, dynamic> _toolCall(String id, String name, String args) => {
  'choices': [
    {
      'index': 0,
      'finish_reason': 'tool_calls',
      'message': {
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': id,
            'type': 'function',
            'function': {'name': name, 'arguments': args},
          },
        ],
      },
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = {};
    MetaAIService.consentForTest = null;
  });

  tearDown(() {
    BenchmarkStore.resetForTest();
    MetaAIService.secureStoreForTest = null;
    MetaAIService.consentForTest = null;
  });

  group('validatePlan', () {
    test('rule 1: needs 1-4 items', () {
      expect(validateOf([], _snap()), isNotNull);
      final five = [
        for (var i = 0; i < 5; i++)
          _item(CoachItemType.practiceGame, 'sequence', 1, CoachWhy.weak),
      ];
      // Duplicates would also fail, so use distinct games is impossible
      // with 5 items; the count rule fires first either way.
      expect(SessionCoach.validatePlan(five, _snap()), isNotNull);
    });

    test('rule 2: total must be 3-12 minutes', () {
      expect(
        SessionCoach.validatePlan([
          _item(CoachItemType.practiceGame, 'sequence', 1, CoachWhy.weak),
        ], _snap()),
        isNotNull,
      );
      expect(
        SessionCoach.validatePlan([
          _item(CoachItemType.pathLesson, 'next', 6, CoachWhy.spacing),
          _item(CoachItemType.practiceGame, 'sequence', 6, CoachWhy.weak),
          _item(CoachItemType.practiceGame, 'number', 6, CoachWhy.weak),
        ], _snap()),
        isNotNull,
      );
    });

    test('rule 3: no duplicate items', () {
      expect(
        SessionCoach.validatePlan([
          _item(CoachItemType.practiceGame, 'sequence', 3, CoachWhy.weak),
          _item(CoachItemType.practiceGame, 'sequence', 3, CoachWhy.weak),
        ], _snap()),
        isNotNull,
      );
    });

    test('rule 4: room_review ref must be a known palace', () {
      expect(
        SessionCoach.validatePlan([
          _item(CoachItemType.roomReview, 'room:nope', 3, CoachWhy.spacing),
        ], _snap()),
        isNotNull,
      );
    });

    test('rule 5: practice_game ref must be a known game', () {
      expect(
        SessionCoach.validatePlan([
          _item(CoachItemType.practiceGame, 'chess', 3, CoachWhy.weak),
        ], _snap()),
        isNotNull,
      );
    });

    test('rule 6: path_lesson ref must be "next"', () {
      expect(
        SessionCoach.validatePlan([
          _item(CoachItemType.pathLesson, 'chapter-3', 4, CoachWhy.spacing),
        ], _snap()),
        isNotNull,
      );
    });

    test('rule 7: a due palace review is missing', () {
      final s = _snap(
        palaces: const [(id: 'room:1', name: 'desk · lamp', dueInDays: 0)],
      );
      expect(
        SessionCoach.validatePlan([
          _item(CoachItemType.practiceGame, 'sequence', 3, CoachWhy.weak),
        ], s),
        'a due palace review is missing',
      );
    });

    test('rule 8: due path lessons are missing', () {
      final s = _snap(pathLessonsDue: 2);
      expect(
        SessionCoach.validatePlan([
          _item(CoachItemType.practiceGame, 'sequence', 3, CoachWhy.weak),
        ], s),
        'due path lessons are missing',
      );
    });

    test('a valid plan passes', () {
      final s = _snap(
        palaces: const [(id: 'room:1', name: 'desk · lamp', dueInDays: 0)],
      );
      expect(
        SessionCoach.validatePlan([
          _item(CoachItemType.roomReview, 'room:1', 3, CoachWhy.spacing),
          _item(CoachItemType.practiceGame, 'sequence', 3, CoachWhy.weak),
        ], s),
        isNull,
      );
    });
  });

  group('localPlan', () {
    test('empty snapshot: valid and short', () {
      final items = SessionCoach.localPlan(_snap());
      expect(SessionCoach.validatePlan(items, _snap()), isNull);
      expect(items.fold(0, (a, b) => a + b.minutes), lessThanOrEqualTo(12));
    });

    test('one due palace: contains its review', () {
      final s = _snap(
        palaces: const [(id: 'room:1', name: 'desk · lamp', dueInDays: 0)],
      );
      final items = SessionCoach.localPlan(s);
      expect(SessionCoach.validatePlan(items, s), isNull);
      expect(
        items.any(
          (it) => it.type == CoachItemType.roomReview && it.ref == 'room:1',
        ),
        isTrue,
      );
      expect(items.fold(0, (a, b) => a + b.minutes), lessThanOrEqualTo(12));
    });

    test('lessons due: contains a path lesson', () {
      final s = _snap(pathLessonsDue: 2);
      final items = SessionCoach.localPlan(s);
      expect(SessionCoach.validatePlan(items, s), isNull);
      expect(items.any((it) => it.type == CoachItemType.pathLesson), isTrue);
      expect(items.fold(0, (a, b) => a + b.minutes), lessThanOrEqualTo(12));
    });
  });

  group('parseItems', () {
    test('valid input', () {
      final items = SessionCoach.parseItems(
        jsonEncode({
          'items': [
            {
              'type': 'room_review',
              'ref': 'room:1',
              'minutes': 3,
              'why': 'spacing',
            },
            {
              'type': 'practice_game',
              'ref': 'sequence',
              'minutes': 3,
              'why': 'weak',
            },
          ],
        }),
      );
      expect(items?.length, 2);
      expect(items?.first.type, CoachItemType.roomReview);
      expect(items?.last.why, CoachWhy.weak);
    });

    test('malformed input returns null', () {
      expect(SessionCoach.parseItems('not json'), isNull);
      expect(SessionCoach.parseItems(jsonEncode({'items': 'nope'})), isNull);
      expect(
        SessionCoach.parseItems(
          jsonEncode({
            'items': [
              {'type': 'room_review', 'ref': 'room:1', 'minutes': 'three'},
            ],
          }),
        ),
        isNull,
      );
      expect(
        SessionCoach.parseItems(
          jsonEncode({
            'items': [
              {'type': 'boss_battle', 'ref': 'x', 'minutes': 3, 'why': 'fresh'},
            ],
          }),
        ),
        isNull,
      );
    });
  });

  group('scripted agent run', () {
    test('tools, rejection, self-correction, then accept', () async {
      final bodies = <Map<String, dynamic>>[];
      var calls = 0;
      final client = MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        calls++;
        if (calls == 1) {
          return http.Response(
            jsonEncode(_toolCall('call_1', 'get_due_reviews', '{}')),
            200,
          );
        }
        if (calls == 2) {
          return http.Response(
            jsonEncode(_toolCall('call_2', 'get_learner_snapshot', '{}')),
            200,
          );
        }
        if (calls == 3) {
          return http.Response(
            jsonEncode(
              _toolCall(
                'call_3',
                'submit_plan',
                jsonEncode({
                  'items': [
                    {
                      'type': 'room_review',
                      'ref': 'room:nope',
                      'minutes': 3,
                      'why': 'spacing',
                    },
                  ],
                }),
              ),
            ),
            200,
          );
        }
        return http.Response(
          jsonEncode(
            _toolCall(
              'call_4',
              'submit_plan',
              jsonEncode({
                'items': [
                  {
                    'type': 'room_review',
                    'ref': 'room:1',
                    'minutes': 3,
                    'why': 'spacing',
                  },
                  {
                    'type': 'practice_game',
                    'ref': 'sequence',
                    'minutes': 3,
                    'why': 'weak',
                  },
                ],
              }),
            ),
          ),
          200,
        );
      });
      final snap = _snap(
        palaces: const [(id: 'room:1', name: 'desk · lamp', dueInDays: 0)],
      );
      final result = await SessionCoach.plan(
        snapshot: snap,
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(result.live, isTrue);
      expect(result.trace.map((s) => s.kind), [
        'tool',
        'tool',
        'reject',
        'accept',
      ]);
      expect(result.items.length, 2);
      // Request 2 carries the tool answer with the right call id, and the
      // assistant message with tool_calls was echoed back.
      final second = bodies[1];
      final msgs = (second['messages'] as List).whereType<Map>().toList();
      final toolMsg = msgs.firstWhere((m) => m['role'] == 'tool');
      expect(toolMsg['tool_call_id'], 'call_1');
      final echo = msgs.firstWhere(
        (m) => m['role'] == 'assistant' && m['tool_calls'] != null,
      );
      expect((echo['tool_calls'] as List).first['id'], 'call_1');
    });

    test('no key falls back to the local planner', () async {
      final snap = _snap(
        palaces: const [(id: 'room:1', name: 'desk · lamp', dueInDays: 0)],
      );
      final result = await SessionCoach.plan(
        snapshot: snap,
        apiKeyOverride: '',
      );
      expect(result.live, isFalse);
      expect(result.trace.last.kind, 'fallback');
      expect(result.items.length, SessionCoach.localPlan(snap).length);
    });

    test('HTTP 500 every time falls back', () async {
      final client = MockClient((_) async => http.Response('hiba', 500));
      final result = await SessionCoach.plan(
        snapshot: _snap(),
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(result.live, isFalse);
      expect(result.trace.last.kind, 'fallback');
    });

    test(
      'model answering with text twice falls back after the nudge',
      () async {
        final client = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'hello'},
                },
              ],
            }),
            200,
          ),
        );
        final result = await SessionCoach.plan(
          snapshot: _snap(),
          client: client,
          apiKeyOverride: 'teszt-kulcs',
        );
        expect(result.live, isFalse);
        expect(result.trace.last.kind, 'fallback');
      },
    );
  });

  group('SessionCoachCard widget', () {
    testWidgets('no key: builds plan on device', (tester) async {
      AppLocalizations.useCode('en');
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SessionCoachCard())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan my session'));
      await tester.pumpAndSettle();
      // FX5 holds the finished timeline for 800ms before revealing the plan.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text('Local plan'), findsOneWidget);
      expect(find.text('Let\'s go'), findsWidgets);
    });
  });
}

String? validateOf(List<CoachItem> items, CoachSnapshot s) =>
    SessionCoach.validatePlan(items, s);
