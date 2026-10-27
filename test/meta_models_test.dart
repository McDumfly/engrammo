import 'package:engrammo/models/meta_image.dart';
import 'package:engrammo/models/meta_segment.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MetaTaskRequest', () {
    test('json korbeir', () {
      const r = MetaTaskRequest(kind: 'spatial', difficulty: 3, seed: 's1');
      final back = MetaTaskRequest.fromJson(r.toJson());
      expect(back, r);
      expect(back.hashCode, r.hashCode);
    });

    test('copyWith csak a kért mezőt cseréli', () {
      const r = MetaTaskRequest(kind: 'verbal');
      final c = r.copyWith(difficulty: 4);
      expect(c.kind, 'verbal');
      expect(c.difficulty, 4);
    });
  });

  group('MetaTask', () {
    test('json korbeir', () {
      final t = MetaTask(
        prompt: 'Jegyezd meg!',
        items: const ['7', '3', '9'],
        question: 'Mi volt a középső?',
        options: const ['5', '3', '7', '9'],
        correct: 1,
        explanation: 'Mondd ki magadban.',
        model: 'local',
        createdAt: DateTime(2026, 10, 27, 12),
      );
      final back = MetaTask.fromJson(t.toJson());
      expect(back, t);
      expect(back.hashCode, t.hashCode);
    });

    test('hiányos json biztonságos alapokra esik', () {
      final back = MetaTask.fromJson(const {});
      expect(back.prompt, isEmpty);
      expect(back.items, isEmpty);
      expect(back.options, isEmpty);
      expect(back.fallback, isTrue);
    });
  });

  group('MetaImageRequest', () {
    test('cacheKey sorrendfüggetlen', () {
      const a = MetaImageRequest(prompt: 'palota kapu', style: 's1');
      const b = MetaImageRequest(prompt: 'palota kapu', style: 's1');
      expect(a.cacheKey, b.cacheKey);
      expect(a, b);
    });

    test('promptHash stabil és nem üres', () {
      const a = MetaImageRequest(prompt: 'palota kapu');
      const b = MetaImageRequest(prompt: 'palota kapu');
      expect(a.promptHash, isNotEmpty);
      expect(a.promptHash, b.promptHash);
      expect(
        const MetaImageRequest(prompt: 'más').promptHash,
        isNot(a.promptHash),
      );
    });

    test('json korbeir', () {
      const r = MetaImageRequest(prompt: 'p', style: 's', size: 'z');
      expect(MetaImageRequest.fromJson(r.toJson()), r);
    });
  });

  group('MetaSegment', () {
    test('json korbeir', () {
      final s = MetaSegment(
        masks: const ['m1'],
        labels: const ['kapu'],
        createdAt: DateTime(2026, 10, 27),
      );
      final back = MetaSegment.fromJson(s.toJson());
      expect(back, s);
    });

    test('üres válasz offline tartaléknak számít', () {
      final s = MetaSegment(createdAt: DateTime(2026, 10, 27));
      expect(s.masks, isEmpty);
      expect(s.fallback, isTrue);
    });
  });
}
