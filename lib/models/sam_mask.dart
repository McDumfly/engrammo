// Copyright (c) Meta Platforms, Inc. and affiliates. All Rights Reserved.
//
// Dart port of the SAM mask decoder (`meta-sam-parser`, SAM License):
// base85 unpacking plus the one_bit / lossless range-coded rasters.
// The wire grammar is documented at
// https://dev.meta.ai/docs/sam/reading-segmentation ; the decoding
// algorithm below follows the reference `meta_sam_parser/_mask_codec.py`
// so Engrammo can render SAM 3.1 shape masks without a JS/Python bridge.
//
// License note: the SAM License grants use, reproduction, distribution
// and derivative works of the SAM Materials; this file is a derivative
// of the reference decoder, kept for decoding Meta API output only.
import 'dart:typed_data';

/// One SAM 3.1 mask record: the encoding marker plus the opaque base85
/// payload and the raster size in pixels ([height] rows x [width] cols).
class SamMaskSpec {
  final String encoding;
  final String payload;
  final int width;
  final int height;

  const SamMaskSpec({
    required this.encoding,
    required this.payload,
    required this.width,
    required this.height,
  });
}

/// One horizontal run of filled cells in a decoded raster row.
class SamMaskRun {
  final int row;
  final int start;
  final int end;

  const SamMaskRun(this.row, this.start, this.end);
}

class _InvalidMask implements Exception {
  final String message;
  const _InvalidMask(this.message);
  @override
  String toString() => 'InvalidSegmentationMask($message)';
}

// Printable ASCII 0x21..0x7E minus the seven wire delimiters (`" \, ; < > |`).
const String _alphabet =
    '!#\$%&\'()*+-./0123456789:=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_`'
    'abcdefghijklmnopqrstuvwxyz{';
const int _radix = 85;
const int _prefixLength = 5;

final List<int> _charValues = (() {
  final values = List<int>.filled(128, -1);
  for (var i = 0; i < _alphabet.length; i++) {
    values[_alphabet.codeUnitAt(i)] = i;
  }
  return values;
})();

const int _top = 1 << 24;
const int _bottom = 1 << 16;
const int _mask8 = 0xff;
const int _mask16 = 0xffff;
const int _mask32 = 0xffffffff;
const int _increment = 14;
const int _countLimit = 4096;
const int _contextCount = 1 << 12;
const int _padding = 2;
const int _symbols = 256;
const int _totalIndex = _symbols;
const int _spatialModes = 5;
const int _zeroIncrement = 32;
const int _zeroLimit = 16384;
const int _orderOneIncrement = 56;
const int _orderOneLimit = 8192;
const int _orderTwoStep = 14 * 44;
const int _orderTwoLimit = 14 * 3584;
const int _orderZeroStep = 2 * 16;
const int _orderZeroLimit = 2 * 2048;
const int _orderZeroInitial = 2;
const int _orderOneInitial = 1;
const int _maxSafe = (1 << 53) - 1;

/// Hard display caps: real SAM rasters are tens of pixels per side.
/// Anything bigger is rejected before any buffer is allocated.
const int _maxSide = 2048;
const int _maxArea = 4 * 1024 * 1024;

int _u8(int v) => v & _mask8;
int _u16(int v) => v & _mask16;
int _u32(int v) => v & _mask32;
int _i32(int v) {
  v &= _mask32;
  return v < (1 << 31) ? v : v - (1 << 32);
}

int _digit(String ch) {
  final code = ch.codeUnitAt(0);
  final v = code < _charValues.length ? _charValues[code] : -1;
  if (v < 0 || v >= _radix) {
    throw const _InvalidMask('Mask payload contains an invalid character.');
  }
  return v;
}

