/// The post-test interview: the self-report leg of the assessment.
///
/// Performance probes alone cannot tell *how* someone remembers — two
/// users can both score 100% while one replays a mental movie and the
/// other rehearses words. Combining a performance test with a
/// structured self-report is standard multitrait-multimethod practice
/// (Campbell & Fiske 1959): the interview breaks performance ties
/// instead of letting index order crown a fake winner.
///
/// Each question targets one published construct ([InterviewQuestion.construct]
/// + [InterviewQuestion.source], shown under the prompt) but is rewritten as
/// a direct coaching question — adapted, not verbatim, so no normed scale is
/// claimed. They deliberately never name the memory palace: at this stage we
/// measure the user's unaided strategy, we don't teach it.
///
/// Each option carries weights per memory-kind index
/// (0 sensory, 1 working, 2 spatial, 3 visual, 4 episodic, 5 semantic).
/// The weights are a transparent rational key (which answer reveals which
/// strategy), not a validated norm table: the interview only ever BREAKS
/// performance ties, it never overrides a measured score gap (see the
/// tie-only rule in `MetaAIService.interviewRequestBody` and rung 4 of
/// `resolveDominant`). The AI analysis reads these weights plus any custom
/// text; the offline fallback ([heuristicVerdict] in `memory_verdict.dart`)
/// uses the same weights, so online and offline agree by design.
library;

/// One selectable answer; [weights] maps kind index → points.
class InterviewOption {
  final String label;
  final Map<int, int> weights;
  const InterviewOption(this.label, this.weights);
}

/// One interview question with 4 selectable answers. Every question
/// also accepts free custom text, which the AI (or the keyword
/// fallback) reads as well.
class InterviewQuestion {
  final String id;
  final String prompt;
  final String hint;

  /// Published construct this question probes (shown under the prompt).
  final String construct;

  /// Source questionnaire/study of the construct (shown under the prompt).
  final String source;
  final List<InterviewOption> options;
  const InterviewQuestion({
    required this.id,
    required this.prompt,
    required this.hint,
    this.construct = '',
    this.source = '',
    required this.options,
  });
}

const interviewQuestions = [
  InterviewQuestion(
    id: 'q1-face',
    prompt:
        'Close your eyes and picture the face of a close friend. '
        'How clear is the image?',
    hint: 'Vividness of visual imagery (VVIQ-style)',
    construct: 'Visual imagery vividness',
    source: 'Adapted from VVIQ (Marks 1973)',
    options: [
      InterviewOption(
        'Crystal clear, every detail',
        {3: 2, 2: 1},
      ),
      InterviewOption(
        'Clear, but some parts are fuzzy',
        {3: 1, 4: 1},
      ),
      InterviewOption(
        'Vague blur, more a feeling than a picture',
        {0: 1, 5: 1},
      ),
      InterviewOption(
        'No picture at all — I just know facts about them',
        {5: 2, 1: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q2-house-walk',
    prompt:
        'Walk through your childhood home in your head, room by room. '
        'Can you do it and notice small details along the way?',
    hint: 'Spatial scene construction, no technique named yet',
    construct: 'Spatial scene construction',
    source: 'Hassabis & Maguire 2007; OSIQ-spatial (Blajenkova et al. 2006)',
    options: [
      InterviewOption(
        'Easily — I stroll through and see everything',
        {2: 2, 3: 1},
      ),
      InterviewOption(
        'Mostly, but I lose track in some rooms',
        {2: 1, 4: 1},
      ),
      InterviewOption(
        'I remember facts about it, not a walkable space',
        {5: 2},
      ),
      InterviewOption(
        'I get lost — spaces never stuck with me',
        {0: 1, 1: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q3-number',
    prompt:
        'Someone tells you a new phone number once. What do you do '
        'to hold onto it?',
    hint: 'Phonological loop vs visual vs chunking strategy',
    construct: 'Rehearsal strategy (phonological loop)',
    source: 'Baddeley & Hitch 1974; strategy probe',
    options: [
      InterviewOption(
        'Repeat it aloud or in my head, over and over',
        {0: 2, 1: 1},
      ),
      InterviewOption(
        'See the digits written out in front of me',
        {3: 2, 1: 1},
      ),
      InterviewOption(
        'Split it into groups, like 49-16-25',
        {1: 2, 5: 1},
      ),
      InterviewOption(
        'Tie it to something I know — a date, an address',
        {4: 1, 5: 2},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q4-yesterday',
    prompt:
        'Think back to yesterday afternoon. How does it come back to you?',
    hint: 'Episodic replay vs semantic listing',
    construct: 'Episodic reliving vs semantic listing',
    source: 'Tulving 1972 episodic/semantic distinction',
    options: [
      InterviewOption(
        'Like replaying a movie, scene by scene',
        {4: 2, 3: 1},
      ),
      InterviewOption(
        'Moments pop up, but out of order',
        {4: 1, 0: 1},
      ),
      InterviewOption(
        'As a list of facts: where I was, who I met',
        {5: 2, 1: 1},
      ),
      InterviewOption(
        'Barely at all — yesterday is already foggy',
        {1: 1, 0: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q5-new-word',
    prompt:
        'You learn a new word in another language. What makes it stick?',
    hint: 'Keyword imagery vs verbal rehearsal vs meaning links',
    construct: 'Keyword-imagery vs verbal rehearsal',
    source: 'Atkinson & Raugh 1975 keyword method',
    options: [
      InterviewOption(
        'A funny picture linking the sound to the meaning',
        {3: 2, 5: 1},
      ),
      InterviewOption(
        'Saying it many times until it sounds right',
        {0: 2, 1: 1},
      ),
      InterviewOption(
        'Connecting it to words I already know',
        {5: 2, 1: 1},
      ),
      InterviewOption(
        'Placing it somewhere — a room, a route, a scene',
        {2: 2, 4: 1},
      ),
    ],
  ),
  InterviewQuestion(
    id: 'q6-new-place',
    prompt:
        'You visit a new neighborhood once. How do you find your way '
        'back the second time?',
    hint: 'Sense of direction (SBSOD-style)',
    construct: 'Sense of direction',
    source: 'Adapted from SBSOD (Hegarty et al. 2002)',
    options: [
      InterviewOption(
        'A map just forms in my head',
        {2: 2, 1: 1},
      ),
      InterviewOption(
        'I remember striking sights along the way',
        {3: 2, 2: 1},
      ),
      InterviewOption(
        'I replay the turns as instructions: left, right, straight',
        {1: 2, 5: 1},
      ),
      InterviewOption(
        'I remember who I was with and what we talked about',
        {4: 2, 0: 1},
      ),
    ],
  ),
];
