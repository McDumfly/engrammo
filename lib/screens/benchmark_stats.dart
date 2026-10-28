import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';
import '../services/app_feedback.dart';
import '../theme/app_colors.dart' show ink, blue, blueDark, trail, orange;

/// Részletező képernyő egy benchmark feladathoz.
///
/// Két kártya, az app stílusában (fehér kártya, 2px `line` keret,
/// 16-os rádiusz):
///  1. "Your progress" – a saját próbálkozások vonaldiagramja.
///  2. "Community" – oszlopdiagram a szintek eloszlásáról, átlaggal
///     és a saját eredménnyel megjelölve.
class BenchmarkDetailPage extends StatefulWidget {
  final String gameId;
  final String title;
  final String subtitle;
  final Color tint;
  final String bestLabel;
  final bool higherIsBetter;
  final int? best;
  final List<int> attempts;
  final Widget Function() buildGame;
  final int? Function()? loadBest;
  final List<int> Function()? loadAttempts;

  const BenchmarkDetailPage({
    super.key,
    required this.gameId,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.bestLabel,
    required this.higherIsBetter,
    required this.best,
    required this.attempts,
    required this.buildGame,
    this.loadBest,
    this.loadAttempts,
  });

  @override
  State<BenchmarkDetailPage> createState() => _BenchmarkDetailPageState();
}

class _CommunityData {
  final String averageLabel;
  final List<String> buckets;
  final List<double> percents;
  const _CommunityData(this.averageLabel, this.buckets, this.percents);
}

/// Közösségi eloszlás játékonként. Backend nélkül nincs közösségi adat:
/// minden sáv 0, az átlagjel pedig gondolatjel. A sávcímkék a játék
/// mérőszámához igazodnak, de érték nélkül maradnak.
_CommunityData _communityFor(String id) {
  switch (id) {
    case 'sequence':
      return const _CommunityData(
        '—',
        ['1–3', '4–5', '6–7', '8–9', '10+'],
        [0, 0, 0, 0, 0],
      );
    case 'number':
      return const _CommunityData(
        '—',
        ['3–4', '5–6', '7–8', '9–10', '11+'],
        [0, 0, 0, 0, 0],
      );
    case 'verbal':
      return const _CommunityData(
        '—',
        ['0–20', '21–40', '41–60', '61–80', '81+'],
        [0, 0, 0, 0, 0],
      );
    case 'visual':
      return const _CommunityData(
        '—',
        ['1–3', '4–5', '6–7', '8–9', '10+'],
        [0, 0, 0, 0, 0],
      );
    case 'order':
      return const _CommunityData(
        '—',
        ['3–4', '5–6', '7–8', '9–10', '11+'],
        [0, 0, 0, 0, 0],
      );
    default:
      return const _CommunityData(
        '—',
        ['1', '2', '3', '4', '5'],
        [0, 0, 0, 0, 0],
      );
  }
}

/// Saját eredmény melyik sávba esik (0..4), vagy null ha nincs adat.
int? _bucketFor(String id, int best) {
  switch (id) {
    case 'sequence':
    case 'visual':
      if (best <= 3) return 0;
      if (best <= 5) return 1;
      if (best <= 7) return 2;
      if (best <= 9) return 3;
      return 4;
    case 'number':
      if (best <= 4) return 0;
      if (best <= 6) return 1;
      if (best <= 8) return 2;
      if (best <= 10) return 3;
      return 4;
    case 'order':
      if (best <= 4) return 0;
      if (best <= 6) return 1;
      if (best <= 8) return 2;
      if (best <= 10) return 3;
      return 4;
    case 'verbal':
      if (best <= 20) return 0;
      if (best <= 40) return 1;
      if (best <= 60) return 2;
      if (best <= 80) return 3;
      return 4;
    default:
      return null;
  }
}

