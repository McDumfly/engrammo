# Engrammo research base

Every design decision in this app traces to at least one study below.
This file is the map: claim -> evidence -> where it lives in the code.

Honesty first: memory training has real, proven effects — and real,
proven limits. Both are documented here.

## 1. Core thesis: teach strategies, not just drills

Isolated brain-training minigames reliably improve only the trained
task, with weak near transfer and ~zero far transfer. Real
"supermemory" is learned mnemonic encoding that reroutes content
into high-capacity spatial/episodic systems.

- Simons et al. (2016), Psychological Science in the Public Interest:
  review of 132 industry-cited studies. Improvement on trained
  tasks, little evidence of everyday cognitive benefit.
- Owen et al. (2010, Nature, n=11,430): online brain training,
  no transfer beyond trained tasks.
- Maguire, Valentine, Wilding & Kapur (2003, Nature Neuroscience):
  top memorizers show no structural brain/IQ advantage; 9/10 use
  the method of loci; loci use recruits hippocampus +
  retrosplenial cortex.
- Dresler et al. (2017, Neuron): 6 weeks of loci training (40x30
  min) took novices from 26 to 62/72 words, shifted connectivity
  toward the athlete pattern, gains kept at 4 months.
- Wagner et al. (2021, Science Advances): loci training boosts
  durable (>24h) memories with decreasing prefrontal activation
  (neural efficiency); WM-training controls lost their gains.
- Twomey & Kroneisen (2021): meta-analysis of 13 RCTs favoring
  loci (medium effect).
- Ericsson & Kintsch (1995): long-term working memory — experts
  exceed limits via learned retrieval structures, never via
  larger short-term stores.

Code: `lib/models/curriculum.dart` (strategy-named sections),
`lib/models/lesson_content.dart` (coach cards), onboarding primers
(`lib/screens/onboarding.dart`).

## 2. Techniques taught (one per section)

| Section | Technique | Key evidence |
|---|---|---|
| Attention gate | Full-attention encoding; stop rehearsing your own reply | Craik, Govoni, Naveh-Benjamin & Anderson (1996): divided attention at encoding wrecks memory, at retrieval barely matters |
| Audio flash | Say it back aloud immediately; rhythmic grouping | MacLeod et al. (2010) production effect; Purnell-Webb & Speelman (2008) rhythm framing |
| Noisy field | Selective attention under noise (cocktail-party filtering) | Cherry (1953); Conway, Cowan & Bunting (2001) |
| Digit chunks | 3-item chunks, phonetic images | Miller (1956) 7±2; Cowan (2001) true limit ~4 chunks; Dirlam (1972) optimal 3-4 items/chunk; Ericsson, Chase & Faloon (1980): 7→80 digits via chunking + retrieval structures |
| Card deck | Fixed card images + ordered stations (PAO) | Memory-sport practice survey (WMSC/IAM); all records use palace + PAO |
| Working memory gym | Backward manipulation drills | Baddeley & Hitch (1974) phonological loop + central executive |
| Palace 1-3 | Method of loci, distinct stations, timed encoding | Maguire et al. (2003); Dresler et al. (2017); Krokos et al. (+30% retention vs 2D); Tilburg Kingdom of Loci (27-item single-session walks) |
| Imagery 1-3 | Dual coding, distinctiveness, bizarre-interactive images, humor effect | Paivio dual-coding theory; Shepard (1967); Standing (1973) massive picture memory; Von Restorff (1933) distinctiveness; Schmidt (1994) humor effect; Wollen et al. (bizarre slower to form — prefer interactive/plausible) |
| Story chains | Narrative chaining, elaboration | Bower & Clark (1969) narrative mediators; Craik & Tulving (1975) depth of processing |
| Time & place anchors | Context reinstatement: re-create the where + when to cue recall | Godden & Baddeley (1975) divers; Smith & Vela (2001) meta-analysis; Tulving & Thomson (1973) encoding specificity |
| Journal + night | Evening replay, sleep consolidation | Gais, Lucas & Born (2006): evening learning forgotten far less; Mazza et al. (2016): a night between sessions halves relearning, benefit visible at 6 months; Wilhelm et al. (2011): expecting a test gates what sleep keeps |
| Baker breaker | 3-step face-name mnemonic | Morris et al.: 42%→79%, d≈2.4; McWeeny et al. (1987) Baker/baker paradox |
| Keyword chain | Acoustic keyword + interactive image | Atkinson & Raugh (1975): 72% vs 46%; Beaton et al. (1995): retention up to 10 years with brief reviews |
| Meaning web | Semantic elaboration, self-explanation | Craik & Tulving (1975); Chi et al. (1994) self-explanation |
| Gauntlet | Competition formats (80-digit sprint, speed cards, 27+ walks) | Memory League/WMSC record tables; speed numbers 80 digits / 13.5 s (2025); speed cards 12.74 s |

## 3. Assessment: level + dominant type (13 probes + interview)

- Two probes per construct (easy 40 + hard 60 points) is the
  minimum that separates types: single yes/no items produce
  all-ties. Free-recall probes split the same budget by partial
  credit (3/4 digits in place = 30), the WAIS/WMS scoring logic —
  so type scores are sums of partial credits, not just
  0/40/60/100.
  Spatial is the exception with three probes (easy 20, medium 30,
  hard 50): a 2-then-4 Corsi ladder ceilinged because both sat
  below the typical adult span (M=6.2, Kessels et al. 2000), so
  the ladder is now 3/5/7 cells (3 well below, 5 near, 7 above
  span). Every type still sums to 100.
  Code: `lib/models/assessment.dart` (`scoreForPair`,
  `spatialProbeBudgets`, `corsiProbeSequences`),
  `lib/screens/memory_profile.dart` (13 tasks).
