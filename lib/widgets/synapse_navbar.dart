import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/app_feedback.dart';

class SynapseTab {
  final List<List<dynamic>> icon;
  final String label;
  const SynapseTab(this.icon, this.label);
}

class _MaskedFillHugeIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color fillColor;
  final double size;

  const _MaskedFillHugeIcon({
    required this.icon,
    required this.fillColor,
    this.size = 26,
  });

  /// Az SVG-string felépítése + parse-olása drága, és a navbar
  /// animációja képkockánként újraépítené mind a 10 ikont.
  /// Ikononként + színenként egyszer építjük fel, utána a
  /// flutter_svg saját picture-gyorsítótára adja vissza.
  static final Map<String, String> _svgCache = {};

  String _cachedSvg() {
    // Az icon-listák const-ok, így az identity stabil kulcs.
    final key = '${identityHashCode(icon)}|${fillColor.toARGB32()}';
    return _svgCache.putIfAbsent(key, _buildSvg);
  }

  static bool _isClosed(String tag, Map<String, dynamic> attrs) {
    if (tag == 'circle' ||
        tag == 'rect' ||
        tag == 'ellipse' ||
        tag == 'polygon') {
      return true;
    }
    if (tag == 'line' || tag == 'polyline') return false;
    final d = attrs['d']?.toString().trim() ?? '';
    return d.endsWith('Z') || d.endsWith('z');
  }

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  static final _upperCase = RegExp(r'[A-Z]');

  String _buildSvg() {
    final white = _hex(fillColor);
    final buffer = StringBuffer()
      ..write(
        '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">',
      );
    for (final element in icon) {
      final tag = element[0] as String;
      final attrs = Map<String, dynamic>.from(element[1] as Map);
      final closed = _isClosed(tag, attrs);
      // Kard-trukk: a hosszu nyitott pengevonalak ket vege a markolatnal
      // kozel van egymashoz, ezert lezarva (Z) tomor penge-sziluettet
      // adnak. Rovid vonalakat (markolat, keresztvas) nem zarunk le,
      // azok vonalkent maradnak.
      final d = attrs['d']?.toString() ?? '';
      // Sulyzorud: ket parhuzamos nyitott vonal a rud ket ele.
      // Z-vel nem zarhato, mert csak a masodik reszt
      // zarna vissza. Helyette a negy sarokpont kozott
      // negyszoget toltunk ki: ez a rud belseje.
      final isDumbbellRod =
          d.contains('7.73438') && d.contains('10.2344');
      final forceClose =
          !closed && tag == 'path' && d.length > 80 && !isDumbbellRod;
      if (isDumbbellRod) {
        buffer.write(
          '<path d="M7.73438 13.7323 L13.7344 7.73044 L16.2344 '
          '10.2312 L10.2344 16.2331 Z" fill="$white" stroke="$white" '
          'stroke-width="1.5" stroke-linejoin="round"/>',
        );
      }
      if (forceClose) {
        buffer.write(
          '<path d="$d Z" fill="$white" stroke="$white" '
          'stroke-width="1.5" stroke-linejoin="round" '
          'stroke-linecap="round"/>',
        );
      }
      buffer.write('<$tag');
      var hasFill = false;
      var hasStroke = false;
      var hasStrokeWidth = false;
      for (final entry in attrs.entries) {
        final key = entry.key;
        if (key == 'key') continue;
        if (key == 'opacity') continue;
        final value = entry.value.toString();
        String finalValue = value;
        if (key == 'stroke' && value == 'currentColor') {
          finalValue = white;
          hasStroke = true;
        } else if (key == 'fill' && value == 'currentColor') {
          finalValue = white;
          hasFill = true;
        } else if (key == 'fill') {
          if (closed) {
            finalValue = white;
          } else {
            finalValue = 'none';
          }
          hasFill = true;
        } else if (key == 'strokeWidth') {
          finalValue = '1.5';
          hasStrokeWidth = true;
        }
        final svgName = key.replaceAllMapped(
          _upperCase,
          (m) => '-${m[0]!.toLowerCase()}',
        );
        buffer.write(' $svgName="$finalValue"');
      }
      if (!hasFill) {
        buffer.write(closed ? ' fill="$white"' : ' fill="none"');
      }
      if (!hasStroke) {
        buffer.write(' stroke="$white"');
      }
      if (!hasStrokeWidth) {
        buffer.write(' stroke-width="1.5"');
      }
      buffer.write('/>');
    }
    buffer.write('</svg>');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      // A string innen már gyorsítótárból jön, azonos stringre a
      // flutter_svg sem parse-ol újra (loader-key alapú cache).
      child: SvgPicture.string(
        _cachedSvg(),
        width: size,
        height: size,
      ),
    );
  }
}

