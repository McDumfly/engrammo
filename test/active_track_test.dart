import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/screens/learning_path.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:engrammo/theme/app_colors.dart';
import 'package:engrammo/widgets/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A5: the app reopens on the learner's active track.
/// The gate resolves active > study pick > strongest, and the home page
/// paints that track (Spatial icon in teal for track 2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MemoryStore.clearMemoryCache();
    AppLocalizations.useCode(AppLocalizations.englishCode);
  });

  tearDown(() {
    MemoryStore.clearMemoryCache();
    AppLocalizations.useCode(AppLocalizations.englishCode);
  });

  /// The same resolution the auth gate in main.dart performs.
  Future<int> resolveGateTrack() async =>
      await MemoryStore.loadActiveTrack() ??
      await MemoryStore.loadStudyChoice() ??
      await MemoryStore.loadDominantKind() ??
      0;

  Finder trackIcon() => find.byKey(const ValueKey('stats-track-icon'));

  test('active track wins over study pick and dominant kind', () async {
    await MemoryStore.saveDominantKind(0, rationale: '', ai: true);
    await MemoryStore.saveStudyChoice(1, rationale: '', ai: true);
    await MemoryStore.saveActiveTrack(2);
    expect(await resolveGateTrack(), 2);
  });

  test('study pick wins when no active track is saved', () async {
    await MemoryStore.saveDominantKind(0, rationale: '', ai: true);
    await MemoryStore.saveStudyChoice(1, rationale: '', ai: true);
    expect(await resolveGateTrack(), 1);
  });

  test('dominant kind wins when only it is saved', () async {
    await MemoryStore.saveDominantKind(4, rationale: '', ai: true);
    expect(await resolveGateTrack(), 4);
  });

  testWidgets('saved track 2 reopens the Spatial track', (tester) async {
    await MemoryStore.saveActiveTrack(2);
    final track = await resolveGateTrack();
    expect(track, 2);
    await tester.pumpWidget(
      MaterialApp(home: LearningPathPage(initialTrack: track)),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<EngramIconButton>(trackIcon());
    expect(button.icon, HugeIcons.strokeRoundedCastle01);
    expect(button.foreground, teal);
  });
}