String _pack(List<int> input) {
  final length = input.length;
  var remaining = length;
  final out = List<String>.filled(_prefixLength, '');
  for (var i = _prefixLength - 1; i >= 0; i--) {
    out[i] = _alphabet[remaining % _radix];
    remaining ~/= _radix;
  }
  if (remaining != 0) throw const _InvalidMask('Mask payload is too large.');

  var offset = 0;
  final full = length - (length % 4);
  final buf = StringBuffer(out.join());
  while (offset < full) {
    var value = _u32(
      (input[offset] << 24) |
          (input[offset + 1] << 16) |
          (input[offset + 2] << 8) |
          input[offset + 3],
    );
    final digits = List<int>.filled(5, 0);
    for (var i = 4; i >= 0; i--) {
      digits[i] = value % _radix;
      value = (value - digits[i]) ~/ _radix;
    }
    for (final d in digits) {
      buf.write(_alphabet[d]);
    }
    offset += 4;
  }

  final remainder = length - offset;
  if (remainder > 0) {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      value = _u32((value << 8) | (i < remainder ? input[offset + i] : 0));
    }
    final digits = List<int>.filled(5, 0);
    for (var i = 4; i >= 0; i--) {
      digits[i] = value % _radix;
      value = (value - digits[i]) ~/ _radix;
    }
    for (var i = 0; i < remainder + 1; i++) {
      buf.write(_alphabet[digits[i]]);
    }
  }
  return buf.toString();
}

Uint8List _unpack(String payload) {
  if (payload.length < _prefixLength) {
    throw const _InvalidMask('Mask payload is missing its length prefix.');
  }
  var length = 0;
  for (var i = 0; i < _prefixLength; i++) {
    length = length * _radix + _digit(payload[i]);
  }
  if (length > _maxSafe) {
    throw const _InvalidMask('Mask payload length is unsupported.');
  }
  final remainder = length % 4;
  final expected =
      _prefixLength + (length ~/ 4) * 5 + (remainder == 0 ? 0 : remainder + 1);
  if (payload.length != expected) {
    throw const _InvalidMask('Mask payload length does not match its prefix.');
  }

  final output = Uint8List(length);
  var source = _prefixLength;
  var destination = 0;
  final full = length - remainder;
  while (destination < full) {
    var value = 0;
    for (var i = 0; i < 5; i++) {
      value = value * _radix + _digit(payload[source + i]);
    }
    if (value > _mask32) {
      throw const _InvalidMask('Mask payload contains an out-of-range group.');
    }
    source += 5;
    output[destination] = (value >> 24) & _mask8;
    output[destination + 1] = (value >> 16) & _mask8;
    output[destination + 2] = (value >> 8) & _mask8;
    output[destination + 3] = value & _mask8;
    destination += 4;
  }

  if (remainder > 0) {
    var value = 0;
    for (var i = 0; i < 5; i++) {
      value =
          value * _radix +
          (i < remainder + 1 ? _digit(payload[source + i]) : _radix - 1);
    }
    if (value > _mask32) {
      throw const _InvalidMask('Mask payload contains an out-of-range tail.');
    }
    for (var i = 0; i < remainder; i++) {
      output[destination + i] = (value >> (24 - i * 8)) & _mask8;
    }
  }

  if (_pack(output) != payload) {
    throw const _InvalidMask('Mask payload is not in canonical form.');
  }
  return output;
}

class _RangeEncoder {
  int _low = 0;
  int _range = _mask32;
  final List<int> _output = <int>[];

  void encode(int cumulative, int frequency, int total) {
    final scaled = _range ~/ total;
    _low = _u32(_low + scaled * cumulative);
    _range = scaled * frequency;
    while (true) {
      if (_u32(_low ^ _u32(_low + _range)) < _top) {
        // Top byte converged: emit it below.
      } else if (_range < _bottom) {
        _range = _u32(-_low) & (_bottom - 1);
      } else {
        break;
      }
      _output.add((_low >> 24) & _mask8);
      _low = _u32(_low << 8);
      _range = _u32(_range << 8);
    }
  }

  Uint8List finish() {
    for (var i = 0; i < 4; i++) {
      _output.add((_low >> 24) & _mask8);
      _low = _u32(_low << 8);
    }
    return Uint8List.fromList(_output);
  }
}

class _RangeDecoder {
  final Uint8List _input;
  int _position = 0;
  int _low = 0;
  int _range = _mask32;
  int _code = 0;
  int _scaled = 0;

  _RangeDecoder(this._input) {
    if (_input.length < 4) {
      throw const _InvalidMask('Mask payload is missing its finalization.');
    }
    for (var i = 0; i < 4; i++) {
      _code = _u32((_code << 8) | _read());
    }
  }

