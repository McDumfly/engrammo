import 'package:engrammo/theme/app_theme.dart';
import 'package:engrammo/widgets/app_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('AppLoader renders with no Material spinner', (tester) async {
    await tester.pumpWidget(_wrap(const AppLoader()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppLoader), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('AppSkeletonList pumps without errors', (tester) async {
    await tester.pumpWidget(_wrap(const AppSkeletonList()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppSkeleton), findsNWidgets(4));
  });

  testWidgets('showAppToast shows text then disappears', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    showAppToast(
      ctx,
      'hello toast',
      duration: const Duration(milliseconds: 800),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('hello toast'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800 + 300));
    expect(find.text('hello toast'), findsNothing);
  });

  testWidgets('a second toast replaces the first', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    showAppToast(ctx, 'first', duration: const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('first'), findsOneWidget);
    showAppToast(ctx, 'second', duration: const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('second'), findsNothing);
  });

  testWidgets('showAppDialog returns the primary value on tap', (tester) async {
    Object? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return EngramTextButton(
                label: 'open',
                onPressed: () async {
                  result = await showAppDialog<String>(
                    context,
                    title: 'Title',
                    body: 'Body',
                    primary: const AppDialogAction('OK', value: 'yes'),
                    secondary: const AppDialogAction('No', value: 'no'),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, 'yes');
  });

  testWidgets('AppCheckbox calls onChanged(true)', (tester) async {
    bool? got;
    await tester.pumpWidget(
      _wrap(AppCheckbox(value: false, onChanged: (v) => got = v)),
    );
    await tester.tap(find.byType(AppCheckbox));
    await tester.pump();
    expect(got, true);
  });

  testWidgets('AppSwitch toggles', (tester) async {
    var val = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return AppSwitch(
                value: val,
                onChanged: (v) => setState(() => val = v),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    expect(val, true);
  });

  testWidgets('AppSegmented calls onChanged with the tapped value', (
    tester,
  ) async {
    int? got;
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 300,
          child: AppSegmented<int>(
            options: const [(1, 'One'), (2, 'Two')],
            value: 1,
            onChanged: (v) => got = v,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(got, 2);
  });

  testWidgets('AppTextField counter appears only past 80 percent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const AppTextField(maxLength: 10, hint: 'x')),
    );
    expect(find.text('0/10'), findsNothing);
    await tester.enterText(find.byType(TextField), '123456789');
    await tester.pump();
    expect(find.text('9/10'), findsOneWidget);
  });

  testWidgets('AppDisclosure shows children after tap', (tester) async {
    await tester.pumpWidget(
      _wrap(const AppDisclosure(title: Text('head'), children: [Text('kid')])),
    );
    expect(find.text('kid'), findsNothing);
    await tester.tap(find.text('head'));
    await tester.pumpAndSettle();
    expect(find.text('kid'), findsOneWidget);
  });

  testWidgets('AppTextField keeps focus when errorText appears', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    Widget build(String? error) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AppTextField(focusNode: focusNode, errorText: error),
      ),
    );
    await tester.pumpWidget(build(null));
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    final before = tester.state(find.byType(EditableText));
    await tester.pumpWidget(build('bad'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(focusNode.hasFocus, isTrue);
    expect(identical(tester.state(find.byType(EditableText)), before), isTrue);
  });

  testWidgets('AppTopBar shows the back button only when it can pop', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const AppTopBar(title: 'Root')));
    expect(find.byType(AppBackButton), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Text('root')),
      ),
    );
    final ctx = tester.element(find.text('root'));
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: AppTopBar(title: 'Sub')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppBackButton), findsOneWidget);
  });
}
