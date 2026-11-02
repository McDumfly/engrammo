import 'package:engrammo/l10n/curriculum_hu.dart';
import 'package:engrammo/l10n/strings_en.dart';
import 'package:engrammo/l10n/strings_hu.dart';
import 'package:engrammo/models/claims_policy.dart';
import 'package:engrammo/models/curriculum.dart';
import 'package:engrammo/models/foundations.dart';
import 'package:engrammo/models/item_banks.dart'
    show dayEventPool, poemBank, prospectiveBank;
import 'package:engrammo/models/lesson_content.dart';
import 'package:engrammo/models/memory_verdict.dart';
import 'package:engrammo/models/meta_task.dart';
import 'package:engrammo/models/study_recommendation.dart';
import 'package:engrammo/models/transfer_missions.dart';
import 'package:engrammo/models/transfer_targets.dart';
import 'package:engrammo/models/user_goals.dart';
import 'package:engrammo/services/meta_ai_service.dart';
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
    // Hungarian twins: every EN surface above has a HU twin that must
    // stay clean too (untranslated banned phrases would hide here).
    for (var c = 0; c < chaptersHu.length; c++) {
      final ch = chaptersHu[c];
      out.add('${ch.realm} ${ch.tagline}');
      for (var s = 0; s < ch.sections.length; s++) {
        final sec = ch.sections[s];
        out.add('${sec.name} ${sec.technique}');
        for (final lesson in sec.lessons) {
          out.add('${lesson.title} ${lesson.detail}');
        }
        final coach = coachFor(c, s, 'hu');
        out.add(coach.title);
        out.add(coach.intro);
        out.addAll(coach.steps);
        out.add(coach.why);
      }
    }
    // Duel, league, battle, arena, coach, recap and mission strings
    // (EN + HU). Myth-busting copy lives only in the onboarding and
    // honesty-sheet keys, which are deliberately NOT in this prefix
    // list — those keys are allowed to name the myths they debunk.
    const duelPrefixes = [
      'duel_',
      'btl_',
      'btz_',
      'btd_',
      'blg_',
      'tier_',
      'coach_',
      'ai_recap',
      'ai_coach',
      'season_',
      'reward_',
      'arena_',
      'scout_',
      'hype_',
      'streak_',
      'mission_',
    ];
    for (final entry in enStrings.entries) {
      if (duelPrefixes.any(entry.key.startsWith)) out.add(entry.value);
    }
    for (final entry in huStrings.entries) {
      if (duelPrefixes.any(entry.key.startsWith)) out.add(entry.value);
    }
    return out;
  }

  group('claims policy', () {
    test('no banned efficacy phrase in tracks, chapters, coach cards, '
        'missions, targets, worked examples, banks, HU twins, duel/league strings', () {
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
      expect(bodies, contains('Eidetic imagery'));
      expect(bodies, contains('Parker et al. 2006'));
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

    test('practice transfer cards carry no banned efficacy phrase', () {
      const games = [
        'sequence',
        'number',
        'verbal',
        'visual',
        'order',
        'spatial',
      ];
      const kinds = ['tech', 'life', 'mission'];
      final surfaces = <String>[];
      for (final game in games) {
        for (final kind in kinds) {
          final key = 'bench_transfer_${game}_$kind';
          final en = enStrings[key] ?? '';
          final hu = huStrings[key] ?? '';
          expect(en, isNotEmpty, reason: 'missing EN $key');
          expect(hu, isNotEmpty, reason: 'missing HU $key');
          surfaces.add(en);
          surfaces.add(hu);
          // Every card's technique line names its source procedure.
          if (kind == 'tech') {
            expect(
              en,
              matches(
                RegExp(
                  'Corsi|Miller|Shepard|Standing|Luck|Cowan|Craik|Maguire|Dresler',
                ),
              ),
              reason: key,
            );
          }
        }
      }
      final failures = <String>[];
      for (final token in bannedClaimTokens) {
        for (final surface in surfaces) {
          if (surface.toLowerCase().contains(token)) {
            failures.add('token "$token" in: "$surface"');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.take(10).join('\n'));
    });

    test('runtime guard flags banned phrases case-insensitively', () {
      expect(bannedTokenIn('clean coaching text'), isNull);
      expect(aiTextAllowed('clean coaching text'), isTrue);
      expect(
        bannedTokenIn('This will give you PHOTOGRAPHIC MEMORY fast'),
        'photographic memory',
      );
      expect(aiTextAllowed('Boost your IQ in a week!'), isFalse);
      expect(aiTextAllowed('We guarantee total recall.'), isFalse);
    });

    test('AI verdict and study rationales with banned phrases are rejected',
        () {
      final badVerdict = parseVerdictContent(
        '{"dominant": 2, "confidence": 0.9, '
        '"rationale": "Start here for photographic memory."}',
      );
      expect(badVerdict, isNull);
      final goodVerdict = parseVerdictContent(
        '{"dominant": 2, "confidence": 0.9, '
        '"rationale": "Start with palace walks; train names second."}',
      );
      expect(goodVerdict, isNotNull);
      final badRec = parseStudyRecommendationContent(
        '{"track": 1, "rationale": "This guarantees higher IQ."}',
      );
      expect(badRec, isNull);
      final goodRec = parseStudyRecommendationContent(
        '{"track": 1, "rationale": "Start with chunking drills."}',
      );
      expect(goodRec, isNotNull);
    });

    test('AI task explanations with banned phrases fall back to local', () {
      const req = MetaTaskRequest(kind: 'sensory', difficulty: 1, seed: 's');
      final bad = MetaAIService.parseTaskContent(
        '{"prompt": "Digits", "items": ["1", "2", "3"], '
        '"question": "What was the 2nd digit?", '
        '"options": ["1", "2", "3", "4"], "correct": 1, '
        '"explanation": "You will never forget anything now.", '
        '"paradigm": "iconic-probe"}',
        req,
      );
      expect(bad, isNull);
      final good = MetaAIService.parseTaskContent(
        '{"prompt": "Digits", "items": ["1", "2", "3"], '
        '"question": "What was the 2nd digit?", '
        '"options": ["1", "2", "3", "4"], "correct": 1, '
        '"explanation": "Say the row aloud once, then answer.", '
        '"paradigm": "iconic-probe"}',
        req,
      );
      expect(good, isNotNull);
    });

    test('AI goal analyses with banned phrases are rejected', () {
      final bad = parseGoalAnalysisContent(
        '{"track": 2, "strategy": "Use loci for flawless recall.", '
        '"paradigms": ["loci-drill"], "source": "X", '
        '"plan": ["Walk daily.", "Review weekly."], "difficulty": 2}',
      );
      expect(bad, isNull);
      final good = parseGoalAnalysisContent(
        '{"track": 2, "strategy": "File one fact per station.", '
        '"paradigms": ["loci-drill"], "source": "X", '
        '"plan": ["Walk daily.", "Review weekly."], "difficulty": 2}',
      );
      expect(good, isNotNull);
    });
  });
}
