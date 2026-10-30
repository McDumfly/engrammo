import 'package:engrammo/models/claims_policy.dart';
import 'package:engrammo/models/curriculum.dart';
import 'package:engrammo/models/foundations.dart';
import 'package:engrammo/models/item_banks.dart'
    show dayEventPool, poemBank, prospectiveBank;
import 'package:engrammo/models/lesson_content.dart';
import 'package:engrammo/models/transfer_missions.dart';
import 'package:engrammo/models/transfer_targets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> allClaimSurfaces() {
    final out = <String>[];
    for (final t in memoryTracks) {
      out.add('${t.name} ${t.module}');
    }
    for (var c = 0; c < chapters.length; c++) {
      final ch = chapters[c];
      out.add('${ch.realm} ${ch.tagline}');
      for (var s = 0; s < ch.sections.length; s++) {
        final sec = ch.sections[s];
        out.add('${sec.name} ${sec.technique}');
        for (final lesson in sec.lessons) {
          out.add('${lesson.title} ${lesson.detail}');
        }
        final coach = coachFor(c, s);
        out.add(coach.title);
        out.add(coach.intro);
        out.addAll(coach.steps);
        out.add(coach.why);
      }
    }
    for (final m in transferMissions) {
      out.add('${m.title} ${m.briefing}');
      out.addAll(m.steps);
      out.add(m.selfCheck);
    }
    for (final t in transferTargets) {
      out.add('${t.label} ${t.situation} ${t.strategy}');
    }
    for (var track = 0; track < 6; track++) {
      final e = workedExampleForTrack(track);
      out.add('${e.situation} ${e.payoff}');
      out.addAll(e.thinkAloud);
    }
    for (final p in prospectiveBank) {
      out.add('${p.when} ${p.then}');
    }
    for (final p in poemBank) {
      out.add('${p.line1} ${p.line2}');
    }
    out.addAll(dayEventPool);
    return out;
  }

  group('claims policy', () {
    test(
        'no banned efficacy phrase in tracks, chapters, coach cards, '
        'missions, targets, worked examples, banks', () {
      final surfaces = allClaimSurfaces();
      expect(surfaces, isNotEmpty);
      final failures = <String>[];
      for (final token in bannedClaimTokens) {
        for (var i = 0; i < surfaces.length; i++) {
          if (surfaces[i].toLowerCase().contains(token)) {
            failures.add('token "$token" in: "${surfaces[i]}"');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.take(10).join('\n'));
    });

    test('ban list covers the four risk groups', () {
      final joined = bannedClaimTokens.join('|');
      expect(joined, contains('supermemory'));
      expect(joined, contains('never forget'));
      expect(joined, contains('higher iq'));
      expect(joined, contains('prevent dementia'));
      expect(joined, contains('flawless'));
      expect(joined, contains('guarantee'));
      expect(joined, contains('grandmaster'));
      expect(joined, contains('championship'));
    });

    test('disclaimers say what the product is not', () {
      expect(assessmentDisclaimer, contains('not a medical'));
      expect(assessmentDisclaimer, contains('not an IQ test'));
      expect(resultDisclaimer, contains('not a diagnosis'));
      expect(levelFootnote, contains('not a clinical'));
      expect(honestPromise, contains('trained and closely similar'));
    });

    test('honesty sheet covers all five required sections', () {
      final titles = [for (final s in honestySections) s.title];
      expect(titles, hasLength(5));
      expect(titles.join(' '), contains('NOT promise'));
      expect(titles.join(' '), contains('Not medical advice'));
      final bodies = [for (final s in honestySections) s.body].join(' ');
      expect(bodies, contains('photographic memory'));
      expect(bodies, contains('Simons et al. 2016'));
      expect(bodies, contains('20 hours'));
    });

    test('verdict prompt guard forbids diagnosis and promises', () {
      expect(verdictPromptGuard, contains('Never diagnose'));
      expect(verdictPromptGuard, contains('never promise improvement'));
      expect(verdictPromptGuard, contains('IQ'));
    });

    test('foundation dose line states the honest comparison', () {
      expect(foundationDoseText, contains('foundation'));
      expect(foundationDoseText, contains('20 hours'));
      expect(foundationDoseText, contains('own material'));
    });
  });
}