- Every probe is modeled on a validated paradigm (shown under
  each stimulus in the app):
  | Probe | Paradigm | Source |
  |---|---|---|
  | Sensory 1-2 (brief look, auto-hides, TYPED digit) | Iconic probe, free recall | Sperling 1960; Luck & Vogel 1997 |
  | Working 1-2 (reverse the digits, TYPED — instruction hidden until the question) | Backward digit span, partial credit | WAIS; Baddeley 1986; Cowan 2001 |
  | Spatial 1-3 (reproduce the tap ORDER, 3/5/7 cells) | Corsi span, sequential reproduction | Corsi 1972; Kessels et al. 2000 |
  | Visual 1-2 (same array or one changed?) | Change detection, same/different | Luck & Vogel 1997; Cowan 2001 |
  | Episodic 1-2 (single reading, TYPED retell) | Story recall, idea-unit scoring | WMS Logical Memory; Craik & Tulving 1975 |
  | Semantic 1-2 (pick the exemplar) | Category exemplar | Collins & Quillian 1969; Rosch 1975 |
- The visual palette is a single source of truth
  (`assessmentColorChips`): each entry paints the circle AND
  names the option, so a blue circle can never be labeled
  "Purple" again. Six Berlin & Kay (1969) basic color terms.
- A no-cheat preamble opens every run: writing things down or
  asking for help only hides the user's real dominant type, so
  the training path would adapt to a lie. Standard
  test-instruction practice.
- Ties are broken by a research-backed ladder, never by index
  order (`resolveDominant`): (1) unique top score wins;
  (2) hard-item hits narrow the tie — hard probes discriminate
  while easy ones ceiling, the same logic as adaptive testing
  and Wechsler discontinue rules; (3) faster mean recall
  narrows it further (fluent retrieval = efficient trace, cf.
  neural-efficiency findings, Wagner et al. 2021); (4) the
  interview verdict picks among the tied top only —
  self-report breaks performance ties but never overrides a
  clear performance gap (multitrait-multimethod logic,
  Campbell & Fiske 1959); (5) still tied → the UI shows a
  "Balanced profile" card listing every tied strength. A
  low-stakes screener cannot resolve differences smaller than
  its own measurement error, so it must not pretend to.
- Second leg: an 8-question structured interview about HOW the
  user remembers (VVIQ-style imagery vividness, Marks 1973;
  house walk-through scene construction; strategy probes;
  SBSOD-style sense of direction, Hegarty et al. 2002;
  prospective-memory strategy, Einstein & McDaniel 1990;
  face-name associative memory, Morris et al.). Each
  question offers 4 selectable answers plus free custom text.
  The interview never names the memory palace — it measures
  the unaided strategy. Muse Spark reads test scores +
  answers together and writes the verdict (kind, confidence,
  rationale); offline, a deterministic heuristic over the
  same inputs decides, so both legs always agree by design.
  Every question shows its construct + source questionnaire
  (VVIQ, SBSOD, Tulving, Atkinson & Raugh, Baddeley & Hitch,
  Hassabis & Maguire) — adapted items, never verbatim, so no
  normed scale is claimed and the option weights are a
  transparent rational key. Tie-only rule, enforced twice: the
  prompt forces a clear winner / restricts the pick to the
  tied top, and a verdict outside the tied top is discarded in
  favor of the local ladder — self-report breaks ties, it never
  overrides a measured gap.
  Code: `lib/models/interview.dart`,
  `lib/models/memory_verdict.dart`,
  `MetaAIService.analyzeMemoryType`,
  `lib/screens/assessment_interview.dart`.
- Fixed parallel forms: runs rotate through Forms A-D carrying
  matched-difficulty, different stimuli (digits, tap orders, color
  arrays, stories, categories), so retakes measure memory, not
  remembered answers (practice-effect control; Woods et al. 2006;
  Duff et al.). Assessment items are RESERVED: lessons draw from
  separate spare banks, so practice can never teach the test.
  The run counter lives in `MemoryStore` (`assessment_runs_v1`);
  cloud downloads never consume a form turn. The assessment NEVER
  uses AI-generated probes: a measurement instrument must give every
  user the same items. AI first appears at the verdict stage, reading
  finished scores + interview under a tie-only rule.
  Code: `_buildTasks(context, form:)`, `loadAssessmentTasks`,
  `lib/screens/memory_profile.dart`.
- The verdict (kind + rationale + ai/local source) is stored
  in the user profile (`MemoryStore` dominant-kind keys,
  cloud-synced) and re-taken with every assessment run. The
  profile and Battle Zone default prefer it over raw
  max-score.
- Null = never assessed → the UI shows a call-to-action,
  never a fake winner. Code: `dominantKind`, profile empty
  state (`lib/screens/kreeds_profile.dart`).
- Levels use the app's existing `(avg ~/ 10) + 1` bands
  (level 1 at avg 0-9 … level 11 at avg 100), shared with
  Battle Zone (`memoryLevelForScore`). This is an internal
  progression metric, not a clinical instrument.
- Honesty note (from assessment literature): a real level test
  needs test-retest reliability (ICC ≥ .70 per subtest) and
  validation against a gold standard (Heaton et al. 2014;
  Karr et al. 2024). Our 13-item screener is a starting
  placement, not a diagnosis. Parallel Forms A-D blunt practice
  effects on retake, but the 13-item form itself has no
  reliability study — that requires a norming sample, not code.
- No learning-styles routing: matching instruction to
  self-reported VAK style has no support (Pashler et al. 2008
  APS review; Newton 2015; Rogowsky et al. 2015). The dominant
  type personalizes emphasis and the default battle mode — it
  never gates content. Every user gets all techniques.

## 4. Scheduling, dose, and difficulty

- Spacing: 259/271 comparisons favor spaced over massed practice
  (Cepeda et al. 2006, 317 experiments). Optimal first gap grows
  with the retention goal (~1 day for a week, ~1-3 weeks for
  months; Cepeda et al. 2008, N=1,354). Equal spacing is fine —
  expanding schedules are not better (Latimier, Peyre & Ramus
  2021 meta-analysis, g=0.034).
  Code: FSRS-lite scheduler (`lib/models/fsrs_card.dart`),
  evening replay lessons, review-heavy Gauntlet.
