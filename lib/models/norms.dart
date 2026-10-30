library;

import 'dart:math' as math;

class LiteratureNorm {
  final String paradigmId;

  final String metric;
  final double mean;
  final double sd;
  final String source;
  const LiteratureNorm({
    required this.paradigmId,
    required this.metric,
    required this.mean,
    required this.sd,
    required this.source,
  });
}

const literatureNorms = <LiteratureNorm>[
  LiteratureNorm(
    paradigmId: 'backward-span',
    metric: 'span',
    mean: 4.7,
    sd: 1.2,
    source: 'WAIS-IV Digit Span backward raw (Wechsler 2008; '
        'López-Martos et al. 2023 ref: M≈4.7, SD≈1.2)',
  ),
  LiteratureNorm(
    paradigmId: 'iconic-probe',
    metric: 'span',
    mean: 6.2,
    sd: 1.1,
    source: 'WAIS-IV Digit Span forward raw (Wechsler 2008; '
        'López-Martos et al. 2023 ref: M≈6.2, SD≈1.1)',
  ),
  LiteratureNorm(
    paradigmId: 'corsi-span',
    metric: 'span',
    mean: 6.2,
    sd: 1.3,
    source: 'Corsi block span forward (Kessels et al. 2000: M=6.2, SD=1.3)',
  ),
  LiteratureNorm(
    paradigmId: 'change-detection',
    metric: 'k',
    mean: 3.0,
    sd: 0.8,
    source: 'Visual array capacity K for colors (Luck & Vogel 1997; '
        'Cowan 2001: K≈3-4)',
  ),
];

LiteratureNorm? priorFor(String paradigmId) {
  for (final n in literatureNorms) {
    if (n.paradigmId == paradigmId) return n;
  }
  return null;
}

const minNormN = 10;

const minReliabilityN = 20;

const maxStoredRuns = 200;

const minReliability = 0.70;

double zScore(double raw, LiteratureNorm norm) =>
    norm.sd <= 0 ? 0 : (raw - norm.mean) / norm.sd;

double normalCdf(double z) {
  final t = 1 / (1 + 0.2316419 * z.abs());
  final d = 0.3989423 * math.exp(-z * z / 2);
  var p = d *
      t *
      (0.3193815 +
          t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
  p = 1 - p;
  return z >= 0 ? p : 1 - p;
}

double percentileFromZ(double z) =>
    (normalCdf(z) * 100).clamp(0.0, 100.0);

String bandForPercentile(double pct) {
  if (pct >= 84) return 'above the lab average';
  if (pct >= 50) return 'around the lab average';
  if (pct >= 16) return 'below the lab average';
  return 'well below the lab average';
}

double _mean(List<double> xs) =>
    xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

double _sampleVariance(List<double> xs) {
  if (xs.length < 2) return 0;
  final m = _mean(xs);
  var s = 0.0;
  for (final x in xs) {
    s += (x - m) * (x - m);
  }
  return s / (xs.length - 1);
}

double _pearson(List<double> xs, List<double> ys) {
  if (xs.length != ys.length || xs.length < 3) return double.nan;
  final mx = _mean(xs);
  final my = _mean(ys);
  var cov = 0.0, vx = 0.0, vy = 0.0;
  for (var i = 0; i < xs.length; i++) {
    cov += (xs[i] - mx) * (ys[i] - my);
    vx += (xs[i] - mx) * (xs[i] - mx);
    vy += (ys[i] - my) * (ys[i] - my);
  }
  if (vx <= 0 || vy <= 0) return double.nan;
  return cov / math.sqrt(vx * vy);
}

double? cronbachAlpha(List<List<double>> persons) {
  if (persons.length < 3) return null;
  final k = persons.first.length;
  if (k < 2 || persons.any((row) => row.length != k)) return null;
  var itemVarSum = 0.0;
  for (var j = 0; j < k; j++) {
    itemVarSum += _sampleVariance([for (final row in persons) row[j]]);
  }
  final totals = [for (final row in persons) row.reduce((a, b) => a + b)];
  final totalVar = _sampleVariance(totals);
  if (totalVar <= 0) return null;
  return (k / (k - 1)) * (1 - itemVarSum / totalVar);
}

double? splitHalfReliability(List<List<double>> persons) {
  if (persons.length < 3) return null;
  final k = persons.first.length;
  if (k < 2 || persons.any((row) => row.length != k)) return null;
  final odd = <double>[];
  final even = <double>[];
  for (final row in persons) {
    var o = 0.0, e = 0.0;
    for (var j = 0; j < k; j++) {
      if (j.isEven) {
        o += row[j];
      } else {
        e += row[j];
      }
    }
    odd.add(o);
    even.add(e);
  }
  final r = _pearson(odd, even);
  if (r.isNaN || (1 + r) <= 0) return null;
  return (2 * r) / (1 + r);
}

List<double> itemDifficulties(List<List<double>> persons) {
  if (persons.isEmpty) return const [];
  final k = persons.first.length;
  return [
    for (var j = 0; j < k; j++)
      _mean([for (final row in persons) row[j]]),
  ];
}

List<double> itemDiscriminations(List<List<double>> persons) {
  if (persons.length < 6) return List.filled(persons.first.length, 0);
  final order = List<List<double>>.of(persons)
    ..sort(
      (a, b) => b.reduce((x, y) => x + y).compareTo(a.reduce((x, y) => x + y)),
    );
  final third = (order.length / 3).floor().clamp(1, order.length);
  final top = order.take(third).toList();
  final bottom = order.reversed.take(third).toList();
  final k = order.first.length;
  return [
    for (var j = 0; j < k; j++)
      _mean([for (final row in top) row[j]]) -
          _mean([for (final row in bottom) row[j]]),
  ];
}

class LocalNorm {
  int n;
  double mean;
  double m2;
  LocalNorm({this.n = 0, this.mean = 0, this.m2 = 0});

  void add(double x) {
    n++;
    final delta = x - mean;
    mean += delta / n;
    m2 += delta * (x - mean);
  }

  double get sd => n < 2 ? 0 : math.sqrt(m2 / (n - 1));

  Map<String, dynamic> toJson() => {'n': n, 'mean': mean, 'm2': m2};

  factory LocalNorm.fromJson(Map<String, dynamic> json) => LocalNorm(
        n: (json['n'] as num?)?.toInt() ?? 0,
        mean: (json['mean'] as num?)?.toDouble() ?? 0,
        m2: (json['m2'] as num?)?.toDouble() ?? 0,
      );
}
