library;

import '../l10n/app_localizations.dart';
import 'curriculum.dart' show chapterDepth;

bool isFoundationLesson(int chapter, int section, int lesson) {
  if (chapter < 0 || section < 0 || lesson < 0) return false;
  return chapterDepth(chapter) == 0 && section == 0 && lesson <= 1;
}

bool wantsLagIntroduction(int chapter, int section, int lag) {
  if (lag <= 0 || chapter < 0) return false;
  return chapterDepth(chapter) == 0 && section == 1;
}

class WorkedExample {
  final String situation;

  final List<String> thinkAloud;

  final String payoff;

  const WorkedExample({
    required this.situation,
    required this.thinkAloud,
    required this.payoff,
  });
}

WorkedExample workedExampleForTrack(int track, [String locale = 'en']) {
  final t = track.clamp(0, 5);
  return WorkedExample(
    situation: trFor(locale, 'fnd_ex_${t}_situation'),
    thinkAloud: [
      trFor(locale, 'fnd_ex_${t}_think0'),
      trFor(locale, 'fnd_ex_${t}_think1'),
      trFor(locale, 'fnd_ex_${t}_think2'),
    ],
    payoff: trFor(locale, 'fnd_ex_${t}_payoff'),
  );
}

String stimulusOrdinal(int index) {
  final k = index + 1;
  if (k == 1) return '1st';
  if (k == 2) return '2nd';
  if (k == 3) return '3rd';
  return '${k}th';
}

String stimulusOrdinalIn(String locale, int index) {
  final k = index + 1;
  if (k == 1) return trFor(locale, 'fnd_ord_1');
  if (k == 2) return trFor(locale, 'fnd_ord_2');
  if (k == 3) return trFor(locale, 'fnd_ord_3');
  return trFor(locale, 'fnd_ord_n', {'k': k});
}

String drillKindLabel(String kind) {
  switch (kind) {
    case 'number':
      return 'number';
    case 'sequence':
    case 'working':
    case 'order':
    case 'duel':
      return 'digit row';
    case 'sensory':
      return 'digit flash';
    case 'interference':
      return 'trigram';
    case 'spatial':
      return 'stations walk';
    case 'visual':
      return 'scene';
    case 'pattern':
      return 'grid';
    case 'episodic':
      return 'story';
    case 'semantic':
      return 'category';
    case 'verbal':
      return 'word pair';
    case 'face':
      return 'face + name';
    case 'foreign':
      return 'foreign word';
    case 'prospective':
      return 'if-then plan';
    case 'poem':
      return 'verse chunk';
    case 'replay':
      return 'mini-day';
    default:
      return 'drill';
  }
}

String _drillKindKey(String kind) {
  switch (kind) {
    case 'number':
      return 'fnd_kind_number';
    case 'sequence':
    case 'working':
    case 'order':
    case 'duel':
      return 'fnd_kind_digitrow';
    case 'sensory':
      return 'fnd_kind_digitflash';
    case 'interference':
      return 'fnd_kind_trigram';
    case 'spatial':
      return 'fnd_kind_stations';
    case 'visual':
      return 'fnd_kind_scene';
    case 'pattern':
      return 'fnd_kind_grid';
    case 'episodic':
      return 'fnd_kind_story';
    case 'semantic':
      return 'fnd_kind_category';
    case 'verbal':
      return 'fnd_kind_wordpair';
    case 'face':
      return 'fnd_kind_face';
    case 'foreign':
      return 'fnd_kind_foreign';
    case 'prospective':
      return 'fnd_kind_ifthen';
    case 'poem':
      return 'fnd_kind_verse';
    case 'replay':
      return 'fnd_kind_miniday';
    default:
      return 'fnd_kind_drill';
  }
}

String drillKindLabelIn(String locale, String kind) =>
    trFor(locale, _drillKindKey(kind));

String stimulusBadge(int round, int total, String kind) {
  return 'Drill ${round + 1} of $total · ${drillKindLabel(kind)}';
}

String stimulusBadgeIn(String locale, int round, int total, String kind) {
  return trFor(locale, 'fnd_badge', {
    'i': round + 1,
    'n': total,
    'kind': drillKindLabelIn(locale, kind),
  });
}

String delayedQuestionLead(int round, int total, String kind) {
  return 'About drill ${round + 1} of $total (${drillKindLabel(kind)}):';
}

String delayedQuestionLeadIn(String locale, int round, int total, String kind) {
  return trFor(locale, 'fnd_delayed', {
    'i': round + 1,
    'n': total,
    'kind': drillKindLabelIn(locale, kind),
  });
}
