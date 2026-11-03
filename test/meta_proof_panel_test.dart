import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/widgets/meta_call_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MetaAIService.debugClearLog();
  });

  testWidgets('per-model live/local counters with title, sorted by live', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 3, 10, 0);
    MetaAIService.debugRecord(
      MetaCallEntry(
        model: MetaAIService.taskModel,
        kind: 'task',
        at: now,
        success: true,
        fallback: false,
      ),
    );
    MetaAIService.debugRecord(
      MetaCallEntry(
        model: MetaAIService.taskModel,
        kind: 'task',
        at: now,
        success: true,
        fallback: false,
      ),
    );
    MetaAIService.debugRecord(
      MetaCallEntry(
        model: MetaAIService.imageModel,
        kind: 'image',
        at: now,
        success: false,
        fallback: true,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MetaCallLogView())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meta models used (last 120 calls)'), findsOneWidget);
    expect(find.text('2 live · 0 local'), findsOneWidget);
    expect(find.text('0 live · 1 local'), findsOneWidget);
    // Most live calls first: Spark row above the image row.
    final sparkY = tester.getCenter(find.text(MetaAIService.taskModel)).dy;
    final imageY = tester.getCenter(find.text(MetaAIService.imageModel)).dy;
    expect(sparkY, lessThan(imageY));
  });
}
