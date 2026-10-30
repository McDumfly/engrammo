import 'package:engrammo/screens/profile_setup.dart';
import 'package:engrammo/services/cloud_sync.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/services/profile_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CloudSync.currentUid = null;
  });

  group('ProfileSetupRules.normalizeUsername', () {
    test('kisbetusit, vag, szokozbol alahuzas', () {
      expect(ProfileSetupRules.normalizeUsername('  Jane Doe '), 'jane_doe');
      expect(ProfileSetupRules.normalizeUsername('ABC'), 'abc');
    });
  });

  group('ProfileSetupRules.validateUsername', () {
    test('jo nevek atmennek', () {
      expect(ProfileSetupRules.validateUsername('jane'), isNull);
      expect(ProfileSetupRules.validateUsername('Jane.Doe_99'), isNull);
      expect(ProfileSetupRules.validateUsername('a_b.c1'), isNull);
    });

    test('ures es tul rovid nem jo', () {
      expect(ProfileSetupRules.validateUsername(''), isNotNull);
      expect(ProfileSetupRules.validateUsername('ab'), contains('3'));
    });

    test('tul hosszu nem jo', () {
      expect(
        ProfileSetupRules.validateUsername('a' * 21),
        contains('20'),
      );
      expect(ProfileSetupRules.validateUsername('a' * 20), isNull);
    });

    test('tiltott karakterek nem jok', () {
      expect(ProfileSetupRules.validateUsername('jane!'), contains('Only'));
      expect(ProfileSetupRules.validateUsername('jános'), contains('Only'));
      expect(ProfileSetupRules.validateUsername('a@b'), contains('Only'));
    });

    test('szelso pont/alahuzas nem jo', () {
      expect(ProfileSetupRules.validateUsername('.jane'), contains('Cannot'));
      expect(ProfileSetupRules.validateUsername('jane_'), contains('Cannot'));
      expect(ProfileSetupRules.validateUsername('ja..ne'), contains('Dots'));
    });
  });

  group('ProfileSetupRules.validateDisplayName', () {
    test('ures nem jo, normal jo', () {
      expect(ProfileSetupRules.validateDisplayName(''), isNotNull);
      expect(ProfileSetupRules.validateDisplayName('   '), isNotNull);
      expect(ProfileSetupRules.validateDisplayName('Jane'), isNull);
    });

    test('tul hosszu nem jo', () {
      expect(
        ProfileSetupRules.validateDisplayName('a' * 41),
        contains('40'),
      );
      expect(ProfileSetupRules.validateDisplayName('a' * 40), isNull);
    });
  });

  group('MemoryStore profilbeallitas-jeloles', () {
    test('uid-hez kotott: masik fioknak ujra kell', () async {
      expect(await MemoryStore.isProfileSetupDone('uid-1'), isFalse);
      await MemoryStore.markProfileSetupDone('uid-1');
      expect(await MemoryStore.isProfileSetupDone('uid-1'), isTrue);
      expect(await MemoryStore.isProfileSetupDone('uid-2'), isFalse);
    });

    test('ures uid soha nem kesz', () async {
      await MemoryStore.markProfileSetupDoneWithoutNotify('');
      expect(await MemoryStore.isProfileSetupDone(''), isFalse);
    });

    test('fioktorleskor a jeloles is urul', () async {
      await MemoryStore.markProfileSetupDone('uid-1');
      await MemoryStore.clearAccountData();
      expect(await MemoryStore.isProfileSetupDone('uid-1'), isFalse);
    });
  });

  testWidgets('ProfileSetupScreen: cim + mezok + mentes, vissza-gomb nelkul',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfileSetupScreen(onDone: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up your profile'), findsOneWidget);
    expect(find.text('SAVE & CONTINUE'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(CloseButton), findsNothing);
  });

  testWidgets('ProfileSetupScreen: ures nev hibauzenetet ad', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfileSetupScreen(onDone: () {})),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAVE & CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Add your name.'), findsOneWidget);
  });

  testWidgets('ProfileSetupScreen: rovid @nev hibauzenetet ad',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfileSetupScreen(onDone: () {})),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'Jane');
    await tester.enterText(fields.at(1), 'ab');
    await tester.tap(find.text('SAVE & CONTINUE'));
    await tester.pumpAndSettle();
    expect(
      find.text('Username needs at least 3 characters.'),
      findsOneWidget,
    );
  });
}