class SynapseNavBar extends StatefulWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<SynapseTab> tabs;

  static const double buttonSize = 54;

  static const double itemGap = 6;

  const SynapseNavBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.tabs,
  });

  @override
  State<SynapseNavBar> createState() => _SynapseNavBarState();
}

class _SynapseNavBarState extends State<SynapseNavBar>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _goo;
  late double _fromPos;
  late double _toPos;

  int? _dragTarget;
  double? _dragPos;
  bool _dragging = false;

  double _dragVelocity = 0;
  double _lastDragPos = 0;
  DateTime _lastDragTime = DateTime.now();

  static const _ease = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    _fromPos = widget.index.toDouble();
    _toPos = widget.index.toDouble();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1,
    );
    _goo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _dragVelocity = 0;
        _ensureGooRunning();
      }
    });
  }

  @override
  void didUpdateWidget(SynapseNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index.toDouble() == _toPos) return;
    _fromPos = _currentPos();
    _toPos = widget.index.toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _fromPos = _toPos;
      _ctrl.value = 1;
      return;
    }
    final distance = (_toPos - _fromPos).abs();
    _ctrl.duration = Duration(
      milliseconds: (140 + 40 * distance).round().clamp(140, 220),
    );
    _ctrl.forward(from: 0);
    _ensureGooRunning();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _goo.dispose();
    super.dispose();
  }

  void _ensureGooRunning() {
    final busy = _dragging || _ctrl.isAnimating;
    if (busy && !_goo.isAnimating) {
      _goo.repeat();
    } else if (!busy && _goo.isAnimating) {
      _goo.stop();
    }
  }

  double _currentPos() {
    if (_dragging && _dragPos != null) return _dragPos!;
    if (!_ctrl.isAnimating && (_ctrl.value == 0 || _ctrl.value == 1)) {
      return _ctrl.value == 0 ? _fromPos : _toPos;
    }
    return _fromPos + (_toPos - _fromPos) * _ease.transform(_ctrl.value);
  }

  void _previewDragTarget(int i, double pos) {
    final n = widget.tabs.length;
    if (n <= 0) return;
    i = i.clamp(0, n - 1);
    pos = pos.clamp(0.0, (n - 1).toDouble());
    final now = DateTime.now();
    final dt =
        now.difference(_lastDragTime).inMicroseconds / 1000000.0;
    if (dt > 0.008) {
      final v = (pos - _lastDragPos) / dt;
      _dragVelocity = _dragVelocity * 0.7 + v.clamp(-12.0, 12.0) * 0.3;
      _lastDragPos = pos;
      _lastDragTime = now;
    }
    _dragTarget = i;
    _dragPos = pos;
    _ensureGooRunning();
    setState(() {});
  }

  void _commitDragTarget() {
    final target = _dragTarget;
    final lastPos = _dragPos;
    final fling = _dragVelocity;
    _dragging = false;
    _dragPos = null;
    _dragTarget = null;
    _dragVelocity = fling * 0.35;
    if (target != null && target != widget.index) {
      final maxPos = (widget.tabs.length - 1).toDouble();
      _fromPos = (lastPos ?? widget.index.toDouble()).clamp(0.0, maxPos);
      _toPos = target.toDouble();
      if (MediaQuery.disableAnimationsOf(context)) {
        _fromPos = _toPos;
        _ctrl.value = 1;
      } else {
        final distance = (_toPos - _fromPos).abs();
        _ctrl.duration = Duration(
          milliseconds: (140 + 40 * distance).round().clamp(140, 220),
        );
        _ctrl.forward(from: 0);
      }
      AppFeedback.light();
      widget.onSelect(target);
    } else {
      _dragVelocity = 0;
      setState(() {});
    }
    _ensureGooRunning();
  }

  int _dragIndexFromX(double dx) {
    final cellW = SynapseNavBar.buttonSize + SynapseNavBar.itemGap;
    return (dx / cellW).floor();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = widget.tabs.length;
    const gap = SynapseNavBar.itemGap;
    final rowW = n <= 0
        ? 0.0
        : n * SynapseNavBar.buttonSize + (n - 1) * gap;
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.35
                          : 0.10,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) {
                  _dragging = true;
                  _dragTarget = null;
                  _dragPos = widget.index.toDouble();
                  _dragVelocity = 0;
                  _lastDragPos = widget.index.toDouble();
                  _lastDragTime = DateTime.now();
                  _ensureGooRunning();
                },
                onHorizontalDragUpdate: (d) {
                  final cellW =
                      SynapseNavBar.buttonSize + SynapseNavBar.itemGap;
                  final pos = (d.localPosition.dx / cellW - 0.5)
                      .clamp(0.0, (widget.tabs.length - 1).toDouble());
                  _previewDragTarget(_dragIndexFromX(d.localPosition.dx), pos);
                },
                onHorizontalDragEnd: (d) {
                  final v = d.velocity.pixelsPerSecond.dx;
                  if (_dragTarget == null && v.abs() > 200) {
                    final n = widget.tabs.length;
                    final flick =
                        (widget.index + (v < 0 ? 1 : -1)).clamp(0, n - 1);
                    _dragTarget = flick;
                  }
                  _commitDragTarget();
                },
                onHorizontalDragCancel: () {
                  _dragging = false;
                  _dragPos = null;
                  _dragTarget = null;
                  _dragVelocity = 0;
                  _ensureGooRunning();
                },
                child: SizedBox(
                  width: rowW,
                  height: SynapseNavBar.buttonSize,
                  child: _NavIconStage(
                    tabs: widget.tabs,
                    selected: widget.index,
                    onTap: (i) {
                      AppFeedback.light();
                      widget.onSelect(i);
                    },
                    ctrl: _ctrl,
                    goo: _goo,
                    currentPos: _currentPos,
                    fromPos: () => _fromPos,
                    toPos: () => _toPos,
                    dragging: () => _dragging,
                    dragVelocity: () => _dragVelocity,
                    blobColor: scheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _glowEased(double pos, int i) {
    final glow = (1 - (pos - i).abs()).clamp(0.0, 1.0);
    return Curves.easeOut.transform(glow);
  }
}

/// Az ikonok animált rétege.
///
/// Az ikon-widget példányok egyszer, a [build]-ben jönnek létre; a
/// képkockánkénti builder már csak az olcsó skálázást, a blob-festést
/// és a klip-utat számolja újra. Így animáció közben nem születnek
/// új SVG-widgetek/loader-példányok 60 fps-sel.
class _NavIconStage extends StatelessWidget {
  final List<SynapseTab> tabs;
  final int selected;
  final ValueChanged<int> onTap;
  final AnimationController ctrl;
  final AnimationController goo;
  final double Function() currentPos;
  final double Function() fromPos;
  final double Function() toPos;
  final bool Function() dragging;
  final double Function() dragVelocity;
  final Color blobColor;

  const _NavIconStage({
    required this.tabs,
    required this.selected,
    required this.onTap,
    required this.ctrl,
    required this.goo,
    required this.currentPos,
    required this.fromPos,
    required this.toPos,
    required this.dragging,
    required this.dragVelocity,
    required this.blobColor,
  });

  Widget _plainIcon(ColorScheme scheme, int i) {
    final tab = tabs[i];
    final box = SizedBox(
      width: SynapseNavBar.buttonSize,
      height: SynapseNavBar.buttonSize,
      child: Center(
        child: HugeIcon(
          icon: tab.icon,
          size: 26,
          strokeWidth: 1.5,
          color: scheme.primary,
        ),
      ),
    );
    return Semantics(
      selected: i == selected,
      button: true,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: i == selected ? null : () => onTap(i),
        child: box,
      ),
    );
  }

  Widget _filledIcon(ColorScheme scheme, SynapseTab tab) {
    return SizedBox(
      width: SynapseNavBar.buttonSize,
      height: SynapseNavBar.buttonSize,
      child: Center(
        child: _MaskedFillHugeIcon(
          icon: tab.icon,
          fillColor: scheme.onPrimary,
          size: 26,
        ),
      ),
    );
  }

  Widget _scaledRow(List<Widget> icons, double pos) {
    const gap = SynapseNavBar.itemGap;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < icons.length; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          Transform.scale(
            scale: 1 + 0.16 * _SynapseNavBarState._glowEased(pos, i),
            child: icons[i],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plainIcons = <Widget>[
      for (var i = 0; i < tabs.length; i++) _plainIcon(scheme, i),
    ];
    final filledIcons = <Widget>[
      for (final tab in tabs) _filledIcon(scheme, tab),
    ];
    return AnimatedBuilder(
      animation: Listenable.merge([ctrl, goo]),
      builder: (context, _) {
        final pos = currentPos();
        final from = fromPos();
        final to = toPos();
        final isDragging = dragging();
        final velocity = dragVelocity();
        final t = ctrl.value;
        final flying = ctrl.isAnimating && from != to;
        final stretch = flying ? math.sin(math.pi * t) : 0.0;
        final distF = ((to - from).abs() / 1.5).clamp(0.0, 1.0);
        const cellW = SynapseNavBar.buttonSize + SynapseNavBar.itemGap;
        final cx = cellW * pos + SynapseNavBar.buttonSize / 2;
        final blobLeft = cx - SynapseNavBar.buttonSize / 2;
        final dragStretch = isDragging
            ? (velocity.abs() / 10.0).clamp(0.0, 0.55)
            : 0.0;
        final flingStretch = (velocity.abs() / 14.0).clamp(0.0, 0.35);
        final liquid = flying
            ? (0.45 * stretch * distF + flingStretch).clamp(0.0, 0.8)
            : dragStretch;
        final wobble =
            (isDragging || flying) ? goo.value * 2 * math.pi : 0.0;
        final blobActive = isDragging || flying;
        final blobS = liquid.clamp(0.0, 0.8);
        final blobScaleX = 1 + blobS;
        final blobScaleY = (1 - 0.38 * blobS).clamp(0.62, 1.0);
        final blobWobbleAmp =
            blobActive ? 0.055 + 0.05 * blobS : 0.0;
        final blobCy = SynapseNavBar.buttonSize / 2;
        return Stack(
          children: [
            Positioned(
              left: blobLeft - 10,
              top: -10,
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(
                    SynapseNavBar.buttonSize + 20,
                    SynapseNavBar.buttonSize + 20,
                  ),
                  painter: _LiquidBlobPainter(
                    color: blobColor,
                    stretch: liquid,
                    wobble: wobble,
                    active: blobActive,
                    velocity: isDragging ? velocity : (to - from),
                  ),
                ),
              ),
            ),
            _scaledRow(plainIcons, pos),
            ClipPath(
              clipper: _BlobClipper(
                cx: cx,
                cy: blobCy,
                baseR: SynapseNavBar.buttonSize / 2,
                scaleX: blobScaleX,
                scaleY: blobScaleY,
                wobbleAmp: blobWobbleAmp,
                wobble: wobble,
                active: blobActive,
              ),
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _scaledRow(filledIcons, pos),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Path buildLiquidBlobPath({
  required Offset center,
  required double baseR,
  required double scaleX,
  required double scaleY,
  required double wobbleAmp,
  required double wobble,
  required bool active,
}) {
  const segments = 32;
  final points = <Offset>[];
  for (var k = 0; k < segments; k++) {
    final theta = k / segments * 2 * math.pi;
    final wob = 1 +
        wobbleAmp * math.sin(3 * theta + wobble) +
        (active ? 0.02 * math.sin(5 * theta - wobble * 1.4) : 0);
    points.add(
      Offset(
        center.dx + math.cos(theta) * baseR * scaleX * wob,
        center.dy + math.sin(theta) * baseR * scaleY * wob,
      ),
    );
  }
  return smoothLiquidBlobPath(points);
}

Path smoothLiquidBlobPath(List<Offset> p) {
  final path = Path();
  if (p.isEmpty) return path;
  path.moveTo((p[0].dx + p.last.dx) / 2, (p[0].dy + p.last.dy) / 2);
  for (var i = 0; i < p.length; i++) {
    final curr = p[i];
    final next = p[(i + 1) % p.length];
    path.quadraticBezierTo(
      curr.dx,
      curr.dy,
      (curr.dx + next.dx) / 2,
      (curr.dy + next.dy) / 2,
    );
  }
  path.close();
  return path;
}

class _BlobClipper extends CustomClipper<Path> {
  final double cx;
  final double cy;
  final double baseR;
  final double scaleX;
  final double scaleY;
  final double wobbleAmp;
  final double wobble;
  final bool active;

  const _BlobClipper({
    required this.cx,
    required this.cy,
    required this.baseR,
    required this.scaleX,
    required this.scaleY,
    required this.wobbleAmp,
    required this.wobble,
    required this.active,
  });

  @override
  Path getClip(Size size) {
    return buildLiquidBlobPath(
      center: Offset(cx, cy),
      baseR: baseR,
      scaleX: scaleX,
      scaleY: scaleY,
      wobbleAmp: wobbleAmp,
      wobble: wobble,
      active: active,
    );
  }

  @override
  bool shouldReclip(_BlobClipper old) {
    return old.cx != cx ||
        old.cy != cy ||
        old.baseR != baseR ||
        old.scaleX != scaleX ||
        old.scaleY != scaleY ||
        old.wobbleAmp != wobbleAmp ||
        old.wobble != wobble ||
        old.active != active;
  }
}

class _LiquidBlobPainter extends CustomPainter {
  final Color color;
  final double stretch;
  final double wobble;
  final bool active;
  final double velocity;

  const _LiquidBlobPainter({
    required this.color,
    required this.stretch,
    required this.wobble,
    required this.active,
    required this.velocity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseR = SynapseNavBar.buttonSize / 2;
    final s = stretch.clamp(0.0, 0.8);
    final scaleX = 1 + s;
    final scaleY = (1 - 0.38 * s).clamp(0.62, 1.0);
    final wobbleAmp = active ? 0.055 + 0.05 * s : 0.0;

    final blob = buildLiquidBlobPath(
      center: center,
      baseR: baseR,
      scaleX: scaleX,
      scaleY: scaleY,
      wobbleAmp: wobbleAmp,
      wobble: wobble,
      active: active,
    );
    canvas.drawPath(blob, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LiquidBlobPainter old) {
    return old.color != color ||
        old.stretch != stretch ||
        old.wobble != wobble ||
        old.active != active ||
        old.velocity != velocity;
  }
}
