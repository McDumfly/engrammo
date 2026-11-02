import 'dart:convert';
import 'dart:typed_data';

import 'package:engrammo/services/room_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('squareJpegDataUrl center-crops to a 512x512 JPEG data URL', () {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 300, height: 200)),
    );
    final url = squareJpegDataUrl(png);
    expect(url, startsWith('data:image/jpeg;base64,'));
    final payload = base64Decode(url.substring(url.indexOf(',') + 1));
    final back = img.decodeJpg(payload);
    expect(back, isNotNull);
    expect(back!.width, 512);
    expect(back.height, 512);
  });

  test('squareJpegDataUrl throws on unreadable bytes', () {
    expect(
      () =>
          squareJpegDataUrl(Uint8List.fromList(const [0, 1, 2, 3, 4, 5, 6, 7])),
      throwsStateError,
    );
  });
}
