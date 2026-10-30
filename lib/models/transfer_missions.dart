library;

import '../l10n/app_localizations.dart';

class TransferMission {
  final String id;

  final int track;

  final String title;

  final String briefing;

  final List<String> steps;

  final String selfCheck;

  final String source;

  const TransferMission({
    required this.id,
    required this.track,
    required this.title,
    required this.briefing,
    required this.steps,
    required this.selfCheck,
    required this.source,
  });

  String titleIn([String locale = 'en']) =>
      trFor(locale, 'mission_${id}_title');

  String briefingIn([String locale = 'en']) =>
      trFor(locale, 'mission_${id}_briefing');

  List<String> stepsIn([String locale = 'en']) => <String>[
    for (var i = 0; i < steps.length; i++)
      trFor(locale, 'mission_${id}_step$i'),
  ];

  String selfCheckIn([String locale = 'en']) =>
      trFor(locale, 'mission_${id}_selfcheck');
}

const transferMissions = <TransferMission>[
  TransferMission(
    id: 'sensory-names-3',
    track: 0,
    title: 'Three live introductions',
    briefing:
        'Use the attention gate on three real introductions this week: '
        'full focus, no inner rehearsal, name repeated back at once.',
    steps: [
      'Stop rehearsing your own reply the moment they speak.',
      'Repeat each name back in your greeting sentence.',
      'Ask for the spelling once — it buys a second exposure.',
    ],
    selfCheck:
        'Next morning, write down all three names from memory and check.',
    source: 'Craik et al. (1996)',
  ),
  TransferMission(
    id: 'sensory-noisy-cafe',
    track: 0,
    title: 'Noisy-room recall',
    briefing:
        'Ask a friend to read 5 words aloud in a noisy place, then recall '
        'them in order. Same filter skill as the noisy-field drills.',
    steps: [
      'Lock onto the reader voice and let the rest blur.',
      'Replay the list silently once before answering.',
      'Recall in order, then ask to be corrected.',
    ],
    selfCheck: 'Repeat with 5 fresh words in a quiet room and compare.',
    source: 'Naveh-Benjamin et al. (2005)',
  ),
  TransferMission(
    id: 'sensory-errands-echo',
    track: 0,
    title: 'Errands by ear',
    briefing:
        'Have someone read your next errand list once, say it back aloud, '
        'then run the errands with no written list.',
    steps: [
      'Say the errands aloud once, grouped in rhythm.',
      'Replay them once more from memory before leaving.',
      'At the door, recall the full list a third time.',
    ],
    selfCheck: 'Count how many errands came back right; note which faded.',
    source: 'MacLeod et al. (2010); Purnell-Webb & Speelman (2008)',
  ),
  TransferMission(
    id: 'sensory-evening-replay',
    track: 0,
    title: 'Evening sound replay',
    briefing:
        'Each evening for 3 days, replay the names and numbers you heard '
        'that day before sleep, then sleep on it.',
    steps: [
      'Sit quiet and replay the day sounds in order.',
      'Pause on each name and number; say it once.',
      'Write the three hardest recalls in a notebook.',
    ],
    selfCheck: 'On day 4, recall day 1 sounds again and check the notes.',
    source: 'Gais, Lucas & Born (2006)',
  ),
  TransferMission(
    id: 'working-phones-2',
    track: 1,
    title: 'Two real phone numbers',
    briefing:
        'Learn two phone numbers you actually dial by chunking them into '
        'images — no contacts lookup for a week.',
    steps: [
      'Split each number into groups of 3 and image each group.',
      'Link the images into one short scene per number.',
      'Recall both numbers each morning before checking.',
    ],
    selfCheck: 'Dial both from memory on day 7; note errors by chunk.',
    source: 'Miller (1956); Ericsson, Chase & Faloon (1980)',
  ),
  TransferMission(
    id: 'working-shopping-8',
    track: 1,
    title: 'Shopping without paper',
    briefing:
        'Encode your next 8-item shopping list as chunks with images, '
        'then shop with the list sealed in your pocket.',
    steps: [
      'Group items in threes; image each group as one scene.',
      'Walk the scenes once before entering the shop.',
      'Recall at the till before opening the paper list.',
    ],
    selfCheck: 'Compare recalled items with the paper list; fix misses.',
    source: 'Cowan (2001)',
  ),
  TransferMission(
    id: 'working-dates-5',
    track: 1,
    title: 'Five dates that matter',
    briefing:
        'Fix five birthdays or anniversaries with chunked images so you '
        'can say each date when you see the person name.',
    steps: [
      'Turn each date into one image (day + month together).',
      'Stick the image onto a photo or face cue.',
      'Recall all five each evening for a week.',
    ],
    selfCheck: 'Ask someone to quiz you on all five in random order.',
    source: 'Ericsson & Kintsch (1995)',
  ),
  TransferMission(
    id: 'working-backwards-day',
    track: 1,
    title: 'Backwards errand check',
    briefing:
        'After any 4-stop errand run, recite the stops backwards from '
        'memory before driving home.',
    steps: [
      'Hold all stops in mind before reversing.',
      'Work backwards one stop at a time, aloud.',
      'If one drops, restart from the last stop.',
    ],
    selfCheck: 'Do it on three separate runs; track clean runs.',
    source: 'Baddeley & Hitch (1974)',
  ),
  TransferMission(
    id: 'spatial-home-10',
    track: 2,
    title: 'Your home route of 10',
    briefing:
        'Walk your real home and fix 10 stations in strict order, door to '
        'bedroom. This route becomes your default palace.',
    steps: [
      'Write the 10 stations in order on paper.',
      'Walk the route twice with no items, naming each station.',
      'Place 10 words from today list, one scene each.',
    ],
    selfCheck: 'Tomorrow, walk the route blind and recall all 10 words.',
    source: 'Dresler et al. (2017)',
  ),
  TransferMission(
    id: 'spatial-street-15',
    track: 2,
    title: 'Your street route of 15',
    briefing:
        'Fix a 15-station outdoor route you walk often. Distinct spots '
        'only — no two benches, no vague corners.',
    steps: [
      'Walk the street and pick 15 sharp, distinct spots.',
      'Name each spot in two words and write the order.',
      'Place 15 study or work items along the route.',
    ],
    selfCheck: 'Recall the 15 items forward next morning, then re-walk.',
    source: 'Maguire et al. (2003)',
  ),
  TransferMission(
    id: 'spatial-own-list-20',
    track: 2,
    title: 'Twenty items that are yours',
    briefing:
        'Put a real 20-item list of yours (study, work, packing) into '
        'your two routes and recall it the next day.',
    steps: [
      'Split the list: 10 on the home route, 10 on the street.',
      'Give each station one moving, interacting scene.',
      'Evening walk plus morning walk before checking.',
    ],
    selfCheck: 'Write the 20 from memory; re-walk only the missed ones.',
    source: 'Wagner et al. (2021)',
  ),
  TransferMission(
    id: 'spatial-teach-once',
    track: 2,
    title: 'Teach the walk once',
    briefing:
        'Teach your home route to one person and walk them through 5 '
        'items. Teaching forces clean order and sharp stations.',
    steps: [
      'Show your 10 stations in order on paper.',
      'Place 5 items together, one scene each.',
      'Let them walk it back while you stay silent.',
    ],
    selfCheck: 'A day later, recall those same 5 items yourself.',
    source: 'Rowland (2014)',
  ),
  TransferMission(
    id: 'visual-grocery-images',
    track: 3,
    title: 'Image your abstract tasks',
    briefing:
        'Turn 6 abstract work items (calls, forms, deadlines) into big, '
        'moving pictures and recall them at noon.',
    steps: [
      'Give each abstract item one concrete picture.',
      'Make each picture big, bright, and moving.',
      'Attach each picture to a room corner.',
    ],
    selfCheck: 'At noon, list all 6 from the pictures; check your list.',
    source: 'Paivio dual-coding; Shepard (1967)',
  ),
  TransferMission(
    id: 'visual-photo-next-day',
    track: 3,
    title: 'Photo details next day',
    briefing:
        'Study one busy photo for a minute, then recall 6 details the '
        'next day without looking again.',
    steps: [
      'Name 6 details aloud while looking once.',
      'Exaggerate one feature per detail.',
      'Rebuild the photo from memory before checking.',
    ],
    selfCheck: 'Score details right out of 6; repeat with a fresh photo.',
    source: 'Standing (1973)',
  ),
  TransferMission(
    id: 'visual-meeting-5',
    track: 3,
    title: 'Five meeting points pictured',
    briefing:
        'During your next meeting, image each of 5 key points as it is '
        'said and replay the strip right after.',
    steps: [
      'Picture each point the moment you hear it.',
      'Link pictures 1→2→3→4→5 with small actions.',
      'Replay the strip once before leaving the room.',
    ],
    selfCheck: 'Next morning, replay the strip and check the minutes.',
    source: 'Von Restorff (1933)',
  ),
  TransferMission(
    id: 'visual-study-pages',
    track: 3,
    title: 'Study pages as scenes',
    briefing:
        'Turn one study page into 4 linked scenes and recall the page '
        'structure the next day from the scenes.',
    steps: [
      'One scene per paragraph; keep the page order.',
      'Interact the scenes with each other.',
      'Recall scenes first, then translate back to facts.',
    ],
    selfCheck: 'Explain the page aloud from memory; check gaps.',
    source: 'Paivio & Desrochers (1979)',
  ),
  TransferMission(
    id: 'episodic-7-day-journal',
    track: 4,
    title: 'Seven evenings of replay',
    briefing:
        'Replay each day backwards for 7 evenings and log the three '
        'hardest recalls. Expecting the replay is part of the effect.',
    steps: [
      'Each evening, replay the day scene by scene, backwards.',
      'Pause on faces, numbers, and exact words.',
      'Write the three hardest recalls each night.',
    ],
    selfCheck: 'On day 8, recall day 1 from the log cues only.',
    source: 'Wilhelm et al. (2011); Gais et al. (2006)',
  ),
  TransferMission(
    id: 'episodic-story-study',
    track: 4,
    title: 'Study list as one story',
    briefing:
        'Chain 10 study terms into one silly adventure and retell it '
        'start to finish the next day.',
    steps: [
      'Link term 1→2 with an action, then 2→3, one chain.',
      'Retell the story aloud right after building it.',
      'Retell again next morning before checking.',
    ],
    selfCheck: 'List the 10 terms from the story; note broken links.',
    source: 'Craik & Tulving (1975)',
  ),
  TransferMission(
    id: 'episodic-walkback-week',
    track: 4,
    title: 'Walk back the week',
    briefing:
        'On Sunday, walk one palace from Monday items plus replay the '
        'week day by day, then sleep and re-recall Monday.',
    steps: [
      'Walk the Monday palace once before bed.',
      'Replay Tuesday→Sunday as short scenes.',
      'Recall the Monday walk first thing in the morning.',
    ],
    selfCheck: 'Count Monday items held overnight vs. re-walked ones.',
    source: 'Mazza et al. (2016)',
  ),
  TransferMission(
    id: 'episodic-retell-once',
    track: 4,
    title: 'Retell one story aloud',
    briefing:
        'Read one short article once, then retell it aloud to someone '
        'the same evening from memory only.',
    steps: [
      'Read once like a short movie, no re-reading.',
      'Retell who did what, with numbers, aloud.',
      'Ask your listener what you skipped.',
    ],
    selfCheck: 'Retell again next day; compare skipped parts.',
    source: 'Roediger & Karpicke (2006)',
  ),
  TransferMission(
    id: 'semantic-live-names-5',
    track: 5,
    title: 'Five names at one event',
    briefing:
        'At your next gathering, encode 5 real names with the 3-step '
        'method and greet two of them by name later.',
    steps: [
      'Spot one standout feature per face first.',
      'Turn each surname into a picture hook.',
      'Stick the hook onto the feature with action.',
    ],
    selfCheck: 'Next day, list all 5 names from the features.',
    source: 'Morris et al. face-name mnemonic',
  ),
  TransferMission(
    id: 'semantic-foreign-20',
    track: 5,
    title: 'Twenty words in two weeks',
    briefing:
        'Learn 20 real foreign words you need with keyword images, 2 a '
        'day, testing both directions with feedback.',
    steps: [
      'Two new words a day, each with a keyword scene.',
      'Test foreign→meaning and meaning→foreign daily.',
      'Review misses the same evening and next morning.',
    ],
    selfCheck: 'On day 14, test all 20 shuffled; log held ones.',
    source: 'Atkinson & Raugh (1975); Beaton et al. (1995)',
  ),
  TransferMission(
    id: 'semantic-talk-5',
    track: 5,
    title: 'Five-point talk, no notes',
    briefing:
        'Give a real 5-point update or toast from a loci skeleton, with '
        'no notes in hand.',
    steps: [
      'Place 5 points on 5 stations in order.',
      'Walk the skeleton twice the evening before.',
      'Deliver from the walk; note where you paused.',
    ],
    selfCheck: 'Ask one listener to repeat your 5 points back.',
    source: 'Dresler et al. (2017)',
  ),
  TransferMission(
    id: 'semantic-facts-own-15',
    track: 5,
    title: 'Fifteen facts of yours',
    briefing:
        'File 15 facts from your own study or work into one palace room '
        'set and recall any fact by its station.',
    steps: [
      'Ask why for each fact and link it to two known things.',
      'Place facts in order, one scene per station.',
      'Explain each fact aloud in your own words.',
    ],
    selfCheck: 'Have someone call stations at random; answer each.',
    source: 'Craik & Tulving (1975); Chi et al. (1994)',
  ),
];

List<TransferMission> missionsForTrack(int track) {
  final t = track.clamp(0, 5);
  return [for (final m in transferMissions) if (m.track == t) m];
}

TransferMission? missionById(String id) {
  for (final m in transferMissions) {
    if (m.id == id) return m;
  }
  return null;
}