- Retrieval > restudy at delay (Roediger & Karpicke 2006: 61%
  vs 40% at 1 week). Corrective feedback roughly doubles the
  testing effect; recall formats beat recognition (Rowland 2014
  meta-analysis, g=0.50; Adesope et al. 2017, g=0.51).
  Code: every lesson ends in recall + immediate feedback
  (`lib/screens/lesson_player.dart`).
- Desirable difficulties: errors + correction beat errorless
  study in healthy learners (Kornell, Hays & Bjork 2009;
  Middleton & Schwartz 2012; Wong & Lim 2022 "derring"
  effect). A finished lesson always earns ≥1 star.
  Code: `starsForLesson` in `lib/models/assessment.dart`.
- Difficulty target ~85% success (Wilson et al. 2019 "85%
  rule"; Levitt 1971 staircases; Jaeggi et al. 2008 adaptive
  n-back rule). Lessons rise 1→5 across sections; the
  Gauntlet starts at 3.
  Code: `lessonDifficultyFor` in `lib/screens/lesson_player.dart`.
- Dose: short daily sessions with sleep between them beat
  cramming (Gais et al. 2006; Mazza et al. 2016). App
  sessions target ~5 minutes. Honest dose math: one full pass
  of a track (~62 lessons x ~4 min) is roughly 4 hours of
  guided practice — the foundation, not mastery. The Dresler
  protocol that shifted lab performance used ~20 hours on ONE
  technique over 6 weeks (40x30 min), so durable skill needs
  repeated spaced review plus own-material practice over weeks
  (own palaces, own names, own study texts), then a retest on
  fresh items — never a single pass.
- Long program: each track is a full course, not a single lap.
  Every finished lesson replays at 11 deeper practice rounds
  with harder parameters (more drills, longer delays, higher
  difficulty) and a FRESH deterministic item set per round —
  variable practice plus retest on fresh items, the two
  conditions the transfer literature asks for (Dresler et al.
  2017; Simons et al. 2016). Practice rounds are spaced-LOCKED:
  the next round opens only when due (gaps 1→60 days, ~9 months
  per lesson back-to-back), so the full course cannot be binged —
  the first pass stays a demoable foundation weekend, full
  completion takes many months. A fully practiced track is
  ~800+ short sessions (~70+ guided hours), past the 20-hour
  lab dose, with a stretch line at 80 hours; a per-track
  minute clock shows practiced time against both lines, due
  labels flag waiting lessons, and the lesson-end screen names
  the next review date.
  Gap rationale: the `reviewGapDays` table (1→60 days) widens with the
  retention horizon (Cepeda et al. 2008), not because expanding gaps
  beat equal ones — they do not (Latimier, Peyre & Ramus 2021). The
  exact day counts are an app schedule choice, not a lab prescription.
  Code: `lib/models/marathon.dart` (`practiceRoundLocked`,
  `reviewGapDays`), rep/minute/date counters
  in `lib/services/memory_store.dart`, depth wiring in
  `lib/screens/lesson_player.dart`, program block + lock guards in
  `lib/screens/learning_path.dart`.
- Cognitive load: one technique per lesson, worked steps
  before free recall (Sweller et al. 2019). Coach cards
  stay short for this reason.

## 5. Motivation without corrupting measurement

- Minimal gamification (points/progress framing) beats none;
  keep game layers outside timed measurement windows
  (Lumsden et al. 2016). Rewards + feedback dominate
  effective designs (Vermeir et al. 2020).
- Broken streaks shown without repair reduce engagement vs no
  streak at all (Silverman & Barasch 2023) — hence the
  streak-freeze/restore mechanic. Emergency reserves raise
  persistence (Sharif & Shu 2017).
  Code: `lib/utils/streak_restore.dart`, restore dialog.
- Leaderboards can stress low-rank users (Mekler et al.
  2013); the app prefers private self-comparison — the weekly league
  is therefore a SIMULATED board (player vs 30 deterministic bots),
  never a public ranking of real users. Season length, field size,
  and tier bands are arbitrary game choices, documented in
  `lib/models/league_season.dart` and `lib/models/battle_bot.dart`.
- Duel ratings use the Elo logistic formula (Elo 1978, 400-point
  scale, K=32) as a borrowed relative skill ladder, not a validated
  memory measure; XP reward amounts (daily x2, streak 25, tier-up
  100, weekly 150/100/50) are arbitrary pacing choices under the
  rewards+feedback pattern (Vermeir et al. 2020), kept outside timed
  measurement windows (Lumsden et al. 2016). Code:
  `lib/models/battle_rating.dart`, `lib/models/battle_rewards.dart`.
- The review scheduler is an FSRS-inspired scheduler
  (hand-tuned stability/difficulty rules, not fitted FSRS weights)
  that schedules Room Palace reviews; path lessons use a fixed
  review ladder (1 → 60 days). It borrows the stability/difficulty
  model from FSRS (Ye et al., open-spaced-repetition; SM-2 lineage,
  Wozniak 1987) on top of the spacing literature above.
  Code: `lib/models/fsrs_card.dart`.

## 6. What we do NOT promise (transfer limits)

- Far transfer from generic WM/brain training is ~zero under
  active controls (Melby-Lervåg, Redick & Hulme 2016, 87
  publications; Sala & Gobet 2017/2019/2020; Simons et al.
  2016; Aksayli, Sala & Gobet 2019 on Cogmed). No dose
  effect for far transfer (Soveri et al. 2017).
- We therefore promise only near transfer: better performance
  on trained and closely similar material, durable with
  spaced retrieval — never higher IQ or general memory.
- Myth-busting in onboarding (photographic memory
  unreplicated; eidetic imagery brief and mostly child-only, Haber
  1979; HSAM autobiographical-only, Parker, Cahill & McGaugh 2006)
  follows the research consensus so users aim at the trainable
  target: mnemonic strategies on practiced material.
  Code: the myth primer in `lib/screens/onboarding.dart`
  (`onboarding_myth_*` strings) plus `policy_honesty_3_body`.

## 7. Sources for the ~200-study sweep

