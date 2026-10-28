import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('onboarding alapból nincs pipálva, majd mentődik', () async {
    expect(await MemoryStore.loadOnboardingDone(), isFalse);
    await MemoryStore.saveOnboardingDone();
    expect(await MemoryStore.loadOnboardingDone(), isTrue);
  });

  test('strongestKindOrNull: null mérés nélkül', () {
    expect(MemoryStore.strongestKindOrNull(null), isNull);
    expect(MemoryStore.strongestKindOrNull([]), isNull);
    expect(MemoryStore.strongestKindOrNull([40, 100, 60, 0, 40, 100]), 1);
  });

  test('strongestKind marad 0 ismeretlenre (battle-alap)', () {
    expect(MemoryStore.strongestKind(null), 0);
    expect(MemoryStore.strongestKind([]), 0);
  });
}