  int frequency(int total) {
    _scaled = _range ~/ total;
    if (_scaled == 0) {
      throw const _InvalidMask('Mask payload has invalid coding state.');
    }
    final value = _u32(_code - _low) ~/ _scaled;
    return value >= total ? total - 1 : value;
  }

  void decode(int cumulative, int frequency) {
    _low = _u32(_low + _scaled * cumulative);
    _range = _scaled * frequency;
    while (true) {
      if (_u32(_low ^ _u32(_low + _range)) < _top) {
        // Top byte converged: shift it below.
      } else if (_range < _bottom) {
        _range = _u32(-_low) & (_bottom - 1);
      } else {
        break;
      }
      _code = _u32((_code << 8) | _read());
      _low = _u32(_low << 8);
      _range = _u32(_range << 8);
    }
  }

  int _read() {
    if (_position >= _input.length) {
      throw const _InvalidMask('Mask payload ended before decoding completed.');
    }
    return _input[_position++];
  }
}

List<int> _orderTwo(Map<int, List<int>> countsByContext, int key) {
  var counts = countsByContext[key];
  if (counts == null) {
    counts = List<int>.filled(_symbols + 1, 0);
    countsByContext[key] = counts;
  }
  return counts;
}

int _paeth(int left, int up, int upperLeft) {
  final estimate = left + up - upperLeft;
  final dl = (estimate - left).abs();
  final du = (estimate - up).abs();
  final dul = (estimate - upperLeft).abs();
  if (dl <= du && dl <= dul) return left;
  return du <= dul ? up : upperLeft;
}

int _predictByte(Uint8List output, int offset, int x, int y, int mode, int width) {
  if (mode < 0 || mode >= _spatialModes) {
    throw const _InvalidMask('Lossless mask payload uses an invalid predictor.');
  }
  final left = x > 0 ? output[offset - 1] : 0;
  final up = y > 0 ? output[offset - width] : 0;
  if (mode == 1) return up;
  if (mode == 2) return left;
  if (mode == 3) return (left + up) >> 1;
  final upperLeft = x > 0 && y > 0 ? output[offset - width - 1] : 0;
  if (mode == 0) return _paeth(left, up, upperLeft);
  final hi = left > up ? left : up;
  final lo = left < up ? left : up;
  if (upperLeft >= hi) return lo;
  if (upperLeft <= lo) return hi;
  return left + up - upperLeft;
}

int _unzig(int value, int prediction) {
  final delta = (value & 1) != 0 ? -((value + 1) >> 1) : value >> 1;
  return _u8(prediction + delta);
}

int _zeroContext(Uint8List residuals, int offset, int x, int y, int width) {
  final left = (x > 0 ? residuals[offset - 1] == 0 : true) ? 1 : 0;
  final up = (y > 0 ? residuals[offset - width] == 0 : true) ? 1 : 0;
  final upperLeft =
      (x > 0 && y > 0 ? residuals[offset - width - 1] == 0 : true) ? 1 : 0;
  final upperRight =
      (y > 0 && x < width - 1 ? residuals[offset - width + 1] == 0 : true)
      ? 1
      : 0;
  return left | (up << 1) | (upperLeft << 2) | (upperRight << 3);
}

