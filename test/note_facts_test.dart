import 'dart:convert';
import 'dart:typed_data';

import 'package:engrammo/services/meta_ai_service.dart';
import 'package:engrammo/services/room_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('note facts keep distinct entries, drop banned and junk', () {
    final found = MetaAIService.parseNoteFacts(
      jsonEncode([
        'mitochondria',
        'photographic memory trick',
        'mitochondria',
        '   ',
        42,
        'ribosome',
      ]),
      max: 4,
    );
    expect(found, ['mitochondria', 'ribosome']);
  });

  test('note facts cap at max and reject non-arrays', () {
    final found = MetaAIService.parseNoteFacts(
      jsonEncode(['a', 'b', 'c']),
      max: 2,
    );
    expect(found, ['a', 'b']);
    expect(MetaAIService.parseNoteFacts('no array here'), isEmpty);
  });

  test('note facts request asks for a JSON array with minimal effort', () {
    final body = MetaAIService.noteFactsRequestBody(
      imageRef: 'data:image/jpeg;base64,AAA',
      count: 4,
    );
    final input = ((body['input'] as List).first as Map)['content'] as List;
    final text = (input.first as Map)['text'] as String;
    expect(text, contains('JSON array'));
    expect(text, contains('never invent'));
    expect((body['reasoning'] as Map)['effort'], 'minimal');
  });

  test('note photo keeps aspect without cropping', () {
    final wide = img.Image(width: 1600, height: 400);
    final url = noteJpegDataUrl(Uint8List.fromList(img.encodePng(wide)));
    final back = img.decodeImage(base64Decode(url.split(',').last))!;
    expect(back.width, 1280);
    expect(back.height, 320);
  });
}
