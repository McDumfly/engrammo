import 'package:engrammo/screens/brain_league.dart';
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
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
    final bottomHeight =
        (appBar.bottom as PreferredSizeWidget).preferredSize.height;
    final size = tester.getSize(find.byType(AppBar).first);
    expect(size.height, kToolbarHeight + bottomHeight);
  });
}
