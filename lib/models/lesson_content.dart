library;

import '../l10n/lesson_content_hu.dart';

class CoachContent {
  final String title;
  final String intro;
  final List<String> steps;
  final String why;
  final String source;
  const CoachContent({
    required this.title,
    required this.intro,
    required this.steps,
    required this.why,
    required this.source,
  });
}

const coachContent = <String, CoachContent>{
  '0-0': CoachContent(
    title: 'The Attention Gate',
    intro:
        'You forget names because you never really heard them. Your brain '
        'was busy rehearsing your own introduction. Fix the intake and the '
        'memory fixes itself.',
    steps: [
      'Stop your inner rehearsal the second someone starts talking.',
      'Repeat the name back immediately: "Nice to meet you, Anna."',
      'Ask for the spelling when you can — it buys you a second exposure.',
    ],
    why:
        'Divided attention at encoding wrecks memory far more than '
        'distraction at recall. Full attention in, memory out.',
    source: 'Craik, Govoni, Naveh-Benjamin & Anderson (1996)',
  ),
  '0-1': CoachContent(
    title: 'Audio Flash',
    intro:
        'Your echoic memory holds raw sound for a few seconds. Say it back '
        'fast and it sticks. Hesitate and it evaporates.',
    steps: [
      'Listen once, then say the sequence aloud right away.',
      'Group sounds into rhythm: "seven-three — nine".',
      'Recall before you look: pull it out, do not re-read.',
    ],
    why:
        'Saying words aloud beats silent reading (the production effect), '
        'and rhythm chunks items so short-term memory holds more.',
    source: 'MacLeod et al. (2010); Purnell-Webb & Speelman (2008)',
  ),
  '0-2': CoachContent(
    title: 'Focus Under Noise',
    intro:
        'Real life is noisy. Champions do not need silence — they train to '
        'lock onto one signal while the world chatters.',
    steps: [
      'Pick one voice or stream and follow only that.',
      'Filter everything else into background hum.',
      'Replay the target from memory the instant it ends.',
    ],
    why:
        'Selective attention is trainable: practiced filtering protects '
        'encoding. How much noisy-room practice helps daily life varies '
        'person to person — no promise either way.',
    source: 'Naveh-Benjamin et al. (2005); Robison & Unsworth (2015)',
  ),
  '1-0': CoachContent(
    title: 'Digit Chunks',
    intro:
        'Few people hold 12 separate digits. Trained chunkers hold 4 '
        'images instead. Chunking turns a hard string into a short story.',
    steps: [
      'Split digits into groups of 3: 491-625-830.',
      'Turn each group into one vivid image or word.',
      'Link the images in order and walk through them.',
    ],
    why:
        'Working memory holds about 4 chunks, but a chunk can be huge '
        'once you recode it. One trained student reached 80 digits.',
    source: 'Cowan (2001); Ericsson, Chase & Faloon (1980)',
  ),
  '1-1': CoachContent(
    title: 'Card Systems',
    intro:
        'Cards look random until every card becomes a person you know. '
        'Then a deck becomes a party, and the order becomes gossip.',
    steps: [
      'Give each card one fixed image (7 of hearts = your friend Hal).',
      'Place 2-3 cards per station as one interacting scene.',
      'Walk your route in order — never skip a station.',
    ],
    why:
        'Pre-learned image codes plus ordered places convert random '
        'sequences into narratable scenes. Card-record holders report '
        'using palace plus PAO systems.',
    source: 'PAO system survey; memory-sport discipline formats',
  ),
  '1-2': CoachContent(
    title: 'Working Memory Gym',
    intro:
        'Holding items while flipping them around is the core rep of '
        'working memory. Short sets, full effort, then rest.',
    steps: [
      'Hold the whole set in mind before you start reversing.',
      'Work backwards one item at a time, out loud.',
      'If you drop one, restart the set — no peeking.',
    ],
    why:
        'Backward span taxes the central executive, not just storage. '
        'Honest note: drills improve at drills; the transfer comes from '
        'the strategies you learn with them.',
    source: 'Baddeley & Hitch (1974); Melby-Lervåg et al. (2016)',
  ),
  '2-0': CoachContent(
    title: 'Your First Palace',
    intro:
        'This is the big one. Memory competitors memorize long lists '
        'with this same method: put each item in a familiar place, then '
        'walk through and pick them up.',
    steps: [
      'Pick a route you know cold: your home, front door to bedroom.',
      'Choose 5 stations in fixed order (door, couch, lamp...).',
      'Place ONE bizarre, moving image per station and walk it twice.',
    ],
    why:
        'The method of loci routes lists through your navigation brain — '
        'a huge, ancient system. In Dresler et al. (2017), six weeks of '
        'loci training shifted beginners toward the athlete pattern.',
    source: 'Maguire et al. (2003); Dresler et al. (2017, Neuron)',
  ),
  '2-1': CoachContent(
    title: 'Bigger Palaces',
    intro:
        'Five stations is a shed. You are building a palace now. More '
        'stations, same rule: one vivid scene each, always in order.',
    steps: [
      'Extend your route to 10, then 15 stations.',
      'Keep stations distinct: no two chairs, no vague corners.',
      'Review by walking forward only — backwards walks blur order.',
    ],
    why:
        'Distinct loci prevent interference between items. In Krokos '
        "et al.'s study, virtual palaces lifted retention ~30% over "
        'flat lists in beginners.',
    source: 'Krokos et al. VR palace study; Wagner et al. (2021)',
  ),
  '2-2': CoachContent(
    title: 'Palace Exam',
    intro:
        'Time to test it. Long route, full list, one clean walk — no '
        'peeking, no skipping. Review day shows what your system can do.',
    steps: [
      'Encode slowly: 10 seconds per station beats rushing.',
      'Close your eyes and walk the whole route before answering.',
      'Missed one? Strengthen that station image and walk again.',
    ],
    why:
        'In the studies, retrieval practice beats re-study by a wide '
        'margin, and the advantage grows with delay. Test yourself, '
        'do not re-read.',
    source: 'Roediger & Karpicke (2006); Rowland (2014) meta-analysis',
  ),
  '3-0': CoachContent(
    title: 'See It Big',
    intro:
        'Your visual memory is enormous — thousands of pictures stick '
        'after one glance. The trick is making boring items picturable.',
    steps: [
      'Turn every item into a picture, even abstract words.',
      'Make it big, bright, and moving in your mind.',
      'Attach it to something already in the scene.',
    ],
    why:
        'Pictures get two memory codes (visual + verbal) instead of '
        'one. That double code is the picture-superiority effect.',
    source: 'Paivio dual-coding theory; Shepard (1967); Standing (1973)',
  ),
  '3-1': CoachContent(
    title: 'Weird Wins',
    intro:
        'Normal is forgettable. Your brain flags the strange, the funny, '
        'and the rude — so encode that way on purpose.',
    steps: [
      'Take your plain image and break it somehow.',
      'Add motion, size, or something socially absurd.',
      'Interact items with each other — never let them sit alone.',
    ],
    why:
        'Distinctive items pop out of memory (the Von Restorff '
        'effect). Interactive images usually beat lonely ones.',
    source: 'Von Restorff (1933); Wollen et al. bizarre-imagery work',
  ),
  '3-2': CoachContent(
    title: 'Imagery Lab Finals',
    intro:
        'Abstract shapes, fast flashes, no mercy. This is where you learn '
        'that even "unpicturable" patterns yield to forced imagery.',
    steps: [
      'Name what you see instantly — words anchor pictures.',
      'Exaggerate one feature per item to tell twins apart.',
      'Reconstruct from memory before checking the answer.',
    ],
    why:
        'Verbal labels plus images give you dual retrieval routes. '
        'Effortful reconstruction strengthens the trace (desirable '
        'difficulty).',
    source: 'Paivio & Desrochers (1979); Bjork (1994)',
  ),
  '4-0': CoachContent(
    title: 'Story Chains',
    intro:
        'Episodes stick when they become stories. A random list is hard; '
        'the same items as one silly adventure are easy.',
    steps: [
      'Link item 1 to item 2 with an action, then 2 to 3, and so on.',
      'Keep ONE chain — branching chains snap.',
      'Retell the story start to finish, out loud if you can.',
    ],
    why:
        'Narrative chaining adds order plus meaning. In the studies, '
        'elaborative encoding (rich sentences) beats shallow '
        'repetition clearly.',
    source: 'Craik & Tulving (1975); elaborative-encoding literature',
  ),
  '4-1': CoachContent(
    title: 'Journal Recall',
    intro:
        'Champions review their day every evening. Ten minutes of replay '
        'before sleep buys you the night shift of consolidation for free.',
    steps: [
      'Each evening, replay your day backwards, scene by scene.',
      'Pause on details: faces, numbers, exact words.',
      'Write down the three hardest recalls.',
    ],
    why:
        'Sleep consolidates what you studied close to bedtime, and '
        'expecting a test gates what sleep keeps. Review, then sleep.',
    source: 'Gais, Lucas & Born (2006); Wilhelm et al. (2011)',
  ),
  '4-2': CoachContent(
    title: 'Night Consolidation',
    intro:
        'You do not learn only while awake. Tonight your brain replays '
        'the day — give it clean material to replay.',
    steps: [
      'Walk one full palace right before bed.',
      'Do not cram new items after the walk — let it settle.',
      'Recall the same walk first thing in the morning.',
    ],
    why:
        'In the lab studies, evening-learned vocabulary was forgotten far '
        'less than morning learning, and a night between sessions roughly '
        'halved relearning. Individual results vary.',
    source: 'Gais et al. (2006); Mazza et al. (2016)',
  ),
  '5-0': CoachContent(
    title: 'Baker Breaker',
    intro:
        'Why is "baker" easy but "Mr. Baker" so hard? Same sound — but '
        'one has meaning and an image. Give every name both.',
    steps: [
      'Spot one standout facial feature first.',
      'Turn the name into a picture (Baker = white hat).',
      'Stick the picture ONTO the feature and make it interact.',
    ],
    why:
        'In the lab study, the 3-step face-name mnemonic lifted recall '
        'from 42% to 79% — a very large effect (d ≈ 2.4). Your results '
        'depend on practice.',
    source: 'Morris et al. face-name mnemonic (d ≈ 2.4)',
  ),
  '5-1': CoachContent(
    title: 'Keyword Chain',
    intro:
        'Foreign words feel slippery until you bolt them to a word you '
        'know. Sound-alike keyword plus crazy image: locked.',
    steps: [
      'Find a native word that sounds like the foreign one.',
      'Picture the keyword interacting with the meaning.',
      'Test yourself both directions, with feedback every time.',
    ],
    why:
        'In the lab studies, the keyword method averaged 72% against 46% '
        'for rote study, with retention lasting years given brief reviews. '
        'Your results depend on practice.',
    source: 'Atkinson & Raugh (1975); Beaton et al. (1995)',
  ),
  '5-2': CoachContent(
    title: 'Meaning Web',
    intro:
        'Deep beats shallow. Ask what a word means, where it comes from, '
        'and what it connects to — and it stops being arbitrary.',
    steps: [
      'Ask "why" about every fact, not just "what".',
      'Connect each item to two things you already know.',
      'Explain it in your own words before moving on.',
    ],
    why:
        'In the studies, semantic, self-explained encoding beats shallow '
        'rehearsal clearly. Time on task alone does not explain it — '
        'depth does.',
    source: 'Craik & Tulving (1975); Chi et al. (1994)',
  ),
  '6-0': CoachContent(
    title: 'Palace Workshop',
    intro:
        'You know the basics. Now you practice the competitor format: '
        'fixed routes, timed encoding, every station walked.',
    steps: [
      'Use one dedicated competition palace per drill.',
      'Encode on a timer — pressure is part of the skill.',
      'Score every run: items correct, stations clean.',
    ],
    why:
        'Athletes show no structural brain advantage — only superior '
        'strategy use and loci-network recruitment. It is all trained.',
    source: 'Maguire et al. (2003); Dresler et al. (2017)',
  ),
  '6-1': CoachContent(
    title: 'Number Systems Lab',
    intro:
        'Two-digit images, chained three at a time into Person-Action-'
        'Object scenes. Six digits per station. That is how 80-digit '
        'sprints become possible.',
    steps: [
      'Fix one image for every 00-99 pair — no improvising mid-run.',
      'Chain 3 pairs per station: person does action to object.',
      'Drill the images alone until recall is instant.',
    ],
    why:
        'Long-term working memory: experts retrieve huge chunks via '
        'learned structures. Automatic codes free attention for order.',
    source: 'Ericsson & Kintsch (1995) LTWM; PAO system survey',
  ),
  '6-2': CoachContent(
    title: 'Name & Word Lab',
    intro:
        'Timed names and words come fast and rarely repeat. Speed '
        'plus the 3-step method plus keyword chains — all at once.',
    steps: [
      'Feature first, image second, interaction third — in seconds.',
      'Chain words into one running story as they appear.',
      'Review with expanding gaps: 1 min, 5 min, 30 min.',
    ],
    why:
        'Expanding retrieval schedules were first shown on names '
        'and faces. Reviews rate spaced retrieval among the '
        'highest-utility strategies.',
    source: 'Landauer & Bjork (1978); Dunlosky et al. (2013)',
  ),
  '7-0': CoachContent(
    title: 'Speed Numbers Final',
    intro:
        'Eighty digits. Seconds ticking. This is the international '
        'sprint-final format — your systems get their timed test here.',
    steps: [
      'Encode in fixed 6-digit PAO scenes, no hesitation.',
      'Trust your palace: walk it once, commit, move on.',
      'Review errors by station — fix the code, not your courage.',
    ],
    why:
        'Speed events separate automatic systems from improvised ones. '
        'For reference, the listed 2025 best is 80 digits in about '
        '13.5 seconds — years of training away.',
    source: 'International sprint record tables (2025)',
  ),
  '7-1': CoachContent(
    title: 'Speed Cards Final',
    intro:
        'A full shuffled deck, against the clock. Three cards per scene, '
        'seventeen scenes, one palace. Go.',
    steps: [
      'Pre-assign every card its PAO role before you start.',
      'One look per scene — re-reading kills your time.',
      'Recall in order, station by station, no jumping.',
    ],
    why:
        'The listed deck record is about 12.7 seconds (2025 tables). '
        'Surveyed record holders report palace plus PAO systems — '
        'a format to practice, not a target for this month.',
    source: 'Record tables (2025); card-memorization survey',
  ),
  '7-2': CoachContent(
    title: 'Palace Marathon',
    intro:
        'Twenty-seven items in one walk was the lab milestone. You '
        'practice past it: fifty, then a hundred. One pass is the '
        'foundation — lasting skill needs spaced review over many months '
        'plus walks with your own lists.',
    steps: [
      'Chain multiple palaces into one grand route.',
      'Place review walks the same evening and next morning.',
      'Keep every station image fresh — revisit, do not rebuild.',
    ],
    why:
        'In Dresler et al. (2017), lab trainees who practiced this way '
        'kept gains at 4 months. Your results depend on continued review.',
    source: 'Dresler et al. (2017); Wagner et al. (2021)',
  ),
  '8-0': CoachContent(
    title: 'Rhythm Codes',
    intro:
        'Rhythm is chunking for the ears. A beat groups stray sounds '
        'into bars, and bars are what your memory actually keeps.',
    steps: [
      'Clap or tap the pattern back before you answer.',
      'Group beats into bars of 3 or 4, never a flat string.',
      'Replay the bar in your head once before recalling.',
    ],
    why:
        'Temporal grouping lifts auditory span the same way visual '
        'chunking lifts digit span: structure carries the items.',
    source: 'Purnell-Webb & Speelman (2008); Cowan (2001)',
  ),
  '8-1': CoachContent(
    title: 'Delayed Echo',
    intro:
        'Echoic memory fades in seconds — unless you rehearse it. This '
        'part trains the hold: keep the trace alive across a delay.',
    steps: [
      'Repeat the items silently during the whole delay.',
      'Do not peek early: the struggle is the training.',
      'Rebuild from the first item, in order, after the wait.',
    ],
    why:
        'Maintenance rehearsal extends the echoic trace, and delayed '
        'recall practice builds retrieval strength that lasts.',
    source: 'Baddeley & Hitch (1974); Rowland (2014) meta-analysis',
  ),
  '8-2': CoachContent(
    title: 'Overlapping Voices',
    intro:
        'The cocktail-party problem is real life: one target voice in '
        'a wash of others. Train the filter and recall gets easy.',
    steps: [
      'Lock onto the target voice in the first second.',
      'Let other voices blur into background texture.',
      'Replay the target stream the instant it stops.',
    ],
    why:
        'Selective auditory attention gates what gets encoded. What '
        'you never isolated, you cannot later recall.',
    source: 'Naveh-Benjamin et al. (2005); Robison & Unsworth (2015)',
  ),
  '9-0': CoachContent(
    title: 'Sound Pictures',
    intro:
        'Sounds evaporate; pictures stick. So turn every sound into a '
        'picture the moment you hear it — double code, double memory.',
    steps: [
      'Give each sound one concrete image on the spot.',
      'Make the image move or collide with the next one.',
      'Recall the images first, then translate back to sounds.',
    ],
    why:
        'Dual coding works for audio too: a verbal-plus-visual trace '
        'survives far better than a bare echo.',
    source: 'Paivio dual-coding theory; MacLeod et al. (2010)',
  ),
  '9-1': CoachContent(
    title: 'Melody Routes',
    intro:
        'Now the sounds move into a palace. Each station holds one '
        'sound-image, and the route holds the order for free.',
    steps: [
      'Walk a short known route, one sound per station.',
      'Make each sound interact with its station.',
      'Recall by walking forward — never jump around.',
    ],
    why:
        'Loci supply order plus distinct contexts, killing the '
        'interference that usually wrecks long sound lists.',
    source: 'Maguire et al. (2003); Wagner et al. (2021)',
  ),
  '9-2': CoachContent(
    title: 'Timbre Tags',
    intro:
        'Similar sounds merge into mush. Tag each one by pitch, volume '
        'or tempo and they stay separate in memory.',
    steps: [
      'Label each sound as you hear it: high, loud, fast.',
      'Exaggerate the tag in your head on purpose.',
      'Recall tag first, then the sound attached to it.',
    ],
    why:
        'Distinctive features cut interference between similar items '
        '— the auditory version of the isolation effect.',
    source: 'Von Restorff (1933); Baddeley & Hitch (1974)',
  ),
  '10-0': CoachContent(
    title: 'Speed Echo',
    intro:
        'Real speech does not wait. This part shrinks your encoding '
        'time until one second per item feels comfortable.',
    steps: [
      'Chunk on the fly: group as the sounds arrive.',
      'Never pause the stream — trust partial codes.',
      'Recall immediately, in order, out loud.',
    ],
    why:
        'Fast-encoding practice automates chunking, freeing attention '
        'for storage instead of fumbling with format.',
    source: 'Ericsson, Chase & Faloon (1980); Cowan (2001)',
  ),
  '10-1': CoachContent(
    title: 'Crowd Filter',
    intro:
        'A full hall of noise is the final exam for attention. Same '
        'skill as before, turned up until it feels like pressure.',
    steps: [
      'Pick your target stream before the noise starts.',
      'Breathe steady: tension narrows attention too far.',
      'Replay from memory instantly — noise erases traces fast.',
    ],
    why:
        'Training under load transfers: filters built in noise hold '
        'up in noisy real life, not just in silence.',
    source: 'Naveh-Benjamin et al. (2005)',
  ),
  '10-2': CoachContent(
    title: 'Long Replays',
    intro:
        'Twenty items in one hearing. Impossible raw — routine with '
        'rhythm, pictures, routes and tags stacked together.',
    steps: [
      'Stack every tool: rhythm first, then images, then route.',
      'Encode slowly and carefully on the first pass.',
      'Walk the whole set once before answering anything.',
    ],
    why:
        'Combined strategies multiply: each code adds a retrieval '
        'route, and long lists need every route they can get.',
    source: 'Dresler et al. (2017); Ericsson & Kintsch (1995)',
  ),
  '11-0': CoachContent(
    title: 'Number Sprint by Ear',
    intro:
        'Phone numbers read once, in noise, remembered. That is the '
        'party trick — and it is just chunking plus attention.',
    steps: [
      'Chunk digits live into groups of 3 as you hear them.',
      'Picture each chunk instantly, one image per group.',
      'Say the full number back within seconds.',
    ],
    why:
        'Live chunking converts an echo problem into an image problem, '
        'and images survive where echoes die.',
    source: 'Ericsson, Chase & Faloon (1980); Paivio (1979)',
  ),
  '11-1': CoachContent(
    title: 'Speech Shadowing',
    intro:
        'Repeat speech half a beat behind the speaker. Interpreters '
        'train exactly this — it fuses listening and memory.',
    steps: [
      'Start echoing after the first two or three words.',
      'Stay half a beat behind, never catching up fully.',
      'Keep going when you stumble: rejoin, do not restart.',
    ],
    why:
        'Shadowing forces continuous encoding plus immediate production, '
        'a demanding loop that interpreters train daily.',
    source: 'MacLeod et al. (2010); interpreter-training literature',
  ),
  '11-2': CoachContent(
    title: 'Golden Ear Review',
    intro:
        'Everything at once: names in noise, long sequences, delayed '
        'recall. Pass this and you have practiced the full listening '
        'stack on trained material — keep it with weekly review and '
        'real conversations.',
    steps: [
      'Settle your attention before each trial starts.',
      'Encode with your full stack: rhythm, image, route, tag.',
      'Recall in order, commit, and move to the next trial.',
    ],
    why:
        'Review pressure tests automaticity: practiced systems hold up, '
        'improvised ones wobble. Then retest on fresh items next week.',
    source: 'Timed sprint formats; Dresler et al. (2017)',
  ),
  '12-0': CoachContent(
    title: 'Major 00-19',
    intro:
        'The Major system turns digits into consonants, consonants into '
        'words, words into pictures. Twenty codes to start.',
    steps: [
      'Learn each code as one fixed, vivid image.',
      'Never improvise mid-drill: fixed codes only.',
      'Drill image-to-number until recall is instant.',
    ],
    why:
        'Pre-learned codes offload encoding: you recognize instead of '
        'invent, which is why 80-digit sprints are possible.',
    source: 'Major system tradition; Ericsson & Kintsch (1995)',
  ),
  '12-1': CoachContent(
    title: 'Image Pairs',
    intro:
        'Codes are useless if they are slow. This part drills your '
        '00-19 images until each pair fires in under two seconds.',
    steps: [
      'Flash through pairs daily, timing yourself.',
      'Strengthen slow pairs with wilder images.',
      'Test number-to-image and image-to-number both.',
    ],
    why:
        'Automatic retrieval frees working memory for order and '
        'structure — the actual hard part of long numbers.',
    source: 'Ericsson & Kintsch (1995) LTWM',
  ),
  '12-2': CoachContent(
    title: 'First PAO Scenes',
    intro:
        'Person-Action-Object: three pairs become one scene, six digits '
        'become one image. This is the engine of number records.',
    steps: [
      'Assign each pair its person, action and object.',
      'Merge three pairs into one interacting scene.',
      'Place one scene per palace station.',
    ],
    why:
        'PAO triples chunk density: 6 digits per station instead of 2, '
        'which is exactly how decks and sprints fall.',
    source: 'Competition PAO system survey',
  ),
  '13-0': CoachContent(
    title: 'Suit Persons',
    intro:
        'Fifty-two cards, fifty-two people you know cold. Learn them '
        'suit by suit and the deck stops being random.',
    steps: [
      'Give every card one fixed person — no swaps.',
      'Use people you can picture instantly.',
      'Drill shuffled cards until naming is instant.',
    ],
    why:
        'Fixed card images convert random sequences into social scenes, '
        'which memory handles far better than suits.',
    source: 'Card-memorization survey; PAO system',
  ),
  '13-1': CoachContent(
    title: 'Action Links',
    intro:
        'Two cards meet and something happens. Link persons with wild '
        'actions and the order locks itself in.',
    steps: [
      'Pair cards and invent one interaction per pair.',
      'Make actions physical and exaggerated.',
      'Replay scenes in order, station by station.',
    ],
    why:
        'Interactive images beat lonely ones: the action binds the '
        'pair and preserves its order.',
    source: 'Wollen et al. bizarre-imagery work',
  ),
  '13-2': CoachContent(
    title: 'Half-Deck Flows',
    intro:
        'Twenty-six cards on one palace walk. Slow first, then faster '
        '— flow comes from clean systems, not from rushing.',
    steps: [
      'Pre-assign every scene before the clock starts.',
      'One look per scene: re-reading kills flow.',
      'Recall station by station, never jumping.',
    ],
    why:
        'Palace plus PAO is the standard card method: surveyed record '
        'holders report using it.',
    source: 'Record tables (2025); card-memorization survey',
  ),
  '14-0': CoachContent(
    title: 'Running Totals',
    intro:
        'Hold a number while new numbers keep coming. Updating — not '
        'just storage — is the core of working memory.',
    steps: [
      'Keep the total in mind as one chunk.',
      'Update it with each new number, dropping the old.',
      'Say the total aloud at checkpoints.',
    ],
    why:
        'Updating tasks tax the central executive directly, the part of '
        'working memory that drills actually exercise.',
    source: 'Baddeley & Hitch (1974); Melby-Lervåg et al. (2016)',
  ),
  '14-1': CoachContent(
    title: 'Backward Chains',
    intro:
        'Forward is storage; backward is control. Reversing a sequence '
        'forces your executive to manipulate, not just hold.',
    steps: [
      'Hold the whole set before you start reversing.',
      'Work backwards one item at a time, out loud.',
      'If you drop one, restart — no peeking.',
    ],
    why:
        'Backward span predicts reasoning better than forward span: it '
        'measures manipulation, the skill this part builds.',
    source: 'Baddeley & Hitch (1974)',
  ),
  '14-2': CoachContent(
    title: 'Dual Tasks',
    intro:
        'Two streams at once: hold one, work on the other. This is the '
        'gym heavyweight — short sets, full effort.',
    steps: [
      'Split attention deliberately: name each stream.',
      'Finish micro-steps on one before switching.',
      'Expect failure early: capacity grows with honest reps.',
    ],
    why:
        'Dual-task practice trains executive coordination itself. Honest '
        'note: drills improve at drills first — everyday benefit varies '
        'person to person, with no promise either way.',
    source: 'Baddeley & Hitch (1974); Melby-Lervåg et al. (2016)',
  ),
  '15-0': CoachContent(
    title: 'Second Palace',
    intro:
        'One palace fills up fast. Champions keep dozens: a second '
        'route doubles your capacity and rests the first.',
    steps: [
      'Pick a new route you know cold, unlike the first.',
      'Fix 15 stations in strict order before placing items.',
      'Quiz both palaces separately — no cross-talk.',
    ],
    why:
        'Separate routes prevent interference between lists. Distinct '
        'contexts are what make reuse possible at all.',
    source: 'Maguire et al. (2003); Wagner et al. (2021)',
  ),
  '15-1': CoachContent(
    title: 'Palace Linking',
    intro:
        'Two palaces become one district with a bridge. Linked routes '
        'carry forty stations in a single walk.',
    steps: [
      'Build a vivid bridge between the two routes.',
      'Walk the full district slowly twice before testing.',
      'Always enter in the same order — order is memory.',
    ],
    why:
        'Chained routes preserve order across palace boundaries, '
        'extending loci far past single-route limits.',
    source: 'Wagner et al. (2021); Dresler et al. (2017)',
  ),
  '15-2': CoachContent(
    title: 'Palace Upkeep',
    intro:
        'Old images haunt stations like ghosts. Learn to wipe, rest '
        'and rotate palaces so every encoding starts clean.',
    steps: [
      'Walk empty first and note any stale images.',
      'Wipe ghosts by vividly erasing each station.',
      'Rest used palaces a day while others work.',
    ],
    why:
        'Proactive interference from old images is the top cause of '
        'palace errors. Maintenance beats rebuilding.',
    source: 'Competition practice survey; Wagner et al. (2021)',
  ),
  '16-0': CoachContent(
    title: 'Five-Second Scenes',
    intro:
        'Competitions give seconds per item. Train the clock until a '
        'sticky scene forms in five seconds flat.',
    steps: [
      'Set a timer: five seconds per station, no more.',
      'First image wins — never re-encode mid-run.',
      'Score sticky vs blank stations after each run.',
    ],
    why:
        'Timed encoding practice builds the automaticity that speed '
        'events demand. Hesitation is the only enemy.',
    source: 'International sprint formats; Dresler et al. (2017)',
  ),
  '16-1': CoachContent(
    title: 'One-Pass Walks',
    intro:
        'Walk once, encode once, never re-enter. One-pass discipline '
        'turns a stroll into a competition run.',
    steps: [
      'Commit to every station as you pass it.',
      'Never walk back to fix a weak image.',
      'Recall with a single clean forward walk.',
    ],
    why:
        'Re-entry during encoding blurs order and doubles time. '
        'One-pass trust is what finals reward.',
    source: 'Competition loci practice; Maguire et al. (2003)',
  ),
  '16-2': CoachContent(
    title: 'Error Repair',
    intro:
        'After the run comes triage: find weak stations, rebuild them '
        'stronger, verify with a re-walk. Champions repair.',
    steps: [
      'Recall first and mark every gap honestly.',
      'Rebuild gaps with bigger, weirder, moving images.',
      'Re-walk the full route to verify the fix.',
    ],
    why:
        'Targeted repair plus retrieval practice beats full re-study: '
        'effort goes exactly where memory failed.',
    source: 'Roediger & Karpicke (2006); Rowland (2014)',
  ),
  '17-0': CoachContent(
    title: 'Grand Route',
    intro:
        'Fifty stations, one palace, one walk. This is the biggest '
        'single route you have ever built — plan it like an architect.',
    steps: [
      'Map all stations on paper before encoding.',
      'Keep every station distinct: no twins allowed.',
      'Walk it empty twice, then encode once.',
    ],
    why:
        'Pre-planned distinct loci are the whole game at scale. Fifty '
        'clean stations beat a hundred blurry ones.',
    source: 'Maguire et al. (2003); Krokos et al. VR study',
  ),
  '17-1': CoachContent(
    title: 'Multi-Palace Chain',
    intro:
        'One hundred stations across chained palaces. This is long '
        'distance — the same scale as international long events.',
    steps: [
      'Chain three rested palaces with strong bridges.',
      'Encode in order, one palace at a time.',
      'Review the same evening and next morning.',
    ],
    why:
        'Chained-palace long lists with spaced review show durable '
        'gains at four months and beyond.',
    source: 'Dresler et al. (2017); Wagner et al. (2021)',
  ),
  '17-2': CoachContent(
    title: 'Grand Walk',
    intro:
        'One hundred words, one walk, recalled the next morning. Pass '
        'this and you can run a 100-station walk on practiced routes — '
        'new routes and lasting skill need more walks over more weeks.',
    steps: [
      'Encode the evening before, slowly and cleanly.',
      'Sleep on it — consolidation does half the work.',
      'Recall blind the next morning, station by station.',
    ],
    why:
        'Sleep consolidates spatial learning powerfully. Evening '
        'encoding plus morning recall is a searching test of it.',
    source: 'Gais, Lucas & Born (2006); Dresler et al. (2017)',
  ),
  '18-0': CoachContent(
    title: 'Twin Spotter',
    intro:
        'Near-identical images are memory poison — unless you train '
        'discrimination. Spot the difference, then remember it.',
    steps: [
      'Scan twins side by side, top to bottom.',
      'Name each difference out loud as you find it.',
      'Exaggerate one difference per pair to anchor it.',
    ],
    why:
        'Verbal labels plus distinctive features give twins separate '
        'traces instead of one merged mush.',
    source: 'Paivio & Desrochers (1979); Von Restorff (1933)',
  ),
  '18-1': CoachContent(
    title: 'Pattern Vault',
    intro:
        'Abstract grids carry no meaning — so you supply it. Name '
        'motifs, chunk cells, and the unrememberable files away.',
    steps: [
      'Name what each motif looks like instantly.',
      'Chunk the grid into 2-3 regions, never 25 cells.',
      'Redraw from memory before checking.',
    ],
    why:
        'Meaningful recoding plus reconstruction practice turns '
        'abstract patterns into durable traces.',
    source: 'Bjork (1994); Paivio dual-coding theory',
  ),
  '18-2': CoachContent(
    title: 'Color Codes',
    intro:
        'Give every color a meaning and palettes become messages. '
        'Color tags are fast, vivid and nearly free.',
    steps: [
      'Fix one meaning per color — never improvise.',
      'Picture the meaning interacting with the color.',
      'Recall meanings in sequence, not colors alone.',
    ],
    why:
        'Consistent color-meaning pairs form automatic codes, like a '
        'tiny personal Major system for the eyes.',
    source: 'Paivio (1979); Ericsson & Kintsch (1995)',
  ),
  '19-0': CoachContent(
    title: 'Scene Chains',
    intro:
        'Lonely images fade; chained images hold. Link every scene to '
        'the next with an action and films form themselves.',
    steps: [
      'Connect scene to scene with one physical action.',
      'Keep a single chain — branches snap.',
      'Replay the film start to finish, out loud.',
    ],
    why:
        'Narrative chaining adds order plus meaning to images. The '
        'action is the glue that preserves sequence.',
    source: 'Craik & Tulving (1975); elaborative-encoding literature',
  ),
  '19-1': CoachContent(
    title: 'Storyboards',
    intro:
        'Directors plan films frame by frame — and remember them. Ten '
        'ordered frames beat ten loose images every time.',
    steps: [
      'Sketch the frame order before filling details.',
      'Give each frame one key action plus one prop.',
      'Walk the frames in order for every recall.',
    ],
    why:
        'Ordered frames are loci for images: structure carries order '
        'so attention can carry content.',
    source: 'Wagner et al. (2021); Paivio (1979)',
  ),
  '19-2': CoachContent(
    title: 'Speed Sketches',
    intro:
        'Capture the essence of an image in five seconds. Fast visual '
        'encoding is a trainable skill — train it.',
    steps: [
      'Grab one key feature per image, fast.',
      'Exaggerate that feature immediately.',
      'Trust first captures: no second looks.',
    ],
    why:
        'Speed forces gist-plus-feature encoding, which is exactly '
        'what survives when time pressure hits.',
    source: 'Shepard (1967); Standing (1973)',
  ),
  '20-0': CoachContent(
    title: 'Gallery Walks',
    intro:
        'Thirty pictures need a building, not a pile. File them on '
        'gallery walls and take yourself on a guided tour.',
    steps: [
      'Assign each picture a fixed wall spot.',
      'Tour the gallery in the same order always.',
      'Narrate the tour out loud like a real guide.',
    ],
    why:
        'Spatial filing plus ordered tours is loci applied to images — '
        'the standard high-volume visual method.',
    source: 'Maguire et al. (2003); Krokos et al. VR study',
  ),
  '20-1': CoachContent(
    title: 'Set Review',
    intro:
        'Pictures fade without review. Space your gallery tours — one '
        'day, three days, a week — and the set lasts.',
    steps: [
      'Tour the full set on schedule, not when bored.',
      'Test yourself; do not just re-look.',
      'Log which pictures faded and re-encode them.',
    ],
    why:
        'Reviews rate spaced retrieval among the highest-utility '
        'learning strategies. Pictures obey it like everything else.',
    source: 'Dunlosky et al. (2013); Landauer & Bjork (1978)',
  ),
  '20-2': CoachContent(
    title: 'Blur Repair',
    intro:
        'Some images always fade first. Audit honestly, re-encode the '
        'faded ones sharper, and the archive stays crisp.',
    steps: [
      'Tour and mark every blurry picture.',
      'Re-encode each with a bigger, weirder version.',
      'Re-test the repaired ones the same day.',
    ],
    why:
        'Retrieval plus feedback roughly doubles the testing effect. '
        'Repair is feedback with a purpose.',
    source: 'Rowland (2014) meta-analysis',
  ),
  '21-0': CoachContent(
    title: 'Thirty-Image Sprint',
    intro:
        'Thirty images against the clock. Pace, system, trust — the '
        'same three things every speed final demands.',
    steps: [
      'Encode at a fixed pace: ten seconds per image.',
      'File each image on the gallery as you go.',
      'Recall in order once, commit, move on.',
    ],
    why:
        'Fixed-pace encoding prevents both rushing and dawdling. '
        'Timed image events are usually won on pacing.',
    source: 'Timed image-event formats',
  ),
  '21-1': CoachContent(
    title: 'Abstract Finals',
    intro:
        'Twenty abstract patterns, no mercy. Forced imagery plus labels '
        'cracks even the most meaningless set.',
    steps: [
      'Name every pattern instantly — labels anchor.',
      'Force one image per pattern, however absurd.',
      'Reconstruct from memory before checking.',
    ],
    why:
        'Effortful reconstruction under difficulty builds strong '
        'traces. Desirable difficulty, fully loaded.',
    source: 'Bjork (1994); Paivio & Desrochers (1979)',
  ),
  '21-2': CoachContent(
    title: 'Gallery Review',
    intro:
        'Fifty pictures, hostile twins, next-day recall. Pass this and '
        'you have finished the visual foundation on practiced pictures '
        '— honestly earned, and honestly kept only with review.',
    steps: [
      'Encode the full archive the evening before.',
      'Sleep, then recall blind the next morning.',
      'Tour in order; mark and repair any blur.',
    ],
    why:
        'Volume plus delay plus interference is the full review. '
        'Nothing about this set is improvised anymore.',
    source: 'Standing (1973); Dresler et al. (2017)',
  ),
  '22-0': CoachContent(
    title: 'Week Replay',
    intro:
        'A full week, day by day, backwards. Evening replay is the '
        'simplest durable-memory habit in the literature.',
    steps: [
      'Each evening, replay the day backwards first.',
      'Extend one more day back every evening.',
      'Write down the three hardest recalls.',
    ],
    why:
        'Backward replay forces effortful reconstruction, and daily '
        'repetition makes it automatic within weeks.',
    source: 'Gais, Lucas & Born (2006); Wilhelm et al. (2011)',
  ),
  '22-1': CoachContent(
    title: 'Timeline Pegs',
    intro:
        'Dates are slippery until they become places. Hang events on '
        'dated pegs and whole years stay ordered.',
    steps: [
      'Fix one peg per month, vivid and distinct.',
      'Hang each event on its peg with an image.',
      'Walk the timeline forward and back.',
    ],
    why:
        'Dated pegs combine loci order with calendar structure — two '
        'retrieval routes for every event.',
    source: 'Wagner et al. (2021); Craik & Tulving (1975)',
  ),
  '22-2': CoachContent(
    title: 'Future Rehearsal',
    intro:
        'Remembering to remember: tie every intention to a cue you '
        'will definitely meet. Prospective memory, trained.',
    steps: [
      'Pair each intention with one concrete cue.',
      'Picture yourself noticing the cue and acting.',
      'Review intentions each morning, score each night.',
    ],
    why:
        'In the studies, implementation intentions ("when X, I do Y") '
        'sharply raised follow-through — a well-replicated effect. '
        'Your results depend on practice.',
    source: 'Gollwitzer (1999) implementation intentions',
  ),
  '23-0': CoachContent(
    title: 'Detail Drill',
    intro:
        'Detectives notice everything because they practice noticing. '
        'Scan, close your eyes, list — then verify.',
    steps: [
      'Scan the scene slowly, section by section.',
      'Close your eyes and list ten details.',
      'Re-open and score: what did you miss?',
    ],
    why:
        'Encoding specificity: verified details get re-encoded richer, '
        'and the miss list teaches attention where to go.',
    source: 'Tulving & Thomson (1973); Craik et al. (1996)',
  ),
  '23-1': CoachContent(
    title: 'Conversation Replay',
    intro:
        'Who said what, in which words. Dialogue recall trains '
        'episodic binding: speaker plus content plus order.',
    steps: [
      'Tag each line with its speaker as you listen.',
      'Replay key quotes word-for-word right after.',
      'Reconstruct the full exchange the same evening.',
    ],
    why:
        'Binding speaker, content and order exercises episodic memory '
        'at full depth — shallow listening cannot fake it.',
    source: 'Tulving (1972) episodic memory; Craik & Tulving (1975)',
  ),
  '23-2': CoachContent(
    title: 'Order Keeper',
    intro:
        'Twelve steps in order, practiced until steady. Procedures are '
        'pure sequence — chaining plus loci keeps them ordered.',
    steps: [
      'Chain steps with actions, one link each.',
      'Anchor the chain on a short route for long lists.',
      'Recite forward twice before any test.',
    ],
    why:
        'Chained-plus-placed sequences resist swaps because order '
        'lives in two systems at once.',
    source: 'Craik & Tulving (1975); Wagner et al. (2021)',
  ),
  '24-0': CoachContent(
    title: 'Bedtime Protocol',
    intro:
        'Ten minutes before sleep beats an hour at noon. Review right, '
        'then let the night shift consolidate it.',
    steps: [
      'Walk one palace or replay the day before bed.',
      'Put hard items last — sleep keeps what is recent.',
      'No new cramming after the review.',
    ],
    why:
        'Sleep preferentially consolidates pre-sleep learning, and '
        'expecting a test gates what the night keeps.',
    source: 'Gais et al. (2006); Wilhelm et al. (2011)',
  ),
  '24-1': CoachContent(
    title: 'Morning Test',
    intro:
        'Recall at wake, before the phone. The morning test shows what '
        'the night actually kept — then you repair the rest.',
    steps: [
      'Recall last night material before any input.',
      'Score kept versus lost honestly.',
      'Relearn losses immediately, then move on.',
    ],
    why:
        'Morning retrieval both measures consolidation and strengthens '
        'it — testing builds memory, not just measures it.',
    source: 'Roediger & Karpicke (2006); Mazza et al. (2016)',
  ),
  '24-2': CoachContent(
    title: 'Weekly Review',
    intro:
        'Expanding gaps — a week, a month, a season — keep the archive '
        'alive forever with minutes of weekly work.',
    steps: [
      'Schedule reviews at expanding intervals.',
      'Test, do not re-read, at every review.',
      'Retire only material recalled perfectly twice.',
    ],
    why:
        'Expanding retrieval schedules were first shown decades ago '
        'and remain the durability standard.',
    source: 'Landauer & Bjork (1978); Dunlosky et al. (2013)',
  ),
  '25-0': CoachContent(
    title: 'Month Replay',
    intro:
        'Thirty days, day by day. Your journal habit plus timeline pegs '
        'make a full month replayable.',
    steps: [
      'Replay week by week, backwards within each.',
      'Use pegs for anchor dates inside the month.',
      'Log blank days and fill them from cues.',
    ],
    why:
        'Hierarchical recall (month to week to day) beats flat search: '
        'structure guides reconstruction.',
    source: 'Tulving (1972); Wilhelm et al. (2011)',
  ),
  '25-1': CoachContent(
    title: 'Milestone Exam',
    intro:
        'Twenty life milestones in dated order. Autobiographical '
        'recall at this level feels like time travel.',
    steps: [
      'List milestones, then date each one exactly.',
      'Attach one vivid scene per milestone.',
      'Recite in order, then by random date.',
    ],
    why:
        'Dated, scene-rich milestones form a self-reference scaffold — '
        'among the stickiest encodings studied.',
    source: 'Rogers, Kuiper & Kirker (1977) self-reference',
  ),
  '25-2': CoachContent(
    title: 'Life Journal Review',
    intro:
        'Practiced days in detail, on demand — plus quoted conversations '
        'and a full season in order. The episodic review.',
    steps: [
      'Take random dates and rebuild those days fully.',
      'Quote week-old conversations from memory.',
      'Walk a full season start to finish.',
    ],
    why:
        'Random-date recall shows the archive is indexed on practiced '
        'dates, not just rehearsed. Keep the daily replay going to '
        'keep it that way.',
    source: 'Tulving (1972); Gais et al. (2006)',
  ),
  '26-0': CoachContent(
    title: 'Crowd Faces',
    intro:
        'Fifteen faces, fifteen names, one round. Scale the 3-step '
        'method up: feature, image, interaction — fast.',
    steps: [
      'Spot one standout feature per face, fast.',
      'Stick the name-image onto the feature.',
      'Make each interaction physical and quick.',
    ],
    why:
        'The 3-step method scales: the same huge effect that fixes 2 '
        'names fixes 15 once feature-spotting is fast.',
    source: 'Morris et al. face-name mnemonic (d ≈ 2.4)',
  ),
  '26-1': CoachContent(
    title: 'Lookalikes',
    intro:
        'Similar faces swap names mercilessly. Build a feature matrix '
        'and every lookalike gets its own hook.',
    steps: [
      'Compare lookalikes side by side deliberately.',
      'Assign each one unique distinguishing feature.',
      'Test pairs until no swaps remain.',
    ],
    why:
        'Deliberate discrimination builds separate traces for similar '
        'faces — distinctiveness defeats interference.',
    source: 'Von Restorff (1933); Morris et al.',
  ),
  '26-2': CoachContent(
    title: 'Delayed Names',
    intro:
        'Names that survive an hour, then a night. Delayed recall is '
        'where party tricks become durable skill.',
    steps: [
      'Encode with the full 3-step, no shortcuts.',
      'Test after 5 minutes, an hour, then next day.',
      'Re-encode failures with wilder interactions.',
    ],
    why:
        'Expanding retrieval on names shows the classic spacing '
        'advantage: brief reviews buy months of retention.',
    source: 'Landauer & Bjork (1978); Beaton et al. (1995)',
  ),
  '27-0': CoachContent(
    title: 'Root Codes',
    intro:
        'Learn twenty roots and hundreds of words decode themselves. '
        'Etymology is the ultimate vocabulary leverage.',
    steps: [
      'Learn each root with one fixed image.',
      'Break new words into roots on sight.',
      'Rebuild meaning from roots before checking.',
    ],
    why:
        'Morphological awareness transfers to every new word in the '
        'family — one code unlocks dozens.',
    source: 'Craik & Tulving (1975); vocabulary-acquisition literature',
  ),
  '27-1': CoachContent(
    title: 'Fifty-Word Sprint',
    intro:
        'Fifty foreign words in fifteen minutes. Keyword chains at '
        'speed — the volume event of vocabulary.',
    steps: [
      'Fire one keyword image per word, no dawdling.',
      'Chain images into a running story.',
      'Test both directions immediately after.',
    ],
    why:
        'Speed plus keywords works because images form faster than '
        'rote traces — volume rewards the imaged.',
    source: 'Atkinson & Raugh (1975); Beaton et al. (1995)',
  ),
  '27-2': CoachContent(
    title: 'Two-Way Chains',
    intro:
        'Knowing a word one way is half-knowing it. Bidirectional '
        'recall closes the loop — both directions practiced.',
    steps: [
      'Test foreign-to-native first, then reverse.',
      'Drill the weak direction twice as much.',
      'Shuffle order: no chain-order crutches.',
    ],
    why:
        'Bidirectional testing with feedback builds symmetric links. '
        'Feedback roughly doubles the gain.',
    source: 'Rowland (2014) meta-analysis',
  ),
  '28-0': CoachContent(
    title: 'Fact Palaces',
    intro:
        'Thirty facts in a palace beats thirty facts in a pile. '
        'Structure files knowledge where you can find it.',
    steps: [
      'File one fact per station, image-rich.',
      'Group related facts in neighboring rooms.',
      'Tour for recall; jump for spot-checks.',
    ],
    why:
        'Organized encoding plus loci gives facts both meaning and '
        'address — recall by tour or by topic.',
    source: 'Maguire et al. (2003); Chi et al. (1994)',
  ),
  '28-1': CoachContent(
    title: 'Speech Skeletons',
    intro:
        'A fifteen-minute talk from a loci skeleton. Placed points '
        'hold your talk in order — after rehearsal.',
    steps: [
      'Place one talk point per station.',
      'Picture each point as a scene, not words.',
      'Rehearse by walking, never by reading.',
    ],
    why:
        'Loci-based speeches resist blanking: the next station usually '
        'cues the next point. Orators knew this.',
    source: 'Classical rhetoric (method of loci); Wagner et al. (2021)',
  ),
  '28-2': CoachContent(
    title: 'Number Facts',
    intro:
        'Dates, constants, figures — steady and exact on practiced '
        'sets. Peg numbers to images and quantities stop slipping.',
    steps: [
      'Convert each figure with your Major codes.',
      'Stick the image onto the fact it belongs to.',
      'Drill exact recall: close does not count.',
    ],
    why:
        'Coded numbers plus fact-images bind quantity to meaning. '
        'Precision comes from the code, not from effort.',
    source: 'Major system tradition; Ericsson & Kintsch (1995)',
  ),
  '29-0': CoachContent(
    title: 'Name Sprint',
    intro:
        'Twenty names in five minutes — long distance. Steady '
        '3-step rhythm, no panic, no skips.',
    steps: [
      'Work faces in order at a fixed pace.',
      'Feature, image, interaction — every single face.',
      'Write the sheet from memory once, commit.',
    ],
    why:
        'Fixed-pace 3-step runs are how timed name events are usually '
        'won. Systems beat nerves.',
    source: 'Timed name-event formats; Morris et al.',
  ),
  '29-1': CoachContent(
    title: 'Word Blitz',
    intro:
        'Fifty words in fifteen minutes, word-for-word. The long '
        'round — everything you learned, at speed.',
    steps: [
      'Keyword every word on first sight.',
      'Chain as you go; review the chain twice.',
      'Recall in order, careful wording.',
    ],
    why:
        'Long word rounds reward automatic keywords plus '
        'chained order. Both are practiced now.',
    source: 'Timed word-event formats; Atkinson & Raugh (1975)',
  ),
  '29-2': CoachContent(
    title: 'Final Review',
    intro:
        'Names plus words, delayed a day, under noise. Pass this and '
        'you have finished the semantic foundation on trained sheets — '
        'crown it with a retest next week, on new sheets.',
    steps: [
      'Encode mixed sheets the evening before.',
      'Recall blind the next day, in noise.',
      'Repair every miss, then re-test once.',
    ],
    why:
        'Mixed, delayed, noisy recall is the full semantic review. '
        'Passing it means the method works for you on trained '
        'material — new names always need fresh encoding.',
    source: 'Dresler et al. (2017); Dunlosky et al. (2013)',
  ),
  '30-0': CoachContent(
    title: 'Live Voices',
    intro:
        'Same attention gate, real people. Three to five names at actual '
        'meetings, with spelling asked and greetings repeated back.',
    steps: [
      'Full focus on each introduction; no inner rehearsal.',
      'Repeat each name back in your greeting.',
      'Next day, write the names from memory and check.',
    ],
    why:
        'Real introductions carry noise, nerves, and speed — the exact '
        'conditions the lab drills simplify. Practice meets them here.',
    source: 'Craik et al. (1996)',
  ),
  '30-1': CoachContent(
    title: 'Own Errands by Ear',
    intro:
        'Your real errand list, heard once and said back aloud. Rhythm '
        'groups it; sealed paper checks it at the till.',
    steps: [
      'Have someone read your errands once; say them back aloud.',
      'Group in rhythm and replay once before leaving.',
      'Recall at the till before opening the sealed list.',
    ],
    why:
        'Saying lists aloud plus rhythmic grouping holds heard items. '
        'The sealed list turns shopping into scored recall.',
    source: 'MacLeod et al. (2010); Purnell-Webb & Speelman (2008)',
  ),
  '30-2': CoachContent(
    title: 'Evening Sound Log',
    intro:
        'Three evenings of replaying the names and numbers you heard '
        'that day. Short sessions, written hard recalls, sleep after.',
    steps: [
      'Replay the day sounds in order before sleep.',
      'Say each name and number once, aloud if you can.',
      'Log the three hardest recalls each night.',
    ],
    why:
        'Evening review plus sleep keeps more than morning study, and '
        'the log shows which sounds need a second pass.',
    source: 'Gais, Lucas & Born (2006)',
  ),
  '31-0': CoachContent(
    title: 'Numbers You Dial',
    intro:
        'Two phone numbers you actually use, chunked into images and '
        'dialed from memory for a week. Real digits, real payoff.',
    steps: [
      'Chunk each number in threes; image each chunk.',
      'Link chunks into one scene per number.',
      'Recall each morning before checking the contacts.',
    ],
    why:
        'Chunked images turn long strings into short scenes. Daily '
        'morning recall spaces the repetitions for free.',
    source: 'Miller (1956); Ericsson, Chase & Faloon (1980)',
  ),
  '31-1': CoachContent(
    title: 'Sealed-List Shopping',
    intro:
        'Four then eight items, sealed in your pocket, recalled at the '
        'till. The paper list is the answer key, not a crutch.',
    steps: [
      'Image the list in groups of three as short scenes.',
      'Walk the scenes once before entering the shop.',
      'Recall everything at the till, then open the paper.',
    ],
    why:
        'Retrieval at the till — not re-reading in the aisle — builds '
        'the recall path you will use next time.',
    source: 'Cowan (2001); Roediger & Karpicke (2006)',
  ),
  '31-2': CoachContent(
    title: 'Dates That Matter',
    intro:
        'Five birthdays or anniversaries fixed with face-linked images, '
        'quizzed by a friend in random order.',
    steps: [
      'Image each date with its person photo or face cue.',
      'Recall all five each evening for a week.',
      'Ask someone to quiz you shuffled; fix misses same night.',
    ],
    why:
        'Face-linked date images reuse the paired-associate path on '
        'material you will actually be asked about.',
    source: 'Ericsson & Kintsch (1995)',
  ),
  '32-0': CoachContent(
    title: 'Your Home Route',
    intro:
        'Ten stations in your real home, door to bedroom, walked blind. '
        'This route becomes your default palace for own lists.',
    steps: [
      'Write 10 stations in strict order on paper.',
      'Walk twice naming stations, no items yet.',
      'Place 10 words, one moving scene each, and re-walk.',
    ],
    why:
        'A known route in fixed order removes the order problem: the '
        'walk carries the sequence, images carry the items.',
    source: 'Dresler et al. (2017)',
  ),
  '32-1': CoachContent(
    title: 'Your Street Route',
    intro:
        'Fifteen distinct outdoor spots you pass often. Sharp spots '
        'only — similar stations blur into each other.',
    steps: [
      'Walk and pick 15 sharp, distinct spots in order.',
      'Name each in two words; write the full order.',
      'Place 15 study or work items along the walk.',
    ],
    why:
        'Distinct loci cut interference between items. Outdoor routes '
        'stay stable for years once fixed.',
    source: 'Maguire et al. (2003)',
  ),
  '32-2': CoachContent(
    title: 'Two Routes, Twenty Items',
    intro:
        'A real 20-item list of yours split across both routes, walked '
        'in the evening and recalled in writing next morning.',
    steps: [
      'Split 10 home plus 10 street; one scene per station.',
      'Evening walk of both routes before sleep.',
      'Morning written recall; re-walk only the misses.',
    ],
    why:
        'Evening encoding plus morning recall uses sleep between reps. '
        'Teaching the walk once more locks the order.',
    source: 'Wagner et al. (2021); Mazza et al. (2016)',
  ),
  '33-0': CoachContent(
    title: 'Work Tasks Pictured',
    intro:
        'Six abstract tasks turned into big moving pictures on room '
        'corners, recalled at noon against your list.',
    steps: [
      'Picture each abstract task as one concrete scene.',
      'Make it big, bright, and moving; attach to a corner.',
      'At noon, list all six from the pictures, then check.',
    ],
    why:
        'Concrete pictures give abstract tasks a second code. Noon '
        'recall tests the pictures, not the paper.',
    source: 'Paivio dual-coding; Shepard (1967)',
  ),
  '33-1': CoachContent(
    title: 'Photo Holds Overnight',
    intro:
        'One busy photo studied once, six details recalled next day. '
        'Exaggerated tags keep similar details apart.',
    steps: [
      'Name six details aloud in one viewing.',
      'Exaggerate one feature per detail on purpose.',
      'Rebuild the photo from memory next day before checking.',
    ],
    why:
        'Overnight detail recall trains durable picture traces. Fresh '
        'photos each round keep the test honest.',
    source: 'Standing (1973)',
  ),
  '33-2': CoachContent(
    title: 'Meeting Strips',
    intro:
        'Five meeting points imaged as said and linked into one strip, '
        'replayed next morning against the minutes.',
    steps: [
      'Image each point the moment you hear it.',
      'Link 1→2→3→4→5 with small actions.',
      'Replay the strip before leaving, again next morning.',
    ],
    why:
        'Linked images carry both items and order out of meetings. The '
        'minutes are the answer key.',
    source: 'Von Restorff (1933)',
  ),
  '34-0': CoachContent(
    title: 'Study Chains',
    intro:
        'Ten study terms as one silly adventure, retold aloud the next '
        'day. One chain only — branches snap.',
    steps: [
      'Chain 1→2→3 in order with actions, never branches.',
      'Retell the story aloud right after building it.',
      'Retell next morning; note where the chain broke.',
    ],
    why:
        'Narrative chaining adds order plus meaning to bare terms. The '
        'break point shows which link needs a stronger scene.',
    source: 'Craik & Tulving (1975)',
  ),
  '34-1': CoachContent(
    title: 'Seven Nights Logged',
    intro:
        'Seven evenings of backward day replay with a short log. Day 8 '
        'recalls day 1 from cue words only.',
    steps: [
      'Replay each day backwards, scene by scene.',
      'Pause on faces, numbers, and exact words.',
      'Log the three hardest recalls every night.',
    ],
    why:
        'Expecting the nightly replay changes what the day encodes. '
        'The log turns evenings into spaced retrieval.',
    source: 'Wilhelm et al. (2011); Gais et al. (2006)',
  ),
  '34-2': CoachContent(
    title: 'Retold Aloud',
    intro:
        'One article read once like a short movie, retold aloud same '
        'evening and again next day. Listener marks the skips.',
    steps: [
      'Read once, no re-reading, scenes playing as you go.',
      'Retell who did what with numbers, aloud.',
      'Next-day retell; compare which skips stayed skipped.',
    ],
    why:
        'Same-evening plus next-day retells beat re-reading by a wide '
        'margin, and the gap grows with delay.',
    source: 'Roediger & Karpicke (2006); Rowland (2014)',
  ),
  '35-0': CoachContent(
    title: 'Names at Events',
    intro:
        'Five real names at one gathering with the 3-step method, two '
        'hellos by name later, full list next day.',
    steps: [
      'Feature first, hook image second, interaction third.',
      'Greet two people by name before leaving.',
      'List all five from the features next day.',
    ],
    why:
        'Real events add the pressure app sheets skip. Greeting by name '
        'is the scored rep.',
    source: 'Morris et al. face-name mnemonic',
  ),
  '35-1': CoachContent(
    title: 'Two Weeks of Words',
    intro:
        'Twenty words you actually need, two a day with keyword scenes, '
        'tested both directions daily for two weeks.',
    steps: [
      'Two new words daily, each with one keyword scene.',
      'Test foreign→meaning and back every day with feedback.',
      'Review misses same evening and next morning.',
    ],
    why:
        'Daily two-way testing with feedback keeps keyword pairs alive. '
        'Day-14 shuffled test shows what held.',
    source: 'Atkinson & Raugh (1975); Beaton et al. (1995)',
  ),
  '35-2': CoachContent(
    title: 'Talks and Facts Out',
    intro:
        'A real 5-point talk from a loci skeleton plus 10 own facts in '
        'rooms. Listener repeats the points; stations get called.',
    steps: [
      'Place talk points on stations; walk twice the night before.',
      'Deliver with no notes; note where you paused.',
      'File 10 own facts; answer them at random stations.',
    ],
    why:
        'Talks and facts share one skill: ordered points on a walk. '
        'Listener checks keep the scoring honest.',
    source: 'Dresler et al. (2017); Chi et al. (1994)',
  ),
};

