import 'package:engrammo/widgets/ai_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1x1 transparent PNG.
const _px =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decodeDataImage', () {
    test('decodes a data:image payload into PNG bytes', () {
      final bytes = decodeDataImage('data:image/png;base64,$_px');
      expect(bytes, isNotNull);
      // PNG magic header.
      expect(bytes!.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('rejects non-data refs without throwing', () {
      expect(decodeDataImage(''), isNull);
      expect(decodeDataImage('https://img/p.png'), isNull);
      expect(decodeDataImage('palace-1'), isNull);
    });

    test('rejects malformed data URIs without throwing', () {
      expect(decodeDataImage('data:image/png;base64,'), isNull);
      expect(decodeDataImage('data:image/png;base64,!!!'), isNull);
      expect(decodeDataImage('data:image/svg+xml,<svg/>'), isNull);
      expect(decodeDataImage('data:image'), isNull);
    });
  });

  group('AiImage', () {
    testWidgets('draws embedded data URIs from memory', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AiImage(imageRef: 'data:image/png;base64,$_px', height: 100),
        ),
      );
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
    });

    testWidgets('reports undecodable payloads and shows the fallback', (
      WidgetTester tester,
    ) async {
      var errors = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AiImage(
            imageRef: 'data:image/png;base64,!!!',
            fallback: const Text('no-picture'),
            onError: () => errors++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('no-picture'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(errors, 1);
    });

    testWidgets('empty refs render the fallback silently', (
      WidgetTester tester,
    ) async {
      var errors = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AiImage(
            imageRef: '  ',
            fallback: const Text('no-picture'),
            onError: () => errors++,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('no-picture'), findsOneWidget);
      expect(errors, 0);
    });
  });
}
