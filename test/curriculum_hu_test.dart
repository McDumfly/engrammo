import 'package:engrammo/l10n/app_localizations.dart';
import 'package:engrammo/l10n/curriculum_hu.dart';
import 'package:engrammo/l10n/lesson_content_hu.dart';
import 'package:engrammo/models/curriculum.dart';
import 'package:engrammo/models/lesson_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hungarian curriculum mirrors the English structure', () {
    expect(chaptersHu.length, chapters.length);
    for (var c = 0; c < chapters.length; c++) {
      final en = chapters[c];
      final hu = chaptersHu[c];
      expect(
        hu.sections.length,
        en.sections.length,
        reason: 'chapter $c (${en.realm}) section count',
      );
      for (var s = 0; s < en.sections.length; s++) {
        expect(
          hu.sections[s].lessons.length,
          en.sections[s].lessons.length,
          reason: 'chapter $c section $s (${en.sections[s].name}) lesson count',
        );
      }
    }
  });

  test('Hungarian curriculum strings are non-empty', () {
    for (var c = 0; c < chaptersHu.length; c++) {
      final hu = chaptersHu[c];
      expect(hu.realm, isNotEmpty, reason: 'chapter $c realm');
      expect(hu.tagline, isNotEmpty, reason: 'chapter $c tagline');
      for (var s = 0; s < hu.sections.length; s++) {
        final sec = hu.sections[s];
        expect(sec.name, isNotEmpty, reason: 'chapter $c section $s name');
        expect(
          sec.technique,
          isNotEmpty,
          reason: 'chapter $c section $s technique',
        );
        for (var l = 0; l < sec.lessons.length; l++) {
          expect(
            sec.lessons[l].title,
            isNotEmpty,
            reason: 'chapter $c section $s lesson $l title',
          );
          expect(
            sec.lessons[l].detail,
            isNotEmpty,
            reason: 'chapter $c section $s lesson $l detail',
          );
        }
      }
    }
  });

  test('Hungarian coach content covers every section', () {
    for (var c = 0; c < chapters.length; c++) {
      for (var s = 0; s < chapters[c].sections.length; s++) {
        final coach = coachContentHu['$c-$s'];
        expect(coach, isNotNull, reason: '$c-$s missing');
        expect(coach!.title, isNotEmpty, reason: '$c-$s title');
        expect(coach.intro, isNotEmpty, reason: '$c-$s intro');
        expect(coach.steps.length, 3, reason: '$c-$s steps');
        expect(coach.why, isNotEmpty, reason: '$c-$s why');
        expect(
          coachFor(c, s, 'hu').title,
          coach.title,
          reason: '$c-$s lookup',
        );
      }
    }
  });

  test('Hungarian dictionary resolves screen keys', () {
    AppLocalizations.useCode('hu');
    try {
      expect(tr('myg_title'), 'Céljaim');
      expect(tr('bench_hub_title'), 'Tedd próbára magad');
      expect(tr('lp_start'), 'GYAKORLÁS INDÍTÁSA');
      expect(tr('btz_title'), 'Csatazóna');
      expect(tr('btd_go'), 'RAJT!');
      expect(tr('blg_title'), 'Ranglista');
      expect(tr('lpt_track_title'), 'Tanulási útvonal');
      expect(tr('mar_due'), 'Ismétlés esedékes');
      expect(tr('fnd_ex_0_payoff'), contains('befogadás'));
      expect(tr('btl_hint_order'), contains('sorrendet'));
    } finally {
      AppLocalizations.useCode('en');
    }
    expect(tr('myg_title'), 'My goals');
  });

  test('locale accessors fall back to English', () {
    expect(chapterRealmIn('en', 0), chapters[0].realm);
    expect(chapterRealmIn('hu', 0), chaptersHu[0].realm);
    expect(lessonTitleIn('en', 0, 0, 0), '1 name, in silence');
    expect(lessonTitleIn('hu', 0, 0, 0), '1 név, csendben');
    expect(trackName(0), 'Sensory');
    expect(trackName(0, 'hu'), 'Érzékelés');
  });
}
