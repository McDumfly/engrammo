import 'dart:convert';

import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/models/curriculum.dart';
import 'package:engrammo/models/dynamic_task.dart';
import 'package:engrammo/models/foundations.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/models/palace_drill.dart';
import 'package:engrammo/models/validated_tasks.dart';
import 'package:engrammo/screens/lesson_player.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/widgets/sam_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.consentForTest = null;
    MetaAIService.clearImageCaches();
  });

  tearDown(() {
    MetaAIService.consentForTest = null;
    MetaAIService.clearImageCaches();
    AppLocalizations.useCode('en');
  });

  group('Palace Builder chapter shape (Spatial ch1)', () {
    test('chapters[2] is Palace Builder with 3 sections x 4 lessons', () {
      expect(trackOfChapter(2), 2);
      expect(chapters[2].realm, 'Palace Builder');
      expect(chapters[2].sections.length, 3);
      for (final section in chapters[2].sections) {
        expect(section.lessons.length, 4);
      }
      expect(chapters[2].sections[0].name, 'First room');
      expect(chapters[2].sections[1].name, 'Island route');
      expect(chapters[2].sections[2].name, 'My own palace');
    });

    test('every ch2 lesson is spatial and every round wants an image', () {
      for (var section = 0; section < 3; section++) {
        for (var lesson = 0; lesson < 4; lesson++) {
          expect(lessonKindFor(2, lesson), 'spatial');
          final rounds = lessonRoundsFor(2, section, lesson);
          if (isFoundationLesson(2, section, lesson)) {
            expect(rounds, 2);
          } else {
            expect(rounds, inInclusiveRange(3, 5));
          }
          for (var r = 0; r < rounds; r++) {
            final kind = lessonRoundKindFor(2, lesson, r, rounds);
            expect(kind, isIn(['spatial', 'visual']));
            expect(lessonRoundKindWantsImage(kind), isTrue);
          }
        }
      }
    });

    test('local tasks follow the round plan paradigm per round', () {
      for (var section = 0; section < 3; section++) {
        for (var lesson = 0; lesson < 4; lesson++) {
          final tasks = loadLocalLessonTasks(
            chapter: 2,
            section: section,
            lesson: lesson,
          );
          expect(tasks, isNotEmpty);
          for (var r = 0; r < tasks.length; r++) {
            final kind = lessonRoundKindFor(2, lesson, r, tasks.length);
            expect(tasks[r].paradigm, specForKind(kind).id);
          }
          final loci = tasks.first;
          expect(loci.paradigm, 'loci-drill');
          expect(loci.stations.length, loci.items.length);
        }
      }
    });

    test('non-foundation ch2 lessons mix loci and picture rounds', () {
      final tasks = loadLocalLessonTasks(chapter: 2, section: 1, lesson: 1);
      expect(tasks.length, greaterThanOrEqualTo(3));
      expect(tasks.map((t) => t.paradigm), contains('loci-drill'));
      expect(tasks.map((t) => t.paradigm), contains('picture-recall'));
    });
  });

  group('chapterImageBudget', () {
    test('unlimited credit: every chapter paints every round', () {
      expect(chapterImageBudget(2, 3), 3);
      expect(chapterImageBudget(2, 5), 5);
      expect(chapterImageBudget(0, 5), 5);
      expect(chapterImageBudget(6, 4), 4);
      expect(chapterImageBudget(2, 0), 0);
    });
  });

  group('spatialSceneForLesson', () {
    test('all 12 lessons map to a non-empty scene', () {
      final seen = <String>{};
      for (var section = 0; section < 3; section++) {
        for (var lesson = 0; lesson < 4; lesson++) {
          final scene = spatialSceneForLesson(section, lesson);
          expect(scene, isNotEmpty);
          seen.add(scene);
        }
      }
      // Room, map, island, first-person, street must all differ.
      expect(seen.length, greaterThanOrEqualTo(8));
    });

    test('prompts carry the scene viewpoint', () {
      expect(
        palaceImagePrompt('hall', 2, 'en', spatialSceneForLesson(1, 0)),
        contains('treasure map'),
      );
      expect(
        palaceImagePrompt('hall', 2, 'en', spatialSceneForLesson(1, 1)),
        contains('island'),
      );
      expect(
        palaceImagePrompt('hall', 2, 'en', spatialSceneForLesson(1, 2)),
        contains('first-person'),
      );
      expect(
        palaceImagePrompt('hall', 2, 'en', spatialSceneForLesson(2, 2)),
        contains('street'),
      );
    });
  });

  group('MetaTask SAM fields', () {
    test('old JSON without SAM fields still reads', () {
      final back = MetaTask.fromJson({
        'prompt': 'p',
        'items': ['a'],
        'question': 'q',
        'options': ['a', 'b'],
        'correct': 0,
      });
      expect(back.samLabels, isEmpty);
      expect(back.samModel, isEmpty);
    });

    test('JSON round-trip keeps SAM labels and model', () {
      final t = localPalaceTask(difficulty: 1, seed: 's').copyWith(
        imageUrl: 'https://x/y.png',
        samLabels: const ['door', 'lamp'],
        samModel: 'sam-3.1',
      );
      expect(MetaTask.fromJson(t.toJson()), t);
    });
  });

  group('enrichment with a fake Meta backend', () {
    // SAM answers with the documented special-token grammar, Spark
    // vision spotting with a grounded label array — routed by model.
    MockClient fakeBackend({required void Function() onImage}) {
      http.Response samLane() => http.Response(
        jsonEncode({
          'id': 'resp_teszt',
          'status': 'completed',
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'text':
                      '<0f>0<|box;x1=10;y1=10;x2=110;y2=110;w=500;h=500|>'
                      '<|mask;x=0;y=0;data=10,10,~AAA|>',
                },
              ],
            },
          ],
        }),
        200,
      );
      http.Response spotLane() => http.Response(
        jsonEncode({
          'id': 'resp_teszt',
          'status': 'completed',
          'output': [
            {
              'type': 'message',
              'content': [
                {
                  'type': 'output_text',
                  'text': jsonEncode([
                    {
                      'object_name': 'oak door',
                      'bbox': [
                        {'x_min': 0, 'y_min': 0, 'x_max': 200, 'y_max': 200},
                      ],
                    },
                    {
                      'object_name': 'brass lamp',
                      'bbox': [
                        {'x_min': 200, 'y_min': 0, 'x_max': 400, 'y_max': 200},
                      ],
                    },
                    {
                      'object_name': 'red rug',
                      'bbox': [
                        {'x_min': 400, 'y_min': 0, 'x_max': 600, 'y_max': 200},
                      ],
                    },
                  ]),
                },
              ],
            },
          ],
        }),
        200,
      );
      return MockClient((req) async {
        if (req.url.path.endsWith('/images/generations')) {
          onImage();
          return http.Response(
            jsonEncode({
              'data': [
                {'url': 'https://img.test/palace.png'},
              ],
            }),
            200,
          );
        }
        if (req.url.path.endsWith('/responses')) {
          final sent = jsonDecode(req.body) as Map<String, dynamic>;
          if (sent['model'] == MetaAIService.segmentModel) return samLane();
          return spotLane();
        }
        return http.Response('nope', 404);
      });
    }

    test('spatial enrich stores image + SAM stamp + playable stations',
        () async {
      MetaAIService.consentForTest = true;
      var images = 0;
      final out = await MetaAIService.enrichSpatialTask(
        localPalaceTask(difficulty: 2, seed: 's'),
        difficulty: 2,
        seed: 's',
        scene: 'map',
        client: fakeBackend(onImage: () => images++),
        apiKeyOverride: 'test-key',
      );
      expect(out.imageUrl, 'https://img.test/palace.png');
      // SAM locates geometry (model stamp), stations stay local — SAM
      // never invents names.
      expect(out.samLabels, isEmpty);
      expect(out.samModel, 'sam-3.1');
      expect(out.stations.length, out.items.length);
      expect(images, 1);
    });

    test('visual enrich stores image + SAM stamp', () async {
      MetaAIService.consentForTest = true;
      final out = await MetaAIService.enrichVisualTask(
        localPictureTask(difficulty: 2, seed: 's'),
        seed: 's',
        client: fakeBackend(onImage: () {}),
        apiKeyOverride: 'test-key',
      );
      expect(out.imageUrl, isNotEmpty);
      expect(out.samLabels, isEmpty);
      expect(out.samModel, 'sam-3.1');
    });

    test('second enrich hits the session cache, not the network', () async {
      MetaAIService.consentForTest = true;
      var images = 0;
      final client = fakeBackend(onImage: () => images++);
      final base = localPalaceTask(difficulty: 2, seed: 's');
      await MetaAIService.enrichSpatialTask(
        base,
        difficulty: 2,
        seed: 's',
        client: client,
        apiKeyOverride: 'test-key',
      );
      await MetaAIService.enrichSpatialTask(
        base,
        difficulty: 2,
        seed: 's',
        client: client,
        apiKeyOverride: 'test-key',
      );
      expect(images, 1);
    });

    test('dynamic enrich paints blocks that carry a prompt', () async {
      MetaAIService.consentForTest = true;
      final task = localDynamicTask(
        DynamicTaskRequest(
          targetId: 'todos-errands',
          userMaterial: 'my kitchen: kettle, plant, clock',
          wantsImage: true,
        ),
      );
      final material = task.blocks.firstWhere((b) => b.id == 'b1');
      expect(material.imagePrompt, isNotEmpty);
      final out = await MetaAIService.enrichDynamicTask(
        task,
        client: fakeBackend(onImage: () {}),
        apiKeyOverride: 'test-key',
      );
      final painted = out.blocks.firstWhere((b) => b.id == 'b1');
      expect(painted.imageUrl, isNotEmpty);
      expect(painted.samLabels, isNotEmpty);
    });

    test('dynamic enrich leaves prompt-less blocks untouched', () async {
      MetaAIService.consentForTest = true;
      final task = localDynamicTask(
        const DynamicTaskRequest(targetId: 'todos-errands'),
      );
      final out = await MetaAIService.enrichDynamicTask(
        task,
        client: fakeBackend(onImage: () => fail('must not call image')),
        apiKeyOverride: 'test-key',
      );
      expect(out, task);
    });

    test('spatial enrich a régi képen is futtat SAM-et, ha az új festés elbukik',
        () async {
      MetaAIService.consentForTest = true;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/images/generations')) {
          return http.Response('nincs kép', 500);
        }
        if (req.url.path.endsWith('/responses')) {
          return http.Response(
            jsonEncode({
              'id': 'resp_teszt',
              'status': 'completed',
              'output': [
                {
                  'type': 'message',
                  'content': [
                    {
                      'type': 'output_text',
                      'text':
                          '<0f>0<|box;x1=10;y1=10;x2=110;y2=110;w=500;h=500|>'
                          '<|mask;x=0;y=0;data=10,10,~AAA|>',
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }
        return http.Response('nope', 404);
      });
      final base = localPalaceTask(difficulty: 2, seed: 's').copyWith(
        imageUrl: 'https://img.test/regi-palota.png',
      );
      final out = await MetaAIService.enrichSpatialTask(
        base,
        difficulty: 2,
        seed: 's',
        client: client,
        apiKeyOverride: 'test-key',
      );
      expect(out.imageUrl, 'https://img.test/regi-palota.png');
      expect(out.samLabels, isEmpty);
      expect(out.samModel, 'sam-3.1');
      expect(out.stations.length, out.items.length);
    });

    test('visual enrich a meglévő képre is futtat SAM-et', () async {
      MetaAIService.consentForTest = true;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/images/generations')) {
          return http.Response('nincs kép', 500);
        }
        if (req.url.path.endsWith('/responses')) {
          return http.Response(
            jsonEncode({
              'id': 'resp_teszt',
              'status': 'completed',
              'output': [
                {
                  'type': 'message',
                  'content': [
                    {
                      'type': 'output_text',
                      'text':
                          '<0f>0<|box;x1=10;y1=10;x2=110;y2=110;w=500;h=500|>'
                          '<|mask;x=0;y=0;data=10,10,~AAA|>',
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }
        return http.Response('nope', 404);
      });
      final base = localPictureTask(difficulty: 2, seed: 's').copyWith(
        imageUrl: 'https://img.test/regi-kep.png',
      );
      final out = await MetaAIService.enrichVisualTask(
        base,
        seed: 's',
        client: client,
        apiKeyOverride: 'test-key',
      );
      expect(out.imageUrl, 'https://img.test/regi-kep.png');
      expect(out.samLabels, isEmpty);
      expect(out.samModel, 'sam-3.1');
    });

    test('dynamic enrich a meglévő képpel jövő blokkot is szegmentálja',
        () async {
      MetaAIService.consentForTest = true;
      var images = 0;
      final task = DynamicTask(
        id: 'd-regi',
        title: 'Régi szoba',
        instructions: 'Nézd meg',
        targetId: 'todos-errands',
        blocks: const [
          DynamicBlock(
            type: DynamicBlockType.text,
            id: 'b9',
            label: 'Régi szoba',
            imageUrl: 'https://img.test/regi-szoba.png',
          ),
        ],
        createdAt: DateTime(2026, 1, 1),
      );
      final out = await MetaAIService.enrichDynamicTask(
        task,
        client: fakeBackend(onImage: () => images++),
        apiKeyOverride: 'test-key',
      );
      expect(images, 0);
      final painted = out.blocks.firstWhere((b) => b.id == 'b9');
      expect(painted.imageUrl, 'https://img.test/regi-szoba.png');
      expect(painted.samLabels, ['oak door', 'brass lamp', 'red rug']);
    });
  });

  group('DynamicBlock image fields', () {
    test('JSON round-trip keeps prompt, url and labels', () {
      const b = DynamicBlock(
        type: DynamicBlockType.text,
        id: 'b1',
        label: 'Cover it',
        imagePrompt: 'paint my room',
        imageUrl: 'https://x/y.png',
        samLabels: ['door'],
      );
      expect(DynamicBlock.fromJson(b.toJson()), b);
    });

    test('local task without wantsImage has no prompt', () {
      final task = localDynamicTask(
        const DynamicTaskRequest(
          targetId: 'todos-errands',
          userMaterial: 'milk, eggs',
        ),
      );
      expect(
        task.blocks.firstWhere((b) => b.id == 'b1').imagePrompt,
        isEmpty,
      );
    });
  });

  group('SamOverlay widget', () {
    testWidgets('empty image renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SamOverlay(imageUrl: ''))),
      );
      expect(find.byKey(const ValueKey('sam-overlay')), findsNothing);
    });

    testWidgets('image + stations render numbered chips and caption',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SamOverlay(
              imageUrl: 'https://img.test/palace.png',
              stations: ['oak door', 'brass lamp'],
              samLabels: ['oak door', 'brass lamp', 'red rug'],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('sam-overlay')), findsOneWidget);
      expect(find.text('1 · oak door'), findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);
    });
  });

  group('Palace Builder coach AI status', () {
    testWidgets('chapter 2 coach shows the AI status card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LessonPlayerPage(
            chapterIndex: 2,
            sectionIndex: 0,
            lessonIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lesson-ai-status')), findsOneWidget);
    });

    testWidgets('other chapters show no AI status card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LessonPlayerPage(
            chapterIndex: 0,
            sectionIndex: 0,
            lessonIndex: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lesson-ai-status')), findsNothing);
    });
  });

  group('new l10n keys', () {
    test('resolve in both locales', () {
      for (final locale in ['en', 'hu']) {
        expect(
          trFor(locale, 'sam_overlay_title', {'n': 3}),
          contains('3'),
        );
        expect(trFor(locale, 'ai_picture_offline'), isNotEmpty);
        expect(trFor(locale, 'ai_palace_on'), isNotEmpty);
        expect(trFor(locale, 'ai_palace_off'), isNotEmpty);
        expect(trFor(locale, 'ai_picture_offline'), isNot('ai_picture_offline'));
      }
    });
  });
}