Uint8List _decodeLosslessRaster(String payload, int width, int height) {
  if (!payload.startsWith('~')) {
    throw const _InvalidMask('lossless mask payloads must start with ~.');
  }
  final packed = _unpack(payload.substring(1));
  if (packed.length < 5) {
    throw const _InvalidMask('Lossless mask payload is truncated.');
  }
  final selector = packed[0];
  final decoder = _RangeDecoder(packed.sublist(1));
  final length = width * height;
  final output = Uint8List(length);
  final residuals = Uint8List(length);
  final zeroCounts = List<int>.filled(32, 1);
  final orderOne = List<int>.filled(_symbols * _symbols, _orderOneInitial);
  final orderOneTotals = List<int>.filled(
    _symbols,
    _symbols * _orderOneInitial,
  );
  final orderZero = List<int>.filled(_symbols, _orderZeroInitial);
  var orderZeroTotal = _symbols * _orderZeroInitial;
  final orderTwo = <int, List<int>>{};
  var previous = 0;

  for (var offset = 0; offset < length; offset++) {
    final x = offset % width;
    final y = offset ~/ width;
    final zeroOffset = _zeroContext(residuals, offset, x, y, width) << 1;
    final zero = zeroCounts[zeroOffset];
    final nonzero = zeroCounts[zeroOffset + 1];
    final zeroFrequency = decoder.frequency(zero + nonzero);
    final bit = zeroFrequency < zero ? 0 : 1;
    decoder.decode(bit == 0 ? 0 : zero, bit == 0 ? zero : nonzero);
    zeroCounts[zeroOffset + bit] = _u32(
      zeroCounts[zeroOffset + bit] + _zeroIncrement,
    );
    if (zeroCounts[zeroOffset] + zeroCounts[zeroOffset + 1] >= _zeroLimit) {
      final a = zeroCounts[zeroOffset] >> 1;
      final b = zeroCounts[zeroOffset + 1] >> 1;
      zeroCounts[zeroOffset] = a == 0 ? 1 : a;
      zeroCounts[zeroOffset + 1] = b == 0 ? 1 : b;
    }

    var symbol = 0;
    if (bit == 1) {
      final above = offset >= width ? residuals[offset - width] : 0;
      final second = _orderTwo(orderTwo, (previous << 8) | above);
      final firstOffset = previous << 8;
      final excludedZero =
          second[0] + orderOne[firstOffset] + orderZero[0];
      final total =
          second[_totalIndex] +
          orderOneTotals[previous] +
          orderZeroTotal -
          excludedZero;
      final target = decoder.frequency(total);
      var cumulative = 0;
      symbol = 1;
      var frequency =
          second[1] + orderOne[firstOffset + 1] + orderZero[1];
      while (cumulative + frequency <= target) {
        cumulative += frequency;
        symbol += 1;
        if (symbol >= _symbols) {
          throw const _InvalidMask('Lossless mask payload is malformed.');
        }
        frequency =
            second[symbol] +
            orderOne[firstOffset + symbol] +
            orderZero[symbol];
      }
      decoder.decode(cumulative, frequency);
      second[symbol] = _u16(second[symbol] + _orderTwoStep);
      second[_totalIndex] = _u16(second[_totalIndex] + _orderTwoStep);
      if (second[_totalIndex] >= _orderTwoLimit) {
        var scaledTotal = 0;
        for (var v = 0; v < _symbols; v++) {
          second[v] = second[v] >> 1;
          scaledTotal += second[v];
        }
        second[_totalIndex] = _u16(scaledTotal);
      }
      orderOne[firstOffset + symbol] = _u16(
        orderOne[firstOffset + symbol] + _orderOneIncrement,
      );
      orderOneTotals[previous] = _i32(
        orderOneTotals[previous] + _orderOneIncrement,
      );
      if (orderOneTotals[previous] >= _orderOneLimit) {
        var scaledTotal = 0;
        for (var v = 0; v < _symbols; v++) {
          var scaled = orderOne[firstOffset + v] >> 1;
          if (scaled == 0) scaled = 1;
          orderOne[firstOffset + v] = scaled;
          scaledTotal += scaled;
        }
        orderOneTotals[previous] = _i32(scaledTotal);
      }
      orderZero[symbol] = _u16(orderZero[symbol] + _orderZeroStep);
      orderZeroTotal += _orderZeroStep;
      if (orderZeroTotal >= _orderZeroLimit) {
        var scaledTotal = 0;
        for (var v = 0; v < _symbols; v++) {
          orderZero[v] = orderZero[v] >> 1;
          scaledTotal += orderZero[v];
        }
        orderZeroTotal = scaledTotal;
      }
    }
    residuals[offset] = symbol;
    output[offset] = _unzig(
      symbol,
      _predictByte(output, offset, x, y, selector, width),
    );
    previous = symbol;
  }
  return output;
}