CoachContent coachFor(int chapter, int section, [String locale = 'en']) {
  if (locale == 'hu') {
    return coachContentHu['$chapter-$section'] ?? _coachFallbackHu;
  }
  return coachContent['$chapter-$section'] ?? _coachFallbackEn;
}

const _coachFallbackEn = CoachContent(
  title: 'Memory Drill',
  intro:
      'Encode with full attention, then pull it back from memory. '
      'Retrieval is the workout.',
  steps: [
    'Study the items once, with full focus.',
    'Hide them and recall everything.',
    'Check, fix errors, recall once more.',
  ],
  why:
      'Testing beats re-studying, and feedback roughly doubles the '
      'gain.',
  source: 'Rowland (2014) meta-analysis',
);

const _coachFallbackHu = CoachContent(
  title: 'Memóriagyakorlat',
  intro:
      'Véss be teljes figyelemmel, aztán húzd vissza emlékezetből. '
      'A felidézés az edzés.',
  steps: [
    'Tanulmányozd egyszer a tételeket, teljes fókusszal.',
    'Rejtsd el őket, és idézz fel mindent.',
    'Ellenőrizz, javítsd a hibákat, idézd fel még egyszer.',
  ],
  why:
      'A tesztelés veri az újratanulást, a visszajelzés pedig nagyjából '
      'megduplázza a nyereséget.',
  source: 'Rowland (2014) meta-analysis',
);
