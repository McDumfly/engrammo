import 'package:engrammo/models/sam_mask.dart';
import 'package:engrammo/screens/benchmark.dart' show buildSamOutline;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildSamOutline', () {
    test('a 3x3 block of runs gives one outline matching the union rect', () {
      const rect = Rect.fromLTWH(0, 0, 30, 30);
      final outline = buildSamOutline(
        rect: rect,
        runs: const [
          SamMaskRun(0, 0, 2),
          SamMaskRun(1, 0, 2),
          SamMaskRun(2, 0, 2),
        ],
        rasterW: 3,
        rasterH: 3,
      );
      expect(outline, isNotNull);
      expect(outline!.getBounds(), const Rect.fromLTWH(0, 0, 30, 30));
    });

    test('returns null for empty runs and for more than 300 runs', () {
      const rect = Rect.fromLTWH(0, 0, 30, 30);
      expect(
        buildSamOutline(rect: rect, runs: const [], rasterW: 3, rasterH: 3),
        isNull,
      );
      final many = List.generate(301, (i) => SamMaskRun(i, 0, 0));
      expect(
        buildSamOutline(rect: rect, runs: many, rasterW: 1, rasterH: 301),
        isNull,
      );
    });
  });
}