String _topTextFor(String id, int best) {
  final b = _bucketFor(id, best);
  if (b == null) return '—';
  if (b == 0) return 'Top 25%';
  if (b == 1) return 'Top 35%';
  if (b == 2) return 'Top 60%';
  if (b == 3) return 'Top 85%';
  return 'Top 95%';
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;
  _LineChartPainter({
    required this.values,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 24.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0 || values.isEmpty) return;

    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    if ((maxV - minV).abs() < 1e-6) {
      minV -= 1;
      maxV += 1;
    }
    final pad = (maxV - minV) * 0.2;
    minV -= pad;
    maxV += pad;

    Offset pt(int i) {
      final x = values.length == 1
          ? left + w / 2
          : left + w * i / (values.length - 1);
      final y = top + h * (1 - (values[i] - minV) / (maxV - minV));
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final labelStyle = TextStyle(color: labelColor, fontSize: 10);
    for (var g = 0; g <= 3; g++) {
      final y = top + h * g / 3;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), gridPaint);
      final v = maxV - (maxV - minV) * g / 3;
      final tp = TextPainter(
        text: TextSpan(text: _fmt(v), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 4);
      tp.paint(canvas, Offset(0, y - 7));
    }

    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(pt(values.length - 1).dx, top + h)
      ..lineTo(pt(0).dx, top + h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fillColor.withValues(alpha: 0.45),
            fillColor.withValues(alpha: 0.05),
          ],
        ).createShader(Rect.fromLTWH(0, top, size.width, h)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final p = pt(i);
      canvas.drawCircle(p, 7, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        7,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(p, 3, Paint()..color = lineColor);
    }
    // X labels: first / last try.
    final xStyle = TextStyle(color: labelColor, fontSize: 10);
    for (final entry in [(0, '#1'), (values.length - 1, '#${values.length}')]) {
      final tp = TextPainter(
        text: TextSpan(text: entry.$2, style: xStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = pt(entry.$1);
      tp.paint(
        canvas,
        Offset(
          (p.dx - tp.width / 2).clamp(0, size.width - tp.width),
          top + h + 6,
        ),
      );
    }
  }

  String _fmt(double v) {
    if (v >= 100) return v.round().toString();
    if (v >= 10) return v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
    return v.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values ||
      old.lineColor != lineColor ||
      old.fillColor != fillColor ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor;
}

class _BenchmarkDetailPageState extends State<BenchmarkDetailPage> {
  late List<int> _attempts;
  int? _best;

  @override
  void initState() {
    super.initState();
    _attempts = List.of(widget.attempts);
    _best = widget.best;
  }

  @override
  Widget build(BuildContext context) {
    final community = _communityFor(widget.gameId);
    final youBucket = _best == null ? null : _bucketFor(widget.gameId, _best!);
    final maxP = community.percents.fold<double>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Theme.of(context).colorScheme.onSurface,
            size: 24,
            strokeWidth: 2.2,
          ),
          onPressed: () {
            AppFeedback.light();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _headerCard(),
          const SizedBox(height: 12),
          _statRow(community),
          const SizedBox(height: 12),
          _card(
            title: 'Your progress',
            subtitle: widget.higherIsBetter
                ? 'Higher is better • last ${_attempts.length} tries'
                : 'Lower is better • last ${_attempts.length} tries',
            trailing: _pill(
              _attempts.isEmpty ? 'NO DATA YET' : '${_attempts.length} TRIES',
            ),
            child: _attempts.isEmpty
                ? _emptyPersonal()
                : SizedBox(
                    height: 190,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _LineChartPainter(
                        values: [for (final v in _attempts) v.toDouble()],
                        lineColor: blueDark,
                        fillColor: trail,
                        gridColor: context.hairline,
                        labelColor: context.mutedText,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          _card(
            title: 'Community',
            subtitle: 'Where you stand vs others',
            trailing: _pill('AVG ${community.averageLabel}'),
            child: Column(
              children: [
                SizedBox(
                  height: 170,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < community.buckets.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: i == 0 ? 2 : 5,
                              right: i == community.buckets.length - 1 ? 2 : 5,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (youBucket == i)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ink,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '${community.percents[i].round()}%',
                                    style: TextStyle(
                                      color: context.mutedText,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Container(
                                  height: maxP <= 0
                                      ? 4
                                      : 110 * community.percents[i] / maxP,
                                  decoration: BoxDecoration(
                                    color: youBucket == i ? orange : blue,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var i = 0; i < community.buckets.length; i++)
                      Expanded(
                        child: Text(
                          community.buckets[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: youBucket == i
                                ? context.inkText
                                : context.mutedText,
                            fontWeight: youBucket == i
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.hairline, width: 2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedUserGroup,
                          color: blueDark,
                          size: 20,
                          strokeWidth: 2.0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _best == null
                              ? 'Play once and your bar lights up here against the average of ${community.averageLabel}.'
                              : 'Your best ${_best!} ${widget.bestLabel} vs the ${community.averageLabel} average.',
                          style: TextStyle(
                            color: context.inkText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              AppFeedback.light();
              await Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => widget.buildGame()));
              if (mounted &&
                  (widget.loadAttempts != null || widget.loadBest != null)) {
                setState(() {
                  if (widget.loadAttempts != null) {
                    _attempts = widget.loadAttempts!();
                  }
                  if (widget.loadBest != null) _best = widget.loadBest!();
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: blue,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: blueDark.withValues(alpha: 0.5),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'PLAY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: _iconFor(widget.gameId),
              color: widget.tint,
              size: 26,
              strokeWidth: 2.0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  widget.subtitle,
                  style: TextStyle(color: context.mutedText, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _best == null ? '—' : '${_best!} ${widget.bestLabel}',
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'BEST',
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statRow(_CommunityData community) {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            'BEST',
            _best == null ? '—' : '$_best',
            widget.bestLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat('AVERAGE', community.averageLabel, 'community'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            'RANK',
            _best == null ? '—' : _topTextFor(widget.gameId, _best!),
            _best == null ? 'play first' : 'of players',
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: blueDark,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(sub, style: TextStyle(color: context.mutedText, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required String subtitle,
    required Widget trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: context.mutedText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: context.isDark ? blue : blueDark,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _emptyPersonal() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hairline, width: 2),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No tries yet — tap PLAY and your curve appears here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedText, fontSize: 13),
        ),
      ),
    );
  }
}

List<List<dynamic>> _iconFor(String id) {
  switch (id) {
    case 'sequence':
      return HugeIcons.strokeRoundedLayers01;
    case 'number':
      return HugeIcons.strokeRoundedHash;
    case 'verbal':
      return HugeIcons.strokeRoundedNotebook01;
    case 'visual':
      return HugeIcons.strokeRoundedEye;
    case 'order':
      return HugeIcons.strokeRoundedBrain01;
    default:
      return HugeIcons.strokeRoundedTimer01;
  }
}
