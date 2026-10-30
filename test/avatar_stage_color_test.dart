import 'package:engrammo/screens/avatar_selection_screen.dart';
import 'package:engrammo/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Stage szinvaltaskor csak a hatter valtozik, az avatar nem villan at',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const AvatarSelectionScreen(),
        ),
      );
      var ready = false;
      for (var i = 0; i < 150; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();
        if (find.text('Avatar studio').evaluate().isNotEmpty) {
          ready = true;
          break;
        }
      }
      expect(ready, isTrue);
      await tester.pumpAndSettle();

      Key? switcherKey() => tester
          .widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
          .child
          ?.key;
      Color? stageColor() {
        final decoration = tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .decoration;
        return (decoration as BoxDecoration?)?.color;
      }

      final beforeKey = switcherKey();
      expect(beforeKey, isNotNull);
      expect(stageColor(), const Color(0xFFFFFFFF));

      await tester.ensureVisible(find.text('Stage'));
      await tester.tap(find.text('Stage'));
      await tester.pumpAndSettle();

      const pink = Color(0xFFF472B6);
      final swatch = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == pink,
      );
      expect(swatch, findsOneWidget);
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pumpAndSettle();

      expect(stageColor(), pink);
      expect(switcherKey(), beforeKey);
    },
  );
}
