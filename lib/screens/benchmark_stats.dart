import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/app_feedback.dart';
import '../widgets/ai_help_button.dart';
import '../theme/app_colors.dart' show blue, blueDark, trail;

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
        actions: const [
          AiHelpButton(topic: AiHelpTopics.benchmark),
          SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _headerCard(),
          const SizedBox(height: 12),
          _statRow(),
          const SizedBox(height: 12),
          _card(
            title: tr('bstat_progress'),
            subtitle: widget.higherIsBetter
                ? tr('bstat_higher', {'n': _attempts.length})
                : tr('bstat_lower', {'n': _attempts.length}),
            trailing: _pill(
              _attempts.isEmpty
                  ? tr('bstat_nodata')
                  : tr('bstat_tries', {'n': _attempts.length}),
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
            title: tr('bstat_community'),
            subtitle: tr('bstat_compare'),
            trailing: _pill(tr('bstat_soon')),
            child: Container(
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
                      _attempts.isEmpty
                          ? tr('bstat_play_first')
                          : tr('bstat_cloud', {'n': _attempts.length}),
                      style: TextStyle(
                        color: context.inkText,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
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
              child: Text(
                tr('bstat_play'),
                style: const TextStyle(
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
                _best == null
                    ? '—'
                    : tr('bstat_best_value', {
                        'n': _best!,
                        'label': widget.bestLabel,
                      }),
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                tr('bstat_best'),
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

  Widget _statRow() {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            tr('bstat_best'),
            _best == null ? '—' : '$_best',
            widget.bestLabel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            tr('bstat_tries_label'),
            _attempts.isEmpty ? '—' : '${_attempts.length}',
            _attempts.isEmpty
                ? tr('bstat_play_first_short')
                : tr('bstat_this_game'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            tr('bstat_last'),
            _attempts.isEmpty ? '—' : '${_attempts.last}',
            widget.bestLabel,
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
          tr('bstat_empty'),
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
    case 'spatial':
      return HugeIcons.strokeRoundedCastle01;
    default:
      return HugeIcons.strokeRoundedTimer01;
  }
}
