import 'dart:convert';

import 'package:engrammo/services/session_coach.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coach run round-trips trace and items', () {
    final run = CoachRun(
      recordedAt: DateTime.utc(2026, 11, 3, 12),
      trace: const [
        CoachStep('tool', 'get_due_reviews'),
        CoachStep('tool', 'submit_plan'),
        CoachStep('reject', 'too long'),
        CoachStep('accept', 'submit_plan'),
      ],
      items: const [
        CoachItem(
          type: CoachItemType.roomReview,
          ref: 'room:1',
          minutes: 4,
          why: CoachWhy.spacing,
        ),
      ],
    );
    final back = CoachRun.fromJson(
      jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>,
    );
    expect(back.recordedAt, run.recordedAt);
    expect(back.trace.map((s) => '${s.kind}:${s.label}'), [
      'tool:get_due_reviews',
      'tool:submit_plan',
      'reject:too long',
      'accept:submit_plan',
    ]);
    expect(back.items.single.type, CoachItemType.roomReview);
    expect(back.items.single.minutes, 4);
  });

  test('coach run never throws on malformed json', () {
    final back = CoachRun.fromJson({'trace': 'junk'});
    expect(back.trace, isEmpty);
    expect(back.items, isEmpty);
    expect(CoachItem.fromJson(const {}).type, CoachItemType.pathLesson);
  });

  test('coach run load is null without the bundled asset', () async {
    expect(await CoachRun.load(), isNull);
  });
}