int _contextAt(Uint8List raster, int position, int prior, int earlier) {
  return raster[position - 1] |
      (raster[position - 2] << 1) |
      (raster[prior - 2] << 2) |
      (raster[prior - 1] << 3) |
      (raster[prior] << 4) |
      (raster[prior + 1] << 5) |
      (raster[prior + 2] << 6) |
      (raster[earlier - 2] << 7) |
      (raster[earlier - 1] << 8) |
      (raster[earlier] << 9) |
      (raster[earlier + 1] << 10) |
      (raster[earlier + 2] << 11);
}

void _updateCounts(List<int> counts, int offset, int bit) {
  counts[offset + bit] = _u16(counts[offset + bit] + _increment);
  if (counts[offset] + counts[offset + 1] >= _countLimit) {
    var a = counts[offset] >> 1;
    var b = counts[offset + 1] >> 1;
    if (a == 0) a = 1;
    if (b == 0) b = 1;
    counts[offset] = a;
    counts[offset + 1] = b;
  }
}

String _encodeRaster(Uint8List input, int width, int height) {
  final encoder = _RangeEncoder();
  final counts = List<int>.filled(_contextCount * 2, 1);
  final paddedWidth = width + 2 * _padding;
  final padded = Uint8List(paddedWidth * (height + _padding));
  for (var y = 0; y < height; y++) {
    final row = (y + _padding) * paddedWidth + _padding;
    for (var x = 0; x < width; x++) {
      final position = row + x;
      final context = _contextAt(
        padded,
        position,
        position - paddedWidth,
        position - 2 * paddedWidth,
      );
      final offset = context << 1;
      final zero = counts[offset];
      final one = counts[offset + 1];
      final bit = input[y * width + x];
      if (bit != 0 && bit != 1) {
        throw const _InvalidMask('Decoded mask is not binary.');
      }
      if (bit == 0) {
        encoder.encode(0, zero, zero + one);
      } else {
        encoder.encode(zero, one, zero + one);
      }
      padded[position] = bit;
      _updateCounts(counts, offset, bit);
    }
  }
  return '!${_pack(encoder.finish())}';
}

Uint8List _decodeOneBitRaster(String payload, int width, int height) {
  final decoder = _RangeDecoder(_unpack(payload.substring(1)));
  final counts = List<int>.filled(_contextCount * 2, 1);
  final paddedWidth = width + 2 * _padding;
  final padded = Uint8List(paddedWidth * (height + _padding));
  final output = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    final row = (y + _padding) * paddedWidth + _padding;
    for (var x = 0; x < width; x++) {
      final position = row + x;
      final context = _contextAt(
        padded,
        position,
        position - paddedWidth,
        position - 2 * paddedWidth,
      );
      final offset = context << 1;
      final zero = counts[offset];
      final one = counts[offset + 1];
      final value = decoder.frequency(zero + one);
      final bit = value < zero ? 0 : 1;
      if (bit == 0) {
        decoder.decode(0, zero);
      } else {
        decoder.decode(zero, one);
      }
      padded[position] = bit;
      output[y * width + x] = bit;
      _updateCounts(counts, offset, bit);
    }
  }
  return output;
}

/// Parses one `<|mask;…|>` token into its spec. Fields are split on `;`
/// (never searched as `key=`: the payload itself may contain `=`).
/// Returns null for anything that is not a well-formed mask token.
/// Pure; never throws.
SamMaskSpec? parseSamMaskToken(String token) {
  try {
    final t = token.trim();
    final start = t.indexOf('<|mask;');
    final end = t.indexOf('|>', start);
    if (start < 0 || end <= start) return null;
    final body = t.substring(start + '<|mask;'.length, end);
    String? data;
    for (final part in body.split(';')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      if (part.substring(0, i) == 'data') data = part.substring(i + 1);
    }
    if (data == null || data.isEmpty) return null;
    // data = H,W,<enc>payload — only the first two commas split.
    final c1 = data.indexOf(',');
    final c2 = c1 < 0 ? -1 : data.indexOf(',', c1 + 1);
    if (c1 <= 0 || c2 <= c1 + 1 || c2 + 2 >= data.length) return null;
    final h = int.tryParse(data.substring(0, c1));
    final w = int.tryParse(data.substring(c1 + 1, c2));
    if (h == null || w == null) return null;
    final payload = data.substring(c2 + 1);
    if (payload.isEmpty) return null;
    final marker = payload[0];
    final encoding = marker == '~'
        ? 'lossless'
        : marker == '!'
        ? 'one_bit'
        : null;
    if (encoding == null) return null;
    if (w <= 0 || h <= 0 || w > _maxSide || h > _maxSide) return null;
    if (w * h > _maxArea) return null;
    return SamMaskSpec(
      encoding: encoding,
      payload: payload,
      width: w,
      height: h,
    );
  } catch (_) {
    return null;
  }
}

