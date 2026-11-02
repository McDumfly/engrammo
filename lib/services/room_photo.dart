import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Camera is offered only where image_picker supports it.
bool get roomCameraSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Picks a photo and returns a square 512x512 JPEG data URL, or null if the
/// user cancelled. Square on purpose: the SAM cover painter maps normalized
/// boxes 1:1 onto a square picture (see docs/RESEARCH.md section 15).
Future<String?> pickRoomPhoto(ImageSource source) async {
  final x = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1280,
    maxHeight: 1280,
    imageQuality: 92,
  );
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  return compute(squareJpegDataUrl, bytes);
}

/// Center-crops to a square, resizes to 512 px and encodes as a JPEG data
/// URL. Top-level so `compute` can run it off the UI isolate.
String squareJpegDataUrl(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw StateError('unreadable image');
  final upright = img.bakeOrientation(decoded);
  final square = img.copyResizeCropSquare(upright, size: 512);
  final jpg = img.encodeJpg(square, quality: 85);
  return 'data:image/jpeg;base64,${base64Encode(jpg)}';
}
