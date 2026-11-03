import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A4: the AI study pick is persisted (track + rationale/source meta) and
/// the learner's active track is remembered across restarts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MemoryStore.clearMemoryCache();
  });

  tearDown(() {
    MemoryStore.clearMemoryCache();
  });

  test('study choice round-trips with AI source meta', () async {
    await MemoryStore.saveStudyChoice(
      2,
      rationale: 'Start with spatial.',
      ai: true,
    );
    expect(await MemoryStore.loadStudyChoice(), 2);
    expect(MemoryStore.lastStudyChoice, 2);
    final meta = await MemoryStore.loadStudyChoiceMeta();
    expect(meta['source'], 'ai');
    expect(meta['rationale'], 'Start with spatial.');
    expect(meta['at'], isNotEmpty);
  });

  test('local estimate is stored with local source', () async {
    await MemoryStore.saveStudyChoice(
      0,
      rationale: 'No clear signal.',
      ai: false,
    );
    expect(await MemoryStore.loadStudyChoice(), 0);
    final meta = await MemoryStore.loadStudyChoiceMeta();
    expect(meta['source'], 'local');
  });

  test('active track round-trips and is cached', () async {
    expect(await MemoryStore.loadActiveTrack(), isNull);
    await MemoryStore.saveActiveTrack(2);
    expect(await MemoryStore.loadActiveTrack(), 2);
    expect(MemoryStore.lastActiveTrack, 2);
  });

  test('clearAccountData removes the study choice and active track', () async {
    await MemoryStore.saveStudyChoice(4, rationale: 'x', ai: true);
    await MemoryStore.saveActiveTrack(4);
    await MemoryStore.saveDominantKind(1, rationale: 'y', ai: true);
    await MemoryStore.clearAccountData();
    expect(await MemoryStore.loadStudyChoice(), isNull);
    expect(await MemoryStore.loadStudyChoiceMeta(), isEmpty);
    expect(await MemoryStore.loadActiveTrack(), isNull);
    expect(await MemoryStore.loadDominantKind(), isNull);
    expect(MemoryStore.lastStudyChoice, isNull);
    expect(MemoryStore.lastActiveTrack, isNull);
  });
}
