import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('friss fiok fejezethaladasa ures (0/12)', () async {
    final progress = await MemoryStore.loadChapterProgress();
    expect(progress, isEmpty);
  });

  test('lecke csillag mentese es visszatoltese a profilba', () async {
    await MemoryStore.saveLessonStars(
      chapter: 2,
      section: 0,
      lesson: 0,
      stars: 3,
    );
    final progress = await MemoryStore.loadChapterProgress();
    expect(progress[MemoryStore.lessonKey(2, 0, 0)], 3);
    expect(progress[MemoryStore.lessonKey(2, 0, 1)], isNull);
  });

  test('csillag 0 es 3 koze vagva mentodik', () async {
    await MemoryStore.saveLessonStars(
      chapter: 0,
      section: 0,
      lesson: 0,
      stars: 9,
    );
    var progress = await MemoryStore.loadChapterProgress();
    expect(progress[MemoryStore.lessonKey(0, 0, 0)], 3);

    await MemoryStore.saveLessonStars(
      chapter: 0,
      section: 0,
      lesson: 1,
      stars: -2,
    );
    progress = await MemoryStore.loadChapterProgress();
    expect(progress[MemoryStore.lessonKey(0, 0, 1)], 0);
  });

  test('teljes terkep mentese megmarad', () async {
    await MemoryStore.saveChapterProgress({'0-0-0': 2, '5-0-3': 1});
    final progress = await MemoryStore.loadChapterProgress();
    expect(progress, {'0-0-0': 2, '5-0-3': 1});
  });
}
