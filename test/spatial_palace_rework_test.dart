import 'package:engrammo/models/meta_segment.dart';
import 'package:engrammo/models/palace_drill.dart';
import 'package:engrammo/screens/benchmark.dart';
import 'package:engrammo/services/meta_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('SAM mask geometry', () {
    Map<String, dynamic> samPayload(String lane) => {
      'id': 'resp_teszt',
      'status': 'completed',
      'output': [
        {
          'type': 'message',
          'content': [
            {'type': 'output_text', 'text': lane},
          ],
        },
      ],
    };

    test('segment output keeps normalized boxes and mask tokens', () {
      final seg = MetaAIService.parseSegmentOutput(
        samPayload(
          '<0f>0<|box;x1=50;y1=50;x2=149;y2=149;w=500;h=500|>'
          '<|mask;x=0;y=0;data=10,10,~AAA|>,'
          '1<|box;x1=250;y1=250;x2=349;y2=449;w=500;h=500|>'
          '<|mask;x=0;y=0;data=20,10,~BBB|>',
        ),
      )!;
      expect(seg.labels, isEmpty);
      expect(seg.boxes.length, 2);
      expect(seg.boxes[0], [0.1, 0.1, 0.2, 0.2]);
      expect(seg.boxes[1], [0.5, 0.5, 0.2, 0.4]);
      expect(seg.masks.length, 2);
      expect(seg.fallback, isFalse);
      final back = MetaSegment.fromJson(seg.toJson());
      expect(back, seg);
    });

    test('segment request sends one short concept, no JSON ask', () {
      final body = MetaAIService.segmentRequestBody(
        const MetaSegmentRequest(
          imageRef: 'https://x/y.png',
          concept: 'lamp',
        ),
      );
      final text = jsonEncodeOf(body);
      expect(text, contains('lamp'));
      expect(text, contains('input_image'));
      expect(text.contains('masks'), isFalse);
      expect(text.contains('labels'), isFalse);
    });
  });

  group('recall answer matching', () {
    test('ignores case, accents and padding', () {
      expect(normalizeRecallAnswer('  Kék Bögre '), 'kek bogre');
      expect(
        matchRecallAnswer('kek bogre', ['kék bögre', 'macska'], {}),
        0,
      );
      expect(matchRecallAnswer('MACSKA', ['kék bögre', 'macska'], {}), 1);
    });

    test('skips already revealed answers', () {
      expect(matchRecallAnswer('alma', ['alma', 'körte'], {0}), -1);
      expect(matchRecallAnswer('körte', ['alma', 'körte'], {0}), 1);
      expect(matchRecallAnswer('szilva', ['alma', 'körte'], {}), -1);
    });
  });

  group('picture objects (vision spotting + cleanup)', () {
    test('parses the joint object list', () {
      final objects = MetaAIService.parsePictureObjects(
        '{"objects": ["kék bögre", "macska", ""]} ',
      );
      expect(objects, ['kék bögre', 'macska']);
    });

    test('offline round falls back to a local scene, never empty', () async {
      final round = await MetaAIService.pictureRecallRound(
        seed: 'sam-test',
        count: 4,
        locale: 'hu',
      );
      expect(round.objects.length, 4);
      expect(round.objects.toSet().length, 4);
      expect(round.live, isFalse);
    });
  });

  group('SAM mask refinement', () {
    double smallOverlap(List<double> a, List<double> b) {
      final ix =
          (a[0] + a[2] < b[0] + b[2] ? a[0] + a[2] : b[0] + b[2]) -
          (a[0] > b[0] ? a[0] : b[0]);
      final iy =
          (a[1] + a[3] < b[1] + b[3] ? a[1] + a[3] : b[1] + b[3]) -
          (a[1] > b[1] ? a[1] : b[1]);
      if (ix <= 0 || iy <= 0) return 0.0;
      final small = a[2] * a[3] < b[2] * b[3] ? a[2] * a[3] : b[2] * b[3];
      return (ix * iy) / small;
    }

    test('separate boxes pass through untouched', () {
      final boxes = [
        [0.05, 0.1, 0.2, 0.2],
        [0.6, 0.1, 0.2, 0.2],
      ];
      expect(MetaAIService.resolveMaskOverlaps(boxes), boxes);
    });

    test('stacked boxes are separated, never identical', () {
      final out = MetaAIService.resolveMaskOverlaps([
        [0.1, 0.1, 0.5, 0.5],
        [0.12, 0.12, 0.5, 0.5],
      ]);
      expect(out.length, 2);
      expect(out[0], [0.1, 0.1, 0.5, 0.5]);
      expect(out[1], isNot([0.12, 0.12, 0.5, 0.5]));
      expect(smallOverlap(out[0], out[1]), lessThan(0.5));
    });

    test('boxes are clamped into the picture', () {
      final out = MetaAIService.resolveMaskOverlaps([
        [-0.1, 0.9, 0.5, 0.5],
      ]);
      final b = out.single;
      expect(b[0], greaterThanOrEqualTo(0.0));
      expect(b[1], greaterThanOrEqualTo(0.0));
      expect(b[0] + b[2], lessThanOrEqualTo(1.0));
      expect(b[1] + b[3], lessThanOrEqualTo(1.0));
    });

    test('offline round still reports progress up to done', () async {
      final seen = <double>[];
      final round = await MetaAIService.pictureRecallRound(
        seed: 'progress-teszt',
        count: 3,
        locale: 'hu',
        onProgress: (p, _) => seen.add(p),
      );
      expect(round.live, isFalse);
      expect(seen, isNotEmpty);
      expect(seen.last, 1.0);
      expect(seen.every((p) => p >= 0.0 && p <= 1.0), isTrue);
    });
  });

  group('palace setup flow', () {
    testWidgets('asks for the user palace and stations, then walks them', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SpatialGamePage()));
      await tester.pump();
      expect(find.text('What is your memory palace?'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'My flat');
      await tester.scrollUntilVisible(
        find.text('Start with my palace'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Start with my palace'));
      await tester.pump();
      final gotIt = find.text('Got it, ask me');
      for (var i = 0; i < 30 && gotIt.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The memorize screen walks the player's own stations.
      final pairs = RegExp(r'^\d+\. (.+) → (.+)$');
      final rows = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where(pairs.hasMatch)
          .toList();
      expect(rows.length, 3);
      expect(rows.first, contains('front door'));
      expect(find.textContaining('My flat'), findsWidgets);
    });

    testWidgets('SAM mask game reveals objects one by one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SamMaskGamePage(count: 3, seed: 'mask-t0')),
      );
      await tester.pump();
      // Memorize phase offers the masking button.
      final maskBtn = find.text('Mask with SAM');
      for (var i = 0; i < 30 && maskBtn.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(maskBtn, findsOneWidget);
      await tester.scrollUntilVisible(
        maskBtn,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(maskBtn);
      await tester.pump();
      expect(find.text('Mask with SAM'), findsNothing);
    });

    testWidgets('offline round never masks the placeholder', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SamMaskGamePage(count: 3, seed: 'mask-t0')),
      );
      await tester.pump();
      final maskBtn = find.text('Mask with SAM');
      for (var i = 0; i < 30 && maskBtn.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(maskBtn, findsOneWidget);
      await tester.scrollUntilVisible(
        maskBtn,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(maskBtn);
      await tester.pump();
      // No picture offline, so no numbered black tiles on the placeholder:
      // the round falls back to word recall instead.
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('3'), findsNothing);
      expect(find.text('0/3 found'), findsOneWidget);
    });
  });
}

String jsonEncodeOf(Map<String, dynamic> body) => body.toString();