The statements above condense a 40-agent literature sweep
(Oct 2026) covering: n-back transfer (Au 2015; Soveri 2017;
Harrison 2013; Lawlor-Savage & Goghari 2016), spacing
(Cepeda 2006/2008; Dunlosky 2013; Smolen/Zhang/Byrne 2016;
Donoghue & Hattie 2021), retrieval practice (Karpicke &
Blunt 2011; Butler & Roediger 2008; Kang/McDermott/Roediger
2007), chunking (Chase & Simon 1973; Gobet & Simon 1996),
interleaving (Rohrer & Taylor 2007; Taylor & Rohrer 2010;
Brunmair & Richter 2019 meta-analysis g=0.42; Kornell &
Bjork 2008), assessment norms (WAIS digit span; Gathercole
CNRep; RAVLT/CVLT; ACTIVE n=1,401), navigation (Maguire
taxi drivers 2000; Sea Hero Quest; GPS-habit effects),
verbal learning (Burke et al. TOT work; Karpicke & Roediger
2008 Swahili study), sleep (Walker 2002; Hu/Stylos-Allan/
Walker 2006), enactment/drawing effects (Engelkamp;
Wammes/Meade/Fernandes 2016), forgetting curves
(Ebbinghaus; Murre & Dros), processing speed (ACTIVE
10-year follow-ups), and gamification meta-analyses
(Hamari et al. 2014; Sailer & Homner 2020). Per-claim
caveats (paywalled primaries verified via abstracts plus
2+ independent citing full texts) are logged in the
session's workflow report.

## 8. Paradigm registry: every task traces to one procedure

Every drill the app can show — lessons, benchmark sparring, battle
duels, assessment fallbacks — is a small, faithful instance of exactly
one published paradigm below. The registry lives in
`lib/models/validated_tasks.dart`; each task carries its paradigm id
and study source (`MetaTask.paradigm`, `MetaTask.source`), so the
provenance is machine-checkable, not a comment.

| Paradigm id | Procedure | Key evidence | Local generator |
|---|---|---|---|
| `iconic-probe` | Brief digit row, probe one position | Sperling 1960; Luck & Vogel 1997 | Seeded digits, no adjacent repeats |
| `brown-peterson` | CCC trigram, count-back distractor, recall | Peterson & Peterson 1959; Brown 1958 | Seeded CCC, original delays |
| `backward-span` | Digit row, report the full order reversed | WAIS digit span; Baddeley 1986; Cowan 2001 | Forward/swap/rotation lure family |
| `chunk-span` | One long number, recognize it among near-miss lures | Miller 1956; Cowan 2001; Ericsson, Chase & Faloon 1980 | 1-2 digit mutations, same length |
| `loci-drill` | Ordered distinct stations, one concrete noun each, cued recall | Maguire et al. 2003; Dresler et al. 2017 | `palace_drill.dart` familiar routes |
| `picture-recall` | Everyday scene, recognize one detail (1 present + 3 absent) | Shepard 1967; Standing 1973; Paivio dual-coding | Scene bank + cross-scene lures |
| `pattern-span` | Grid cells (3x3 canonical, 4x4 in practice), recall the lit set | Luck & Vogel 1997; Cowan 2001 | Distinct cells 0-8 (0-15 on 4x4), mutated sets; the square practice game deals exact-count layouts via `generatePatternCells` |
| `story-recall` | One short story sentence, cued detail | WMS Logical Memory; Craik & Tulving 1975 | Story bank, idea-unit probes |
| `category-exemplar` | Category name, pick the member | Collins & Quillian 1969; Rosch 1975; Battig & Montague 1969 | Category bank, neighbor lures |
| `paired-associate` | Cue→target pair, retrieve target from cue | Karpicke & Roediger 2008; Atkinson & Raugh 1975 | Concrete-noun pairs |
| `face-name` | Face feature + name hook, retrieve the surname | Morris et al. face-name mnemonic; McWeeny et al. 1987 | Face-name bank, surname lures |
| `keyword-pair` | Foreign word + keyword, retrieve the meaning | Atkinson & Raugh 1975; Beaton et al. 1995 | Foreign-word bank, meaning lures |
| `prospective-cue` | WHEN cue → THEN action plan, retrieve THEN | Gollwitzer 1999; Einstein & McDaniel 1990 | If-then plan bank, action lures |
| `poem-chunk` | Two-line verse chunk, retrieve line 2 from line 1 | Rubin 1995; Roediger & Karpicke 2006 | Original couplet bank, line lures |
| `day-replay` | 3-5 ordered day events, what came AFTER X | Gais, Lucas & Born 2006; Wilhelm et al. 2011 | Day-event pool, ordered sampling |

Slot-filling, not invention: Muse Spark receives the paradigm's fixed
procedure (`paradigmPrompt`) and may only fill the stimulus slots
inside it (which digits, words, colors). Low temperature (0.2) keeps
it literal. Structural violations (not exactly 4 options, empty
stimulus) are rejected at parse time and the caller falls back to the
deterministic local generator running the SAME paradigm
(`MetaAIService.parseTaskContent`, `_localTask` /
`localValidatedTask`). Online and offline users therefore train on
identical paradigms — the only difference is who picked the stimulus.
Seeded generation makes every lesson reproducible; an empty seed draws
fresh sparring content. Every answer also passes `validateTask`
(exactly 4 distinct options, in-range correct index,
paradigm-shaped stimulus). There is deliberately no silent repair:
clamping an out-of-range correct index would crown a different option
than the model meant. The registry stamp always comes from code, never
from the model's echo. Code: `lib/models/validated_tasks.dart`,
`MetaAIService.taskRequestBody` / `parseTaskContent`,
`test/validated_tasks_test.dart` (paradigm stamp, 4 options,
determinism, rejection, tie-only rule, form alternation).

Media enrichment keeps the paradigm, upgrades the stimulus. Spatial
(`loci-drill`) rounds additionally call Muse Image for a palace
illustration plus SAM 3.1 to segment it into ordered stations; visual
(`picture-recall`) rounds call Muse Image for the scene. Offline, the
same drills run with familiar local routes and verbal scene
descriptions — forming the image from words is itself dual-coding
practice (Paivio), not a lesser task. Code:
`MetaAIService.enrichSpatialTask` / `enrichVisualTask`, called from
`lib/screens/lesson_player.dart`; UI renders ordered station walks,
scene details, and a one-line technique cue with its citation.