/// Decodes one mask into a row-major 0/1 raster ([height] rows of
/// [width] cells). Returns null when the payload is invalid.
/// Pure; never throws.
Uint8List? decodeSamMask(SamMaskSpec spec) {
  try {
    if (spec.width <= 0 ||
        spec.height <= 0 ||
        spec.width > _maxSide ||
        spec.height > _maxSide) {
      return null;
    }
    if (spec.width * spec.height > _maxArea) return null;
    if (spec.encoding == 'lossless') {
      if (!spec.payload.startsWith('~')) return null;
      final coverage = _decodeLosslessRaster(
        spec.payload,
        spec.width,
        spec.height,
      );
      final out = Uint8List(coverage.length);
      for (var i = 0; i < coverage.length; i++) {
        out[i] = coverage[i] >= 129 ? 1 : 0;
      }
      return out;
    }
    if (spec.encoding == 'one_bit') {
      if (!spec.payload.startsWith('!')) return null;
      final raster = _decodeOneBitRaster(
        spec.payload,
        spec.width,
        spec.height,
      );
      // Canonical round trip: non-canonical spellings are rejected.
      if (_encodeRaster(raster, spec.width, spec.height) != spec.payload) {
        return null;
      }
      return raster;
    }
    return null;
  } catch (_) {
    return null;
  }
}

final Map<String, Uint8List?> _decodeCache = {};

/// Parses and decodes one raw mask token with a small session cache.
/// Returns null for empty/invalid tokens. Never throws.
Uint8List? decodeSamMaskToken(String token) {
  if (token.isEmpty) return null;
  if (_decodeCache.containsKey(token)) return _decodeCache[token];
  Uint8List? out;
  final spec = parseSamMaskToken(token);
  if (spec != null) out = decodeSamMask(spec);
  if (_decodeCache.length >= 64) {
    _decodeCache.remove(_decodeCache.keys.first);
  }
  _decodeCache[token] = out;
  return out;
}

/// Row runs of filled cells for painters: one [SamMaskRun] per
/// contiguous 1-stretch. Empty raster → empty list. Never throws.
List<SamMaskRun> samMaskRuns(Uint8List raster, int width, int height) {
  final runs = <SamMaskRun>[];
  try {
    if (width <= 0 || height <= 0) return runs;
    if (raster.length < width * height) return runs;
    for (var y = 0; y < height; y++) {
      var x = 0;
      while (x < width) {
        if (raster[y * width + x] != 1) {
          x++;
          continue;
        }
        var end = x;
        while (end + 1 < width && raster[y * width + end + 1] == 1) {
          end++;
        }
        runs.add(SamMaskRun(y, x, end));
        x = end + 1;
      }
    }
  } catch (_) {}
  return runs;
}

/// Normalized (0..1) centroid of the filled cells, for placing the
/// cover number on the shape instead of the box middle. Empty raster
/// → the box center. Never throws.
({double x, double y}) samMaskCentroid(
  Uint8List raster,
  int width,
  int height,
) {
  try {
    if (width <= 0 || height <= 0) return (x: 0.5, y: 0.5);
    if (raster.length < width * height) return (x: 0.5, y: 0.5);
    var sx = 0.0;
    var sy = 0.0;
    var n = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (raster[y * width + x] == 1) {
          sx += x + 0.5;
          sy += y + 0.5;
          n++;
        }
      }
    }
    if (n == 0) return (x: 0.5, y: 0.5);
    return (x: (sx / n / width).clamp(0.0, 1.0), y: (sy / n / height).clamp(0.0, 1.0));
  } catch (_) {
    return (x: 0.5, y: 0.5);
  }
}
