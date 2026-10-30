import 'dart:convert';

import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/widgets/ai_help_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => MetaAIService.consentForTest = true);
  tearDown(() => MetaAIService.consentForTest = null);

  group('quickPromptsFor', () {
    test('minden témához van előkészített kérdés', () {
      for (final topic in [
        AiHelpTopics.general,
        AiHelpTopics.lesson,
        AiHelpTopics.path,
        AiHelpTopics.assessment,
        AiHelpTopics.battle,
        AiHelpTopics.benchmark,
        AiHelpTopics.league,
        AiHelpTopics.settings,
      ]) {
        final prompts = quickPromptsFor(topic);
        expect(prompts, isNotEmpty, reason: topic);
        expect(prompts.length, greaterThanOrEqualTo(2), reason: topic);
      }
    });

    test('a lecke és a faliújság kérdései témába vágnak', () {
      expect(
        quickPromptsFor(AiHelpTopics.lesson).join(' ').toLowerCase(),
        anyOf([contains('station'), contains('technique')]),
      );
      expect(
        quickPromptsFor(AiHelpTopics.path).join(' ').toLowerCase(),
        anyOf([contains('star'), contains('streak'), contains('unlock')]),
      );
    });
  });

  group('coachRequestBody', () {
    test('rendszer + felhasználó üzenet, a kérdés szó szerint', () {
      final body = MetaAIService.coachRequestBody(
        question: 'What do I do here?',
        topic: 'lesson',
        context: 'Echo Trail',
      );
      expect(body['model'], MetaAIService.taskModel);
      final messages = body['messages'] as List;
      expect(messages, hasLength(2));
      expect(messages[0]['role'], 'system');
      expect(messages[1]['role'], 'user');
      expect(messages[1]['content'], 'What do I do here?');
      expect(messages[0]['content'] as String, contains('Echo Trail'));
    });

    test('rövid válasz kérése a gyorsaságért', () {
      final body = MetaAIService.coachRequestBody(
        question: 'What do I do here?',
      );
      expect(body['model'], 'muse-spark-1.3-contributor');
      expect(body['reasoning_effort'], 'minimal');
      expect(body['max_completion_tokens'], 1000);
      expect(body.containsKey('max_tokens'), isFalse);
      final messages = body['messages'] as List;
      expect(
        messages[0]['content'] as String,
        contains('at most 4 sentences'),
      );
    });
  });

  group('localCoachAnswer', () {
    test('csillag-kérdésre csillagszabály', () {
      final answer = MetaAIService.localCoachAnswer('How do stars work?');
      expect(answer, contains('1-3 stars'));
    });

    test('English-only: Hungarian question gets English answer', () {
      final answer = MetaAIService.localCoachAnswer('Hogy működik a széria?');
      expect(answer, contains('streak'));
      expect(answer, isNot(contains('széria')));
    });

    test('leckekörnyezetben általános leckemenet', () {
      final answer = MetaAIService.localCoachAnswer(
        'xyzzy plugh',
        topic: 'lesson',
      );
      expect(answer, contains('coach card'));
    });

    test('ismeretlen kérdésre is van terelő válasz', () {
      final answer = MetaAIService.localCoachAnswer('xyzzy plugh');
      expect(answer.isNotEmpty, isTrue);
    });

    test('köszönésre köszönéssel felel, nem terelősablonnal', () {
      for (final g in ['heyyy', 'hello']) {
        final answer = MetaAIService.localCoachAnswer(g);
        expect(answer, contains('coach'), reason: g);
        expect(
          answer,
          isNot(contains('what is unclear')),
          reason: g,
        );
      }
    });

    test('feloldós kérdésre feloldós választ ad', () {
      final answer = MetaAIService.localCoachAnswer(
        'How do I unlock the next station?',
      );
      expect(answer.toLowerCase(), contains('unlock'));
    });
  });

  group('askCoach', () {
    test('kulcs nélkül beépített választ ad, nem dob', () async {
      SharedPreferences.setMockInitialValues({});
      final answer = await MetaAIService.askCoach('How do stars work?');
      expect(answer.fallback, isTrue);
      expect(answer.text, contains('1-3 stars'));
    });

    test('üres kérdésre is válaszol, nem dob', () async {
      SharedPreferences.setMockInitialValues({});
      final answer = await MetaAIService.askCoach('   ');
      expect(answer.fallback, isTrue);
      expect(answer.text.isNotEmpty, isTrue);
    });

    test('lista-tartalmú choices is élő válasz', () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': [
                    {'type': 'text', 'text': 'Szia, ez elo valasz'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(answer.fallback, isFalse);
      expect(answer.text, contains('elo valasz'));
    });

    test('üres choices naplója testrészletet mutat', () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'choices': [],
            'error': {'message': 'valami-baj'},
          }),
          200,
        );
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        topic: 'path',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(answer.fallback, isTrue);
      expect(MetaAIService.lastCalls.first.success, isFalse);
      expect(
        MetaAIService.lastCalls.first.note,
        isNot(equals('Bad state: HTTP 200')),
      );
      expect(
        MetaAIService.lastCalls.first.note.length,
        greaterThan('Bad state: HTTP 200'.length),
      );
    });

    test('tokenkeret-elvágás naplója a lezárási okot mutatja', () async {
      SharedPreferences.setMockInitialValues({});
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'length',
                'message': {'content': null, 'role': 'assistant'},
              },
            ],
          }),
          200,
        );
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 2);
      expect(answer.fallback, isTrue);
      expect(MetaAIService.lastCalls.first.note, contains('length'));
    });

    test('length-levágás után egyszer, dupla kerettel újrapróbál', () async {
      SharedPreferences.setMockInitialValues({});
      var calls = 0;
      final caps = <int>[];
      final client = MockClient((request) async {
        calls++;
        final sent = jsonDecode(request.body) as Map<String, dynamic>;
        caps.add((sent['max_completion_tokens'] as num).toInt());
        if (calls == 1) {
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'length',
                  'message': {'content': null, 'role': 'assistant'},
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'content': 'Elo valasz ujra', 'role': 'assistant'},
              },
            ],
          }),
          200,
        );
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 2);
      expect(caps, [1000, 2000]);
      expect(answer.fallback, isFalse);
      expect(answer.text, contains('Elo valasz'));
    });

    test('tartalmas válaszra nem küld felesleges ismétlést', () async {
      SharedPreferences.setMockInitialValues({});
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'content': 'Elo valasz egybol', 'role': 'assistant'},
              },
            ],
          }),
          200,
        );
      });
      final answer = await MetaAIService.askCoach(
        'szia',
        client: client,
        apiKeyOverride: 'teszt-kulcs',
      );
      expect(calls, 1);
      expect(answer.fallback, isFalse);
    });
  });

  Future<void> tapQuick(WidgetTester tester, String label) async {
    final row = find.byKey(const ValueKey('ai-help-quick-row'));
    for (var i = 0;
        i < 10 && find.text(label).hitTestable().evaluate().isEmpty;
        i++) {
      await tester.drag(row, const Offset(-200, 0));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('előkészített kérdésre beépített válasz jön', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiHelpButton(topic: AiHelpTopics.path)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ai-help-open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-help-quick-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-help-quick-other')), findsNothing);
    await tapQuick(tester, 'How do stars work?');

    expect(find.textContaining('1-3 stars'), findsOneWidget);
    expect(find.text('Built-in answer (offline)'), findsOneWidget);
  });

  testWidgets('a beszélgetés újranyitás után is megmarad', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiHelpButton(topic: AiHelpTopics.path)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ai-help-open')));
    await tester.pumpAndSettle();
    await tapQuick(tester, 'How do stars work?');
    expect(find.textContaining('1-3 stars'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ai-help-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-help-open')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1-3 stars'), findsOneWidget);
    expect(find.text('Built-in answer (offline)'), findsOneWidget);
  });

  testWidgets('az előzmény törölhető', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiHelpButton(topic: AiHelpTopics.path)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ai-help-open')));
    await tester.pumpAndSettle();
    await tapQuick(tester, 'How do stars work?');
    await tester.tap(find.byKey(const ValueKey('ai-help-clear')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1-3 stars'), findsNothing);
    expect(find.byKey(const ValueKey('ai-help-clear')), findsNothing);
  });

  testWidgets('saját kérdés mezőből is küldhető', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiHelpButton(topic: AiHelpTopics.general)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ai-help-open')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('ai-help-input')),
      'What are engrams for?',
    );
    await tester.tap(find.byKey(const ValueKey('ai-help-send')));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('What are engrams for?'), findsOneWidget);
    expect(find.textContaining('single currency'), findsOneWidget);
  });

  group('coach üzenetformázás', () {
    Future<void> openSheet(WidgetTester tester, {String topic = 'general'}) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AiHelpButton(topic: topic))),
      );
      await tester.tap(find.byKey(const ValueKey('ai-help-open')));
      await tester.pumpAndSettle();
    }

    testWidgets('markdown nem nyersen, hanem formázva jelenik meg', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'ai_help_history_v1_general': jsonEncode([
          {
            'mine': false,
            'text': 'This is **Engrammo** — *great*!\n'
                '* First item\n'
                '* Second item',
            'offline': false,
          },
        ]),
      });
      await openSheet(tester);

      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('* First', findRichText: true), findsNothing);
      expect(
        find.textContaining('Engrammo', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('First item', findRichText: true),
        findsOneWidget,
      );
      final rich = tester.widget<RichText>(
        find.textContaining('Engrammo', findRichText: true),
      );
      var sawBold = false;
      void walk(InlineSpan span) {
        if (span is TextSpan) {
          if ((span.text ?? '').contains('Engrammo') &&
              (span.style?.fontWeight == FontWeight.w800 ||
                  span.style?.fontWeight == FontWeight.bold ||
                  span.style?.fontWeight == FontWeight.w900)) {
            sawBold = true;
          }
          for (final c in span.children ?? const <InlineSpan>[]) {
            walk(c);
          }
        }
      }

      walk(rich.text);
      expect(sawBold, isTrue);
    });

    testWidgets('jelöletlen szöveg továbbra is sima Text', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ai_help_history_v1_general': jsonEncode([
          {'mine': false, 'text': 'Hello plain world', 'offline': false},
        ]),
      });
      await openSheet(tester);
      expect(find.text('Hello plain world'), findsOneWidget);
    });

    testWidgets('aláhúzásos azonosító nem dől meg', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ai_help_history_v1_general': jsonEncode([
          {
            'mine': false,
            'text': 'Paste the MODEL_API_KEY and tap Save.',
            'offline': false,
          },
        ]),
      });
      await openSheet(tester);
      expect(
        find.text('Paste the MODEL_API_KEY and tap Save.'),
        findsOneWidget,
      );
    });

    testWidgets('send gomb és beviteli mező egyforma magas', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await openSheet(tester);
      final sendH = tester
          .getSize(find.byKey(const ValueKey('ai-help-send')))
          .height;
      final inputH = tester
          .getSize(find.byKey(const ValueKey('ai-help-input')))
          .height;
      expect(sendH, inputH);
    });

    testWidgets('a panelen nincs Material-ikon', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ai_help_history_v1_general': jsonEncode([
          {'mine': true, 'text': 'hello', 'offline': false},
        ]),
      });
      await openSheet(tester);
      expect(find.byKey(const ValueKey('ai-help-clear')), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });
}
