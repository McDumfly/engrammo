library;

import '../l10n/app_localizations.dart';

const bannedClaimTokens = <String>[
  'supermemory',
  'super-memory',
  'super memory',
  'never forget',
  'unforgettable',
  'perfect recall',
  'total recall',
  'photographic memory',
  'eidetic memory',
  'hyperthymesia',
  'hsam',
  'higher iq',
  'boost your iq',
  'increase your iq',
  'raise your iq',
  'smarter brain',
  'prevent alzheimer',
  'prevent dementia',
  'stop cognitive decline',
  'slow cognitive decline',
  'reverse memory loss',
  'clinically proven',
  'medically proven',
  'guarantee',
  'grandmaster',
  'champion-grade',
  'championship',
  'name master',
  'master recall',
  'master exam',
  'masterclass',
  ' mastery',
  'flawless',
  'verbatim recall',
  'distraction-proof',
  'zero exceptions',
  'no exceptions',
  'trained now',
  'skill is yours',
  'strongest known',
  'perfect test',
  'complete test',
  'perfect order',
  'perfect sequence',
  'exact every time',
  'every name placed',
  'no lost weeks',
  'no broken links',
  'near-record',
  'competition pace',
  'final table',
  'no weak direction',
  'exact words only',
  'transfers best',
  'transfers to noisy real life',
  'multiply follow-through',
];

class HonestySection {
  final String title;
  final String body;
  const HonestySection(this.title, this.body);
}

const foundationLessonsPerTrack = 74;
const minutesPerLesson = 4;

String get researchDoseText => tr('policy_research_dose');

String get foundationDoseText => tr('policy_foundation_dose', {
      'hours': foundationLessonsPerTrack * minutesPerLesson ~/ 60,
      'dose': researchDoseText,
    });

String get honestPromise => tr('policy_honest_promise');

String get assessmentDisclaimer => tr('policy_assessment_disclaimer');

String get resultDisclaimer => tr('policy_result_disclaimer');

String get levelFootnote => tr('policy_level_footnote');

String get levelExplainer => tr('policy_level_explainer');

const verdictPromptGuard =
    'In "rationale", describe practice emphasis only. Never diagnose, never mention medical conditions, IQ, or school/job performance, and never promise improvement.';

String get aiCloudConsentTitle => tr('policy_consent_title');

String get aiCloudConsentBody => tr('policy_consent_body');

List<HonestySection> get honestySections => <HonestySection>[
      HonestySection(
        tr('policy_honesty_1_title'),
        tr('policy_honesty_1_body'),
      ),
      HonestySection(
        tr('policy_honesty_2_title'),
        tr('policy_honesty_2_body'),
      ),
      HonestySection(
        tr('policy_honesty_3_title'),
        tr('policy_honesty_3_body'),
      ),
      HonestySection(
        tr('policy_honesty_4_title'),
        tr('policy_honesty_4_body'),
      ),
      HonestySection(
        tr('policy_honesty_5_title'),
        tr('policy_honesty_5_body'),
      ),
    ];

String labFinding(String study, String finding) =>
    tr('policy_lab_finding', {'study': study, 'finding': finding});
