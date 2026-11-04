import 'package:engrammo/screens/room_palace_page.dart' show goalMaterialItems;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('goal material splits by line then by sentence', () {
    final items = goalMaterialItems(
      'mitochondria powers the cell. Ribosome builds proteins\nnucleus holds DNA',
      6,
    );
    expect(items, [
      'mitochondria powers the cell.',
      'Ribosome builds proteins',
      'nucleus holds DNA',
    ]);
  });

  test('goal material caps at station count, drops dupes', () {
    final items = goalMaterialItems('a\na\nb\nc', 2);
    expect(items, ['a', 'b']);
  });
}
