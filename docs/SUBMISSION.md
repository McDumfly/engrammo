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
in the learner's own material. Six Meta models are
wired into one training loop; everything works offline
too, with deterministic local generators as fallback.

## 2. Meta models in the loop

All calls go through one service,
`lib/services/meta_ai_service.dart` (model IDs in one
constants block, lines 97–105; base URL overridable via
`META_API_BASE_URL`, default `https://api.meta.ai/v1`).
Every call is logged with model, kind, and fallback state
(`MetaCallEntry`), viewable in the app under
Settings → Meta AI → recent calls.

| Model | Where it shows in the demo |
| --- | --- |
| Muse Spark (`muse-spark-1.3-contributor`) | Lesson/practice stimuli, technique teaching, forgetting diagnosis, personal tasks from own material, post-lesson/duel recaps; vision spotting reads pictures into stations |
| Muse Image (`muse-image-1.0`) | Palace illustration, visual-scene image, lesson art, endless unique picture-recall rounds |
| SAM 3.1 (`sam-3.1`) | Locates the lead station/object in palace/picture images (geometry; names come from Spark spotting) |
| Wonder (`muse-wonder-1.0`) | Spatial route preview from a second viewpoint |
| Glimmer / Spark Open (open-weight, self-host only — no Meta API endpoint) | Short post-game verdict / practice tip from built-in templates, honestly logged as local |

No key or no network → local generators take over and
the log marks each call `fallback: true`. The app never
depends on the network.

## 3. Judging cross-reference

Stage One (pass/fail): fits **Build for Your World**
(memory training is a firsthand student/professional
problem) and uses the Meta Model API throughout (Spark,
Image, SAM 3.1, Wonder — see the
table above). Glimmer and Spark Open are open-weight
with no Meta API endpoint, so their slots run on
built-in templates and are logged as local.

Stage Two (0–10 each, equally weighted):

- **Impact.** Real-world, daily-use training: 6 tracks ×
  13 lessons × 12 topics of curriculum, 13-task
  assessment with interview, spaced schedule, goals,
  duels, leagues. Strategy-first design per the
  literature (`docs/RESEARCH.md`), not a chatbot and not
  medical advice (claims guardrail:
  `lib/models/claims_policy.dart`).
- **Use of Meta AI Tooling.** 4 hosted models, each doing
  what only it can (segment, illustrate,
  preview, spot, teach) — plus this whole repo was
  built with the Muse Code coding agent. Two more
  open-weight slots (Glimmer, Spark Open) run local
  templates, since Meta serves no API endpoint for
  them.
- **Technical Depth & Execution.** One state pattern,
  merge-based offline-safe Firestore sync, per-card
  spaced state, `flutter analyze` clean, 98 test files
  (852 tests) green, EN↔HU key/placeholder parity
  tests, consent gates.
- **Demo.** Below: a working app, live Meta calls in the
  call log, fallback path shown by pulling the key.

Bonus angles: Best Creative Build (Muse Image + Wonder
in the palace loop). (No open-weight bonus claim:
Glimmer and Spark Open have no Meta-hosted endpoint,
so the app serves those slots from local templates.)

## 4. Demo script (3:00)

Setup: `.env` key in place, `sh tool/run.sh`, guest
entry, onboarding skipped, one goal pre-created, one
foundation lesson unlocked. Screen-record the phone.

- 0:00–0:20 — Hook: "Brain games don't transfer. This
  teaches you the memory palace, then tests you on YOUR
  exam material." Show the learning path.
- 0:20–0:50 — Assessment flash: one palace task + the
  interview answer; verdict assigns the track.
- 0:50–1:30 — Lesson: palace image generates (Muse
  Image), Spark spots the details into stations and SAM
  locates them (overlay), Spark teaches the technique,
  Wonder previews the route from a second viewpoint.
- 1:30–2:00 — Make-it-yours: paste own material → Spark
  builds a personal task → answer it → forgetting
  diagnosis.
- 2:00–2:30 — Practice + duel: tap SEEN/NEW answers
  in word practice, verdict + tip cards, one duel
  round vs a bot.
- 2:30–2:50 — Proof: Settings → Meta AI call log shows
  live models; remove the key, rerun one task → local
  fallback, no crash.
- 2:50–3:00 — Close: "Six tracks, spaced schedule,
  leagues — built Oct 27 – Nov 4 with Meta's models."

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
--date=short`. All code, text, and screens are original
work: no copied snippets, data, or trademarked visuals.
