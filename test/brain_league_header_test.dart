import 'package:engrammo/screens/brain_league.dart';
import 'package:engrammo/widgets/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('League header adds no extra status-bar space when embedded', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: const Scaffold(
            body: Column(
              children: [
                SizedBox(height: 48),
                Expanded(child: BrainLeaguePage()),
              ],
            ),
          ),
        ),
      ),
    );
    // pumpAndSettle sosem érne véget: a torna-sejt csillogó
    // animációja szándékosan végtelen (..repeat()), ezért fix pump.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final topBar = tester.widget<AppTopBar>(find.byType(AppTopBar).first);
    final bottomHeight =
        (topBar.bottom as PreferredSizeWidget).preferredSize.height;
    final size = tester.getSize(find.byType(AppTopBar).first);
    expect(size.height, kToolbarHeight + bottomHeight);
  });
}
