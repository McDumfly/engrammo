import 'package:engrammo/models/avatar_traits.dart';
import 'package:engrammo/services/dicebear_generator.dart';
import 'package:engrammo/services/memory_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('cacheKey fuggetlen a map beszurasi sorrendjetol', () {
    final a = {'eyes': 'happy', 'skinColor': 'ffdbb4'};
    final b = {'skinColor': 'ffdbb4', 'eyes': 'happy'};
    expect(DicebearGenerator.cacheKey(a), DicebearGenerator.cacheKey(b));
  });

  test(
    'masodik generalas mar memoria-cachebol jon, ujraszamolas nelkul',
    () async {
      SharedPreferences.setMockInitialValues({});
      final opts = DicebearGenerator.withoutBackground(AvatarTraits.defaults());
      final first = await DicebearGenerator.generateAvatarSvgAsync(opts);
      expect(first, isNotEmpty);
      expect(DicebearGenerator.cachedSvg(opts), first);
      final second = await DicebearGenerator.generateAvatarSvgAsync(opts);
      expect(second, first);
    },
  );

  test('avatar beallitasok mentese es visszatoltese korbeir', () async {
    SharedPreferences.setMockInitialValues({});
    final opts = {...AvatarTraits.defaults(), 'eyes': 'happy'};
    await MemoryStore.saveAvatarOpts(opts);
    final loaded = await MemoryStore.loadAvatarOpts(AvatarTraits.defaults());
    expect(loaded['eyes'], 'happy');
    expect(loaded['skinColor'], opts['skinColor']);
  });
}
