import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'app_kit.dart';

/// Decodes a `data:image/...;base64,<payload>` URI into bytes. Returns
/// null for anything else (network URLs, empty or plain refs) and for
/// malformed payloads, so callers can fall back to network loading or a
/// placeholder. Never throws.
Uint8List? decodeDataImage(String ref) {
  final t = ref.trim();
  if (!t.startsWith('data:image')) return null;
  final comma = t.indexOf(',');
  if (comma < 0 || comma + 1 >= t.length) return null;
  final header = t.substring(0, comma);
  if (!header.contains(';base64')) return null;
  try {
    return base64Decode(base64.normalize(t.substring(comma + 1).trim()));
  } catch (_) {
    return null;
  }
}

/// One AI picture renderer for every screen. Muse Image answers with
/// either a hosted URL or an embedded `data:image` payload, and
/// `Image.network` cannot draw the latter — so data URIs go to
/// `Image.memory`, http(s) refs to `Image.network`, and anything else
/// (empty, plain IDs, undecodable payloads) renders [fallback] and
/// reports [onError].
class AiImage extends StatefulWidget {
  final String imageRef;
  final double? height;
  final double? width;
  final BoxFit fit;
  final int? cacheWidth;
  final Widget? loading;
  final Widget fallback;
  final VoidCallback? onError;

  const AiImage({
    super.key,
    required this.imageRef,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.loading,
    this.fallback = const SizedBox.shrink(),
    this.onError,
  });

  @override
  State<AiImage> createState() => _AiImageState();
}

class _AiImageState extends State<AiImage> {
  String? _ref;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _syncRef();
  }

  @override
  void didUpdateWidget(AiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageRef.trim() != _ref) _syncRef();
  }

  void _syncRef() {
    final t = widget.imageRef.trim();
    _ref = t;
    _bytes = t.startsWith('data:image') ? decodeDataImage(t) : null;
  }

  void _report() {
    final cb = widget.onError;
    if (cb == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => cb());
  }

  Widget _loadingBox() {
    final ph =
        widget.loading ??
        AppSkeleton(height: widget.height ?? 160, width: widget.width);
    final h = widget.height;
    if (h == null) return Center(child: ph);
    return SizedBox(
      height: h,
      child: Center(child: ph),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.imageRef.trim();
    final height = widget.height;
    final width = widget.width;
    final fit = widget.fit;
    final cacheWidth = widget.cacheWidth;
    final fallback = widget.fallback;
    if (ref.startsWith('data:image')) {
      final bytes = _bytes;
      if (bytes == null) {
        _report();
        return fallback;
      }
      return Image.memory(
        bytes,
        height: height,
        width: width,
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSync) => wasSync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                child: child,
              ),
        errorBuilder: (context, error, stack) {
          _report();
          return fallback;
        },
      );
    }
    if (ref.startsWith('http://') || ref.startsWith('https://')) {
      return Image.network(
        ref,
        height: height,
        width: width,
        fit: fit,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSync) => wasSync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                child: child,
              ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _loadingBox();
        },
        errorBuilder: (context, error, stack) {
          _report();
          return fallback;
        },
      );
    }
    return fallback;
  }
}