Honesty note: these are faithful drill instances of validated
paradigms, not normed clinical instruments. It does not mean the app's
444-lesson sequence, its level bands, or its 13-item screener are
themselves validated instruments; those would need their own trials.
The app therefore shows the paradigm + source on every drill instead
of claiming a certified test. Near transfer to similar material with
spaced retrieval is the only promise (see section 6).

## 9. Claims policy: FTC-safe wording, enforced in code

Why this section exists: a brain-training company that promised
general memory gains, better school/work performance, and protection
against cognitive decline — without randomized controlled trials of
its own product — was fined $2M by the US FTC (Jan 2016) and barred
from such claims without competent, reliable scientific evidence
(human clinical testing by qualified experts). The evidence review
behind that outcome is Simons et al. (2016, 132 studies) plus Owen
et al. (2010, n=11,430): drills improve the drilled task; far
transfer to everyday cognition is ~zero. Engrammo's whole text
surface is written against that standard:

Allowed (and these are the ONLY efficacy promises):
- "Practice improves the trained strategies on trained and closely
  similar material, durable with spaced review."
- Lab findings reported AS lab findings, with study name and the
  qualifier that individual results vary with practice
  (`labFinding` helper in `lib/models/claims_policy.dart`).
- Playful place names (palaces, galleries, arenas) that describe
  the exercise setting, never the outcome.

Banned everywhere in user-visible lesson text (enforced by
`test/claims_policy_test.dart` over tracks + chapters + coach cards +
missions + HU twins + duel/league/battle strings,
token list in `bannedClaimTokens`):
- guaranteed super-ability: supermemory, never forget,
  unforgettable, perfect/total recall;
- mythical targets as goals: photographic/eidetic memory,
  hyperthymesia/HSAM (allowed ONLY inside myth-busting copy that
  says they are NOT the goal);
- medical/diagnostic promises: higher IQ, prevent dementia /
  Alzheimer's, stop/slow decline, clinically/medically proven,
  guarantee;
- absolute outcomes: flawless, verbatim recall, exact every time,
  zero exceptions, "the skill is yours", "trained now";
- mastery titles implying certified level: grandmaster,
  championship/champion-grade, name master, masterclass, mastery.

Where the honest copy lives (single source of truth,
`lib/models/claims_policy.dart`):
- `honestPromise` — the one-line promise;
- `assessmentDisclaimer` / `resultDisclaimer` — screener honesty on
  the assessment intro + results pages;
- `levelFootnote` — under every "Memory level" display (practice
  metric, not clinical);
- `foundationDoseText` — the 4h-foundation vs 20h-lab-dose math on
  the track picker;
- `honestySections` — the five-section "What this app can — and
  cannot — do" sheet (`lib/widgets/honesty_sheet.dart`), opened
  from onboarding, the track picker, assessment results, and
  (via the same widget) anywhere else;
- `verdictPromptGuard` — appended to the AI interview prompt so
  generated rationales can never diagnose or promise improvement
  (plus the existing tie-only rule and local fallback).
- `bannedTokenIn` / `aiTextAllowed` — the RUNTIME guard: every
  AI-generated string the user can see (verdict/study rationales,
  task explanations, coach/teacher/recap/tip/hype/round/scout notes,
  goal analyses, wonder captions) is scanned before acceptance, and
  blocked text falls back to the deterministic local copy.
  Code: `lib/models/claims_policy.dart`,
  `MetaAIService.parseTaskContent` / `parseDynamicTaskContent` /
  free-text acceptors, `parseVerdictContent`,
  `parseStudyRecommendationContent`, `parseGoalAnalysisContent`.

Dose honesty: a finished track is labeled the FOUNDATION
("every core strategy practiced once on trained material") in the
curriculum docs, the track picker ("every path ends in a foundation
review"), and every final coach card (each ends with a keep-going
line: weekly review + own material + retest on fresh items).
Durable-skill criteria — spaced review over weeks, own-material
practice, retest delta on the alternate form — are stated in the
honesty sheet instead of a fake "mastery" badge.

## 10. Transfer layer: from app skill to daily-life skill

App drills alone improve mostly the drilled screens (Simons et al.
2016; Owen et al. 2010). Durable daily-life skill comes from the SAME
strategy on the user's OWN material, varied contexts, and spaced
recall over weeks (Dresler et al. 2017; Dunlosky et al. 2013;
Roediger & Karpicke 2006). This layer adds exactly that — without
changing the honest promise (trained strategies on trained and
closely similar material, durable with spaced review):

- Fieldwork chapters 30-35 (one closes each track, 3 sections x 4
  lessons): own palaces and routes, real names at events, real phone
  numbers and shopping lists, study pages as scenes, evening logs.
  Code: `lib/models/curriculum.dart` chapters 30-35,
  `lib/models/lesson_content.dart` entries `30-0`..`35-2`.
- Real-world missions (24, 4 per track): self-verified checklists
  with a built-in self-check on fresh material (e.g. sealed-list
  shopping, 7-night replay log, 5-point talk with no notes).
  Completion only is stored — never the user's private material.
  Code: `lib/models/transfer_missions.dart`,
  `lib/widgets/missions_sheet.dart` (opened from the track header),
  `MemoryStore.loadDoneMissions/saveMissionDone`.
- Transfer-ready paradigms: `face-name` (Morris 3-step) and
  `keyword-pair` (Atkinson keyword) join the registry with local
  banks and generators; fieldwork lessons rotate them with stories
  and categories. Deep-path chapters (8+) now drill their own track
  kind plus cross instead of a generic number mix.
  Code: `lib/models/validated_tasks.dart`,
  `lessonKindFor/lessonRoundKindFor` in `lib/screens/lesson_player.dart`.
- Guard tests: `test/transfer_tasks_test.dart` covers the new
  paradigms, the deep-chapter mapping, and mission shape +
  persistence; `test/claims_policy_test.dart` now scans missions too,
  so no banned efficacy phrase can slip into transfer copy.

