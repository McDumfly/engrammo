# Engrammo — hackathon submission

Meta Global AI Developer Hackathon (Cerebral Valley),
Oct 27 – Nov 4, 2026. Track: **Indie Dev (solo)**,
problem statement: **Build for Your World**.

Deadline: Wed, Nov 4, 9:00 PM ET. Submission: public repo
+ this file's demo script as a **3-minute video** showing
only features built during the hackathon (Participant
Guide §4, §7: new work only, or immediate
disqualification at judges' discretion).

## 1. What it is (30 seconds)

Engrammo is a memory-training gym: instead of mechanical
brain games (which do not transfer — Simons et al. 2016),
it teaches real mnemonic strategies (memory palace,
spaced repetition, active recall) and ends every lesson
in the learner's own material. Four hosted Meta models
— Muse Spark (text, vision and tool calling), Muse Image,
SAM 3.1 and Muse Wonder — are chained into one training
loop. If the Meta API is unreachable or no key is set,
every AI step falls back to deterministic local generators,
so no screen ever breaks. Offline banner; local features keep
working; bot duels also work offline.

## 2. Meta models in the loop

All calls go through one service,
`lib/services/meta_ai_service.dart` (model IDs in one
constants block at the top of `MetaAIService`; base URL
overridable via `META_API_BASE_URL`, default
`https://api.meta.ai/v1`).
Every call is logged with model, kind, and fallback state
(`MetaCallEntry`), viewable in the app under
Settings → Meta AI → recent calls, with per-model
live/local counters (`MetaCallLogView`).

| Model | Where it shows in the demo |
| --- | --- |
| Muse Spark (`muse-spark-1.3`) | Lesson/practice stimuli, technique teaching, forgetting diagnosis, personal tasks from own material, post-lesson/duel recaps; vision spotting reads the learner's room photo into stations |
| Muse Spark — tool calling | Session Coach agent: reads due reviews/weak spots/goals via 3 tools, submits a plan that a deterministic validator accepts or rejects (self-correction loop, visible trace) |
| Muse Image (`muse-image-1.0`) | Palace illustration, Room Palace dream scenes of the learner's own objects, visual-scene image, lesson art, endless unique picture-recall rounds |
| SAM 3.1 (`sam-3.1`) | Cuts exact object silhouettes out of the learner's own room photo — the covers ARE the retrieval cues (geometry only; names come from Spark spotting) |
| Muse Wonder (`muse-wonder-1.0`) | Spatial route preview from a second viewpoint |

Muse Glimmer and Muse Spark Open are open-weight and not
used in this build.

No key or no network → local generators take over and
the log marks each call `fallback: true`. Offline banner;
local features keep working; bot duels also work offline.

## 3. Judging cross-reference

Stage One (pass/fail): fits **Build for Your World**
(memory training is a firsthand student/professional
problem) and uses the Meta Model API throughout (Spark,
Image, SAM 3.1, Wonder — see the
table above).

Stage Two (0–10 each, equally weighted):

- **Impact.** Room Palace first: photograph your own room
  and train the method of loci on your own objects — Muse
  Spark names the stations, SAM 3.1 cuts their exact
  silhouettes as retrieval cues, Muse Image paints each
  fact onto them. Around it, a full research-based
  curriculum: 6 tracks, 36 chapters, 400+ short lessons,
  13-task assessment with interview, an FSRS-inspired
  scheduler (hand-tuned stability/difficulty rules, not
  fitted FSRS weights) that schedules Room Palace reviews
  while path lessons use a fixed review ladder (1 → 60
  days), goals, duels, leagues. Strategy-first design per
  the literature (`docs/RESEARCH.md`), not a chatbot and
  not medical advice (claims guardrail:
  `lib/models/claims_policy.dart`).
- **Use of Meta AI Tooling.** 4 hosted models, each doing
  what only it can (plan with tools, segment, illustrate,
  preview, spot, teach). Built solo with AI coding
  assistants, including the Muse Code coding agent for
  the final features (Room Palace, Session Coach).
- **Technical Depth & Execution.** One state pattern,
  merge-based offline-safe Firestore sync, per-card
  spaced state, `flutter analyze` clean, 128 test files
  (1165 tests) green, EN↔HU key/placeholder parity
  tests, consent gates, a live smoke test against the
  real Meta Model API
  (`test/live/meta_live_smoke_test.dart`, skipped without
  a key), and a deterministic Session Coach plan
  validator with a self-correction loop.
- **Demo.** Below: a working app, live Meta calls in the
  call log, fallback path shown by pulling the key.

Bonus angles: Best Creative Build (Muse Image dream scenes
of the learner's own room objects + Wonder route preview)
and Best Agentic Use-Case (Session Coach).

## 4. Demo script (3:00)

Record on a **real phone** (a simulator has no camera),
English UI, light theme. Burn in captions: judges often
watch muted. Where AI waits happen, speed them up and show
a small "2×" label (honest).

| Time | Screen | Voice-over / caption |
|---|---|---|
| 0:00–0:10 | Phone camera pointed at a real messy desk | "Brain games don't help you remember your life. Memory champions use one trick: the memory palace. Engrammo builds one — from your own room." |
| 0:10–0:35 | Room Palace → Take photo → "Muse Spark is reading your room…" → **SAM 3.1 silhouettes appear** on lamp, mug, plant, laptop, books, chair | "Muse Spark names the objects. SAM 3.1 cuts out their exact shapes. Six stations, in walking order." |
| 0:35–1:05 | "Use sample list" (cell biology) → Build → station cards with vivid links → **Muse Image dream scenes** pop in (mitochondria powering the lamp…) | "Muse Spark ties each fact to a real object with a vivid, interacting image. Muse Image paints it." |
| 1:05–1:35 | "Hide everything" → covers ARE the object silhouettes → type answers; one deliberate wrong answer → "That one lives at station 4" → finish 6/6 → "Next review: Thu" | "Recall is cued by the place — the exact method-of-loci test. The silhouette is the cue. A spaced scheduler sets the next review." |
| 1:35–2:05 | Practice tab → Today's plan → "Plan my session" → live trace: Read get_due_reviews, Read get_learner_snapshot, **Validator rejected…**, **Plan validated ✓** → tap Start on the palace review | "A Muse Spark agent reads my real data through tools and proposes a plan. A deterministic validator rejects bad plans until it's right. Every step is visible." |
| 2:05–2:30 | Fast montage (2–3 s each): learning path, a lesson with a palace image + Wonder preview, assessment result, a duel | "Around it: a full research-based curriculum — six memory tracks, 400+ lessons, an assessment, duels." |
| 2:30–2:45 | Settings → Meta AI → **per-model live counters** (Spark / Image / SAM / Wonder) | "Every call is logged. These are live Meta models — and if the API is down, every step falls back locally." |
| 2:45–3:00 | Back to the desk photo with covers, logo | "Engrammo. Teach your brain the technique, not the trick. Built Oct 27 – Nov 4 with Muse Spark, Muse Image, SAM 3.1 and Muse Wonder." |

## 5. Recording checklist

- [ ] Key works: call log shows `fallback: false`
  entries before recording.
- [ ] Fallback works: without key every shown path
  still renders (`fallback: true`).
- [ ] No personal data on screen (guest account, sample
  material only).
- [ ] EN UI for the video (HU parity is tested, EN is
  the judging language).
- [ ] Repo public, video link public, all contributors
  listed (solo: one).
- [ ] Video ≤ 3:00, hackathon-built features only.

## 6. New-work statement

Oct 26: plain `flutter create` scaffold only (initial
commit). Everything else — app code, docs, tests —
landed Oct 27 – Nov 4, 2026 in day-stamped build
commits; verify with `git log --format='%ad %s'
--date=short`. Nov 3–4: Room Palace, Session Coach agent,
live smoke test, live-proof panel. All code, text, and
screens are original work: no copied snippets, data, or
trademarked visuals.
