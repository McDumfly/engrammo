import 'package:engrammo/screens/benchmark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BenchmarkStore.resetForTest();
  });

  tearDown(() {
    BenchmarkStore.resetForTest();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('submit persists best, xp and plays across a restart', () async {
    BenchmarkStore.submit('sequence', 7, higherIsBetter: true);
    BenchmarkStore.submit('sequence', 5, higherIsBetter: true);
    await settle();

    BenchmarkStore.resetForTest();
    expect(BenchmarkStore.best, isEmpty);

    await BenchmarkStore.ensureLoaded();
    expect(BenchmarkStore.best['sequence'], 7);
    expect(BenchmarkStore.attempts['sequence'], [7, 5]);
    expect(BenchmarkStore.plays, 2);
    expect(BenchmarkStore.xp, 20);
  });

  test('lower-is-better keeps the minimum above zero', () async {
    BenchmarkStore.submit('number', 9, higherIsBetter: false);
    BenchmarkStore.submit('number', 5, higherIsBetter: false);
    BenchmarkStore.submit('number', 7, higherIsBetter: false);
    await settle();

    BenchmarkStore.resetForTest();
    await BenchmarkStore.ensureLoaded();
    expect(BenchmarkStore.best['number'], 5);
  });

  test('attempts cap at thirty entries', () async {
    for (var i = 0; i < 35; i++) {
      BenchmarkStore.submit('verbal', i, higherIsBetter: true, xpGain: 0);
    }
    expect(BenchmarkStore.attempts['verbal'], hasLength(30));
    await settle();

    BenchmarkStore.resetForTest();
    await BenchmarkStore.ensureLoaded();
    expect(BenchmarkStore.attempts['verbal'], hasLength(30));
    expect(BenchmarkStore.attempts['verbal']!.last, 34);
  });

  test('corrupt rows decode to the empty state', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('benchmark_state_v1', 'not-json');
    await BenchmarkStore.ensureLoaded();
    expect(BenchmarkStore.best, isEmpty);
    expect(BenchmarkStore.attempts, isEmpty);
    expect(BenchmarkStore.plays, 0);
    expect(BenchmarkStore.xp, 0);
  });
}