## 11. Validation layer: free recall, calibrated banks, local norms

Recognition (pick 1 of 4) is easier than recall (produce the
answer) and trains less: recall formats beat recognition
(Rowland 2014, g=0.50; Adesope et al. 2017, g=0.51), and
corrective feedback roughly doubles the testing effect. This
layer replaces recognition with production wherever the paradigm
prescribes it:

- Free-recall scoring engine (`lib/models/recall_scoring.dart`):
  accent-folded normalization, typo-tolerant word match
  (Levenshtein, length-gated so "2" never matches "3"),
  positional digit-span scoring (partial-credit proportion for
  points; exact is a binary full-match flag for stars and
  hard-hits only), WMS-style idea-unit scoring for
  stories, ordered Corsi tap scoring (order errors are errors),
  and false-alarm-penalized set scoring. The expected answer
  always comes from the validated key or the fixed bank —
  responses never define their own truth.
- Lessons: base chapters (0-5) stay recognition as scaffolding,
  EXCEPT single-word production — face-name, keyword-pair and
  paired-associate switch to typed recall from difficulty 2 (lesson
  3 of a foundation section), because producing one concrete word
  runs the lab procedure in its natural response format (Morris et
  al. d≈2.4; Atkinson & Raugh 1975; Karpicke & Roediger 2008) and
  recall beats recognition (Rowland 2014; Adesope et al. 2017).
  Finals/deep/fieldwork chapters (6+) answer hard rounds typed
  (`lessonRecallMode`: chapter >= 6, difficulty >= 3). Foundations
  at difficulty 1 stay recognition everywhere (~85% rule, Wilson et
  al. 2019). Stars need exact recall; near-misses show their
  partial detail as feedback.
- Foundations drill the procedure their coach card teaches
  (`lessonKindFor`, section-aware): Digit chunks drills chunk-span,
  the Journal drills day-replay/story, Baker breaker drills
  face-name, Keyword chain drills keyword-pair, Meaning web drills
  category judgment — so the largest lab-proven wins (Morris d≈2.4,
  Atkinson 72% vs 46%, Ericsson chunking) land in week 1 instead
  of fieldwork. Section-agnostic calls keep the old mapping.
- Assessment: iconic digits, backward spans, and stories are
  typed with partial credit; spatial probes reproduce the Corsi
  tap ORDER in three levels (3/5/7 cells, 20/30/50 points;
  Corsi 1972; Kessels et al. 2000); visual probes run
  true same/different change detection (Luck & Vogel 1997).
  Only semantic exemplar judgment stays recognition — the
  response format Rosch's paradigm uses.
- Backward-span blindness: the working-memory probes hide the
  reverse instruction (title, paradigm caption, input hint) until
  the question phase. Knowing the trick upfront lets users encode
  backwards directly, which removes the hold-then-manipulate load
  the backward span exists to measure (Baddeley 1986).
- Calibrated banks (`lib/models/item_banks.dart`): 24 stories
  with idea units (8 reserved assessment items across Forms A-D
  + 16 lesson spares), 24 categories, 16 face-name pairs,
  32 foreign words, +8 picture scenes, +24 concrete nouns.
  Assessment/reserve separation means practice cannot teach the
  test. Easy/hard shapes are matched across forms (3 vs 5 idea
  units, prototypes vs lookalikes).
- Paradigm-fidelity fixes: the visual probe is renamed
  echoic→iconic (echoic is auditory; Sperling 1960 is the right
  citation; old stamps still resolve), and the TRUE Peterson &
  Peterson procedure joins as `brown-peterson` (CCC trigram +
  count-back distractor at the original 3/6/9/18 s delays),
  wired into fieldwork sensory lessons.
- Local norming sample (`lib/models/norms.dart`,
  `MemoryStore.recordAssessmentRun`): every finished run stores
  its 13 item proportions (reliability math) and 6 kind scores
  (same-instrument norms, Welford accumulators, cap 200 runs,
  on-device only). The results page reports the device average
  from N>=10 and split-half reliability (Spearman-Brown) from
  N>=20 against the .70 bar (Heaton et al. 2014; Karr et al.
  2024) — until then it honestly says it is calibrating.
  Literature priors (WAIS-IV spans, Wechsler 2008 /
  López-Martos et al. 2023; Corsi M=6.2 SD=1.3, Kessels et al.
  2000; visual K≈3, Luck & Vogel 1997 / Cowan 2001) ship as
  labeled approximate anchors for span estimates, never as
  claims that the miniatures equal the full instruments.

Honesty note, updated: every drill's procedure AND response
format now mirror their published paradigm, banks are large and
calibration accumulates from real runs. What is still NOT
claimed: the 13-item screener is not a normed clinical
instrument (its local reliability is computed and SHOWN, not
assumed), AI-filled stimuli are uncalibrated by difficulty, and
the 444-lesson sequence itself was never trialed — only its
techniques and paradigms were.

## 12. Far-transfer curriculum: teach first, label everything, end in real life

This section documents the curriculum rebuild (Oct 2026): foundations
first, unambiguous delayed questions, everyday transfer targets, and
AI-built personal tasks. The design rule behind all of it: drills
alone improve mostly the drilled screens (Simons et al. 2016; Owen et
al. 2010) — so every drill must teach a strategy, name its real-life
destination, and end with the user's own material.

- Teach before testing (`lib/models/foundations.dart`). Every track
  opens with explanation plus a worked example (worked-example effect,
  Sweller et al. 2019) before any drill. Foundation lessons run a
  gentle 2-drill session with immediate questions and recognition
  answers — near-100% success, the ~85%-rule floor (Wilson et al.
  2019), not a wall. Code: `isFoundationLesson`,
  `workedExampleForTrack`, `lessonRoundsFor` in
  `lib/screens/lesson_player.dart`.
- Delayed questions are taught, then tagged. The opening section of
  every foundation chapter stays lag-free; lag starts in section 2
  with a spoken introduction card plus numbered stimulus/question tags
  ("Drill 2 of 4 · number", "About drill 2 of 4 (number):") and a
  labels-only history strip — never the hidden content, which would
  give answers away. A late question can always be traced to its own
  drill. Code: `lessonLagForLesson`, `wantsLagIntroduction`,
  `stimulusBadge`, `delayedQuestionLead`.
- Everyday transfer targets (`lib/models/transfer_targets.dart`): 12
  destinations — exam material, names, faces, numbers/codes, years,
  birthdays, deadlines, todos/errands, poems, phone numbers, foreign
  words, the whole day. Each names the strategy, the in-app paradigms
  training the IDENTICAL procedure, and the study. Every lesson's
  coach card lists its track's targets, so no drill exists without a
  real-life purpose. Transfer happens because the user runs the same
  procedure on their own material with spaced review (Dresler et al.
  2017; Dunlosky et al. 2013) — never because a drill score went up.
  This is the Lumosity distinction the claims policy (section 9)
  enforces: practiced strategies on trained and closely similar
  material, durable with spaced review — no IQ, grade, or medical
  promises, ever.
- New everyday paradigms (registry section 8): `prospective-cue`
  (Gollwitzer 1999; Einstein & McDaniel 1990) for deadlines/todos,
  `poem-chunk` (Rubin 1995; Roediger & Karpicke 2006) for verses, and
  `day-replay` (Gais, Lucas & Born 2006; Wilhelm et al. 2011) for the
  evening whole-day replay — each with a local bank and generator, so
  offline users train the same procedures. Fieldwork chapters rotate
  them (`lessonKindFor`); recall scoring covers all three
  (`recall_scoring.dart`).
- Make-it-yours transfer step (lesson done-screen). After every
  lesson the learner tells the AI what they want to remember and what
  slipped away; the AI teaches the strategy on that material
  (`explainTechnique`), diagnoses the forgetting
  (`diagnoseForgetting`), or builds a personal task from UI blocks
  (`buildDynamicTask` + `DynamicTaskView`: info, choice, text/date/
  phone fields, checklists, ordering). The fixed block schema plus
  `validateDynamicTask` keeps AI invention inside guardrails, with a
  deterministic local builder as fallback. Private material stays on
  the device (`MemoryStore.saveOwnMaterial`, never cloud-synced).
- Meta models in the loop: Muse Spark fills paradigm stimuli
  (`generateTask`), teaches (`explainTechnique`), diagnoses
  (`diagnoseForgetting`), and builds personal tasks
  (`buildDynamicTask`); Muse Image illustrates spatial/visual drills;
  SAM 3.1 segments palace stations — every call logged with model,
  kind, and fallback state (`MetaCallEntry`), every path with a local
  fallback so the app never depends on the network.
- Progress is always visible: determinate session bars on every
  multi-drill screen, per-round load progress, AI-build progress, and
  per-block progress inside AI-built tasks — long work never runs
  without a visible bar.

## 13. Battle duels: timed retrieval on validated paradigms

A duel is spaced retrieval under a clock, not a separate curriculum: 3
rounds, both sides the same tasks on the same clocks. Every round runs
encode -> hide -> recall — the stimulus auto-hides before the question
appears, so open-book matching is structurally impossible. Rounds are
interleaved (chosen kind first, then two rotated kinds; Rohrer & Taylor
2007; Brunmair & Richter 2019, g=0.42), never three identical drills.

Battle mapping (code: `lib/models/battle_round.dart`, UI:
`lib/screens/battle_duel_page.dart`):

| Memory kind | Paradigm | Response | Why this format |
|---|---|---|---|
| Sensory | `iconic-probe` | Typed digit | Brief exposure + probe-after (Sperling 1960); single chars are exact-only, never fuzzy |
| Working | `backward-span` | Typed reversed order | Direction hidden until recall (Baddeley 1986); positional partial credit |
| Spatial | `pattern-span` | Tapped cell set | Lit grid hides, blank grid scored with false-alarm penalty (Luck & Vogel 1997; Cowan 2001) |
| Visual | `picture-recall` | Typed detail | Scene hides, one detail produced (Shepard 1967; Standing 1973; Paivio) |
| Episodic | `paired-associate` | Typed target | Cue shown, target retrieved (Karpicke & Roediger 2008); single-token scoring resists word-salad farming |
| Semantic | `category-exemplar` | 4-choice judgment | Judgment IS the paradigm (Collins & Quillian 1969; Rosch 1975) — the only recognition round |

Scoring (code: `BattleScore.questionPoints` in
`lib/models/battle_match.dart`): quantized partial credit — exact 100,
full-content-with-typo 75, near-miss 60, half-remembered 40, below half
0. The speed bonus (up to 50) applies ONLY to exact answers, so fast
garbage can never farm partial points plus speed. Every reveal shows
corrective feedback with the technique line and its citation — feedback
roughly doubles the testing effect (Rowland 2014).

Fairness and anti-cheat, enforced in code:
- Foe progress stays blind until reveal (no "done" leak to stall on);
  bots are seeded policy that never peek at the player pick.
- Bots simulate human memory per paradigm: exact probability = tier
  accuracy x recall difficulty, tier-graded near-miss rates, slower
  latencies on harder paradigms (code: `botRecallOutcome` in
  `lib/models/battle_bot.dart`); rubber-banding touches only future
  exact probability, never locked answers.
- Empty typing, zero taps and timeouts count as unanswered, so idle
  stalling earns only the participation floor; forfeit is a rated loss.
- Timed measurement windows keep game layers outside them (Lumsden et
  al. 2016): no rewards, streaks or leaderboards render during encode
  or recall — they land on the result screen and in the feed.

## 14. Practice honesty: live badges and transfer cards

Two benchmark gaps closed (Oct 2026), both rooted in the same rule that
protects the product from the transfer trap (sections 1, 6, 9):

- Honest model badges. Every practice stimulus deal returns the stimulus
  PLUS whether a live model dealt it (`BenchmarkMeta` records,
  `MetaAIService.generatePatternCells`). The strip above each game shows
  AI LIVE only when the CURRENT round's content actually came from a live
  model; local rounds say LOCAL and name the models as join-when-online.
  The square game was the worst case: it asked Spark for a fixed 3-cell
  3x3 layout while needing up to 15 cells on 4x4, so the deal was always
  discarded and the strip borrowed names it never used. It now deals
  exact-count layouts for the real grid size; the spatial upgrade (which
  silently skipped levels 3/9/10 on length mismatch) now deals exact
  station counts at every level (`localPalaceTask(count:)`), and picture
  rounds fill the scene with Spark before Image/SAM enrich — mirroring
  the lesson path. Verdict/tip source labels (SPARK / GLIMMER / SPARK
  OPEN vs LOCAL) come from the same fallback flags.
  Code: `MetaAIService.patternRequestBody` / `parsePatternCells` /
  `localPatternCells` / `generatePatternCells`, `_AiModelsStrip`,
  `test/pattern_cells_test.dart`.
- Transfer cards on all six result screens. Practice games without a
  strategy destination are exactly the isolated minigames the literature
  warns about (Simons et al. 2016; Owen et al. 2010; FTC 2016). Every
  result screen now carries a static, claims-scanned card: the rehearsed
  strategy with its source procedure, one real-life destination running
  the SAME procedure, and one own-material micro-mission for today —
  the transfer conditions Dresler et al. (2017), Dunlosky et al. (2013)
  and Roediger & Karpicke (2006) ask for. Static copy keeps the claims
  policy (section 9) machine-checkable; the Spark recap stays for
  personalization.
  Code: `_TransferCard` in `lib/screens/benchmark.dart`,
  `bench_transfer_*` strings (EN+HU),
  `test/claims_policy_test.dart` (transfer scan).
- Practice-hub mapping (Nov 2026): each hub game scores the memory kind
  its procedure actually trains. The visual page holds two visual
  procedures — the pattern grid (`pattern-span`, Luck & Vogel 1997;
  Cowan 2001) and SAM picture masking (picture recall with occlusion:
  Shepard 1967; Standing 1973) — both scoring `visual`. The spatial
  page holds the measured method-of-loci walk (ordered stations, one
  noun each, station-cued recall: Maguire et al. 2003; Dresler et al.
  2017, scoring `spatial`) plus an unmeasured free-practice list in
  the player's own palace (list recognition is not the loci probe, so
  it earns no score).
  Code: `VisualGamePage` / `SamMaskGameBody` / `_PalaceWalkGame` /
  `_PalaceListGame` in `lib/screens/benchmark.dart`;
  `test/spatial_game_test.dart` (walk pairs, mask-scores-visual,
  practice-earns-nothing).

## 15. Picture loci: what SAM is for (Nov 2026)

Two questions drove this design: (1) is "name everything that was on
the picture" a scientifically valid drill at all, and (2) what can SAM
do in this app that nothing else can. Both answers are yes:

- Free recall of pictures IS a validated procedure — listing what was
  on the picture is free-recall retrieval practice, one of the
  strongest known effects: recall beats restudy at delay (Roediger &
  Karpicke 2006), recall formats beat recognition (Rowland 2014,
  g=0.50; Adesope et al. 2017, g=0.51), pictures beat words (Paivio
  dual coding; Shepard 1967; Standing 1973), and corrective feedback
  roughly doubles the testing effect. Conditions, all kept: typed
  recall (never multiple choice), immediate feedback per answer,
  spaced rounds with more objects (2→8). The offline word fallback is
  the same procedure without the picture.
- Location-cued picture recall is the SAM-native upgrade. Instead of
  free listing, each question asks the object under ONE numbered cover
  in walk order: study the numbered walk → mask → "what hides under
  cover N?" This is the picture analogue of the method-of-loci probe
  (station cues item: Maguire et al. 2003; Dresler et al. 2017),
  retrieval is still recall, and the location reinstates the encoding
  context (encoding specificity, Tulving & Thomson 1973; context
  reinstatement, Smith & Vela 2001). Guessing an object that hides
  under a DIFFERENT cover is scored wrong ("that hides elsewhere") —
  the binding of item to place is the trained skill (object-location
  binding: Chalfonte & Johnson 1996; Wheeler & Treisman 2002).
- Why SAM is essential: none of this works with boxes. Covers follow
  the object's true outline (Gollin 1960 fragmented-figures logic: the
  silhouette is a retrieval cue, not a giveaway), study dots sit on
  the shape centroid in walk order, and the glow ring marks only the
  cover under question. Box covers would leak rectangle edges and sit
  off-object; SAM shape masks make occlusion, silhouette cueing, and
  station-precise loci walks possible on any picture.
  Code: `SamMaskGameBody` cue loop (`_cue`, `matchRecallAnswer` per
  cover, `bench_mask_cue_hint` / `bench_mask_wrong_cover` /
  `bench_mask_walk_note`), `test/spatial_game_test.dart` (mask flow),
  `test/spatial_palace_rework_test.dart` (placeholder fallback).

Shape-occlusion engineering (same section, honest tech notes):

- SAM 3.1 returns base85 range-coded rasters on the documented wire
  grammar; the app decodes them in Dart (port of Meta's
  `meta_sam_parser` decoder, SAM License, attribution in
  `lib/models/sam_mask.dart`) and paints each cover from the raster
  runs scaled into its box — never a rectangle. Verified against
  Meta's own conformance vectors (lossless 3x2 + 11x11, one_bit 5x5).
- 1:1 mapping: generated art is square (512x512), so the masked
  picture renders square (capped at 380 px) — normalized SAM boxes map
  exactly onto the display. The old 220-px-high strip cropped square
  art under `BoxFit.cover` and every cover sat off its object.
- Covers never move: boxes are clamped, never pushed apart (a cover
  must sit on its object); only the number badges are separated when
  shapes stack. Objects with box geometry but no decodable mask get a
  soft rounded cover; objects with no geometry share the grid tiles.
  Code: `lib/models/sam_mask.dart`, `refinePictureMasks`,
  `_MaskedPicture` / `_SamCoverPainter` in `lib/screens/benchmark.dart`,
  `test/sam_mask_test.dart` (vectors + mock-server pairing).
