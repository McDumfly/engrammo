import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show ImageFilter, MaskFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:hugeicons/hugeicons.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../models/fsrs_card.dart';
import '../models/meta_image.dart';
import '../models/room_palace.dart';
import '../models/sam_mask.dart'
    show SamMaskRun, decodeSamMaskToken, parseSamMaskToken, samMaskRuns;
import '../services/active_palace_store.dart';
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../services/room_photo.dart';
import '../theme/app_colors.dart' show blue, coral, orange, success, teal;
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../utils/test_mode.dart';
import '../widgets/ai_image.dart';
import '../widgets/app_buttons.dart'
    show EngramBackButton, EngramButton, EngramButtonVariant;
import '../widgets/app_kit.dart';
import '../widgets/room_preview_art.dart';
import 'benchmark.dart' show BenchmarkStore, MaskedPicture, buildSamOutline;

/// Station colour cycle, matching the highlight fills.
Color _stationColor(int i) {
  const cycle = [teal, blue, orange, coral];
  return cycle[i % cycle.length];
}

/// Palace list row title: the first two memorised items plus how many
/// more, e.g. "apple · hammer +3". Without items it falls back to the
/// station names.
String _listTitle(RoomPalace p) {
  final items = p.items;
  if (items.isEmpty) return roomPalaceName(p);
  if (items.length == 1) return items[0];
  if (items.length == 2) return '${items[0]} · ${items[1]}';
  return tr('room_list_title', {
    'a': items[0],
    'b': items[1],
    'n': '${items.length - 2}',
  });
}

/// Stagger curve for [_RoomPalacePageState._enter]: holds 0 for the
/// first [start] fraction, then easeOutCubic. Gives a per-index delay
/// with a plain TweenAnimationBuilder (no timers, test-safe).
class _StaggerCurve extends Curve {
  final double start;
  const _StaggerCurve(this.start);

  @override
  double transform(double t) {
    if (t <= start) return 0;
    return Curves.easeOutCubic.transform((t - start) / (1 - start));
  }
}

class RoomPalacePage extends StatefulWidget {
  /// null = build a new palace; otherwise open that saved palace in review.
  final String? reviewId;
  const RoomPalacePage({super.key, this.reviewId});

  @override
  State<RoomPalacePage> createState() => _RoomPalacePageState();
}

enum _Step { list, capture, scanning, items, baseline, encode, recall, result }

class _RoomPalacePageState extends State<RoomPalacePage> {
  _Step _step = _Step.capture;
  int _token = 0;
  bool _ready = false;

  List<RoomPalace> _palaces = [];
  String? _activeId;

  // Scan state.
  String _photo = '';
  String _stage = 'image';
  int _samDone = 0;
  int _samTotal = 0;
  List<String> _stations = [];
  List<List<double>> _boxes = [];
  List<String> _masks = [];
  List<String> _scanLabels = [];
  List<List<double>> _scanBoxes = [];
  bool _live = false;
  bool _imageFailed = false;
  bool _sample = false;
  int _coverVersion = 0;

  // Items + encode state.
  final _itemsCtrl = TextEditingController();
  bool _building = false;
  RoomPalace? _palace;
  int _focus = 0;
  final Map<int, String> _dreams = {};
  final Map<int, String> _storedDreams = {};

  /// Stations whose dream reveal already played (haptic included).
  /// Cleared whenever a new palace build starts.
  final Set<int> _revealedDreams = {};
  Future<void> _persistChain = Future.value();

  // Recall state.
  int _cue = 0;

  /// Correct-answer ripple: station centre (photo fractions) and a
  /// generation counter that replays the 500 ms ring. Zero = no ripple.
  Offset _rippleAt = const Offset(0.5, 0.5);
  int _rippleKey = 0;
  int _correct = 0;
  Set<int> _revealed = {};
  Set<int> _correctIdx = {};
  final _guessCtrl = TextEditingController();
  final _guessFocus = FocusNode();
  String _feedback = '';
  bool _feedbackGood = false;
  bool _awaitNext = false;
  bool _judging = false;
  bool _blind = false;
  bool _rescheduled = false;
  DateTime? _nextDue;
  String? _popDream;
  Timer? _popTimer;
  double _popOpacity = 1;

  // Baseline (no-palace) probe state: same list, recalled today.
  int? _baselineCorrect;
  List<String> _baselineItems = [];
  int _baselineLeft = 0;
  bool _baselineRecall = false;
  final _baselineCtrl = TextEditingController();
  Timer? _baselineTimer;

  @override
  void initState() {
    super.initState();
    _itemsCtrl.addListener(_onItemsChanged);
    final reviewId = widget.reviewId;
    if (reviewId != null) {
      _openReview(reviewId);
    } else {
      _loadList();
    }
  }

  void _onItemsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _token++;
    _popTimer?.cancel();
    _baselineTimer?.cancel();
    _itemsCtrl.removeListener(_onItemsChanged);
    _itemsCtrl.dispose();
    _guessCtrl.dispose();
    _guessFocus.dispose();
    _baselineCtrl.dispose();
    super.dispose();
  }

  /// One staggered entrance helper: fade + slide-up 12px, 260ms,
  /// 60ms stagger per index, replayed per step via the key.
  Widget _enter(int i, Widget child) {
    final total = 260 + 60 * i;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${_step.name}-$i'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: _StaggerCurve(60 * i / total),
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: c),
      ),
      child: child,
    );
  }

  Future<void> _loadList() async {
    final token = _token;
    final list = await MemoryStore.loadRoomPalaces();
    final activeId = await ActivePalaceStore.loadId();
    if (!mounted || token != _token) return;
    setState(() {
      _palaces = list;
      _activeId = activeId;
      _ready = true;
      _step = list.isEmpty ? _Step.capture : _Step.list;
    });
  }

  Future<void> _openReview(String id) async {
    final token = _token;
    final list = await MemoryStore.loadRoomPalaces();
    if (!mounted || token != _token) return;
    RoomPalace? found;
    for (final p in list) {
      if (p.id == id) found = p;
    }
    if (found == null) {
      setState(() {
        _palaces = list;
        _ready = true;
        _step = list.isEmpty ? _Step.capture : _Step.list;
      });
      return;
    }
    final foundPalace = found;
    setState(() {
      _palaces = list;
      _ready = true;
      _photo = foundPalace.imageRef;
      _sample = foundPalace.sample;
      _baselineCorrect = null;
      _stations = foundPalace.stations;
      _boxes = foundPalace.boxes;
      _masks = foundPalace.masks;
      _live = foundPalace.live;
      _imageFailed = false;
      _coverVersion++;
      _palace = foundPalace;
      _blind = false;
      _resetRecall();
      for (var i = 0; i < foundPalace.dreams.length; i++) {
        if (foundPalace.dreams[i].isNotEmpty) {
          _dreams[i] = foundPalace.dreams[i];
          // Stored scenes are not new arrivals: no replay, no haptic.
          _revealedDreams.add(i);
        }
      }
      _rescheduled = false;
      _nextDue = null;
      _step = _Step.recall;
    });
  }

  void _resetRecall() {
    _cue = 0;
    _rippleKey = 0;
    _correct = 0;
    _revealed = {};
    _correctIdx = {};
    _feedback = '';
    _feedbackGood = false;
    _awaitNext = false;
    _popTimer?.cancel();
    _popDream = null;
    _popOpacity = 1;
    _guessCtrl.clear();
  }

  void _snack(String text) {
    showAppToast(context, text);
  }

  Future<void> _pick(ImageSource source) async {
    if (!await MetaAIService.cloudConsent()) {
      if (!mounted) return;
      _snack(tr('room_consent_off'));
      return;
    }
    final token = ++_token;
    try {
      final url = await pickRoomPhoto(source);
      if (!mounted || token != _token) return;
      if (url == null) return; // Cancelled: stay on this step.
      setState(() {
        _photo = url;
        _sample = false;
        _stage = 'image';
        _samDone = 0;
        _samTotal = 0;
        _scanLabels = [];
        _scanBoxes = [];
        _baselineCorrect = null;
        _imageFailed = false;
        _step = _Step.scanning;
      });
      _scan(url, token);
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
        showAppToast(context, tr('room_perm_denied'), kind: ToastKind.warning);
      } else {
        showAppToast(context, tr('room_pick_failed'), kind: ToastKind.error);
      }
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, tr('room_pick_failed'), kind: ToastKind.error);
    }
  }

  /// Same as [_pick], but loads the bundled AI-generated sample room, so
  /// judges on a simulator reach the scan in one tap. The scan still runs
  /// the real Muse Spark + SAM 3.1 round on this image.
  Future<void> _pickSample() async {
    if (!await MetaAIService.cloudConsent()) {
      if (!mounted) return;
      _snack(tr('room_consent_off'));
      return;
    }
    final token = ++_token;
    try {
      final bytes = (await rootBundle.load('assets/demo/sample_room.jpg'))
          .buffer
          .asUint8List();
      final url = await compute(squareJpegDataUrl, bytes);
      if (!mounted || token != _token) return;
      setState(() {
        _photo = url;
        _sample = true;
        _stage = 'image';
        _samDone = 0;
        _samTotal = 0;
        _scanLabels = [];
        _scanBoxes = [];
        _baselineCorrect = null;
        _imageFailed = false;
        _step = _Step.scanning;
      });
      _scan(url, token);
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, tr('room_pick_failed'), kind: ToastKind.error);
    }
  }

  /// Cancel (and blocked back navigation) while scanning: drop the
  /// in-flight round and go back to capture.
  void _cancelScan() {
    AppFeedback.light();
    _token++;
    if (!mounted) return;
    _baselineTimer?.cancel();
    setState(() {
      _stage = 'image';
      _samDone = 0;
      _samTotal = 0;
      _scanLabels = [];
      _scanBoxes = [];
      _baselineCorrect = null;
      _sample = false;
      _step = _Step.capture;
    });
  }

  Future<void> _scan(String dataUrl, int token) async {
    try {
      final round = await MetaAIService.pictureRecallRound(
        seed: 'room:${DateTime.now().millisecondsSinceEpoch}',
        count: 8,
        locale: AppLocalizations.localeCode,
        imageRefOverride: dataUrl,
        sceneOverride:
            'a real photo of the learner\'s own room, used as a memory palace. '
            'Name ONLY large, fixed, clearly separate landmarks a person would '
            'walk past and that never move: furniture and fixtures such as '
            'door, window, bed, desk, chair, shelf, wardrobe, cabinet, lamp, '
            'radiator, mirror, plant pot, picture frame. NEVER name walls, '
            'floor, ceiling, carpet, rug, curtains as a whole room surface, '
            'shadows, or small loose items (remote, bottle, cup, pen, cable, '
            'ball, phone, headphones)',
        onProgress: (p, stage) {
          if (!mounted || token != _token) return;
          setState(() => _stage = stage);
        },
        onSamItem: (done, total) {
          if (!mounted || token != _token) return;
          AppFeedback.select();
          setState(() {
            _samDone = done;
            _samTotal = total;
          });
        },
        onObjects: (labels, boxes) {
          if (!mounted || token != _token) return;
          AppFeedback.medium();
          setState(() {
            _scanLabels = labels;
            _scanBoxes = boxes;
          });
        },
      );
      if (!mounted || token != _token) return;
      final aiOk =
          round.live && round.imageUrl == dataUrl && round.objects.length >= 2;
      if (aiOk) {
        // Drop room surfaces and loose items, keep the first 6 landmarks.
        const badBits = [
          'wall',
          'floor',
          'ceiling',
          'carpet',
          'rug',
          'fal',
          'padló',
          'plafon',
          'szőnyeg',
          'mennyezet',
        ];
        var stations = <String>[];
        var boxes = <List<double>>[];
        var masks = <String>[];
        final aligned =
            round.boxes.length == round.objects.length &&
            round.masks.length == round.objects.length;
        for (var i = 0; i < round.objects.length; i++) {
          final low = round.objects[i].toLowerCase();
          if (badBits.any(low.contains)) continue;
          stations.add(round.objects[i]);
          if (aligned) {
            boxes.add(round.boxes[i]);
            masks.add(round.masks[i]);
          }
          if (stations.length >= 6) break;
        }
        if (stations.length < 2) {
          // Filtering ate everything: keep the first landmarks unfiltered
          // so the flow never strands the learner on an empty list.
          stations = round.objects.take(6).toList();
          boxes = aligned ? round.boxes.take(6).toList() : <List<double>>[];
          masks = aligned ? round.masks.take(6).toList() : <String>[];
        }
        final ordered = walkOrder(stations, boxes, masks);
        setState(() {
          _stations = ordered.stations;
          _boxes = ordered.boxes;
          _masks = ordered.masks;
          _live = true;
          _coverVersion++;
          _step = _Step.items;
        });
      } else {
        final live = round.live;
        setState(() {
          _stations = [
            for (var i = 1; i <= 4; i++) tr('room_spot', {'n': '$i'}),
          ];
          _boxes = [];
          _masks = [];
          _live = false;
          _coverVersion++;
          _step = _Step.items;
        });
        if (!mounted || token != _token) return;
        showAppToast(
          context,
          tr(live ? 'room_no_stations' : 'room_ai_unavailable'),
          kind: ToastKind.warning,
          actionLabel: tr('room_retake'),
          onAction: () {
            _token++;
            if (!mounted) return;
            setState(() => _step = _Step.capture);
          },
        );
      }
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() => _step = _Step.capture);
      showAppToast(context, tr('room_pick_failed'), kind: ToastKind.error);
    }
  }

  List<String> _parseItems() {
    return _itemsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(_stations.length)
        .toList();
  }

  Future<void> _buildPalace() async {
    final items = _parseItems();
    if (items.length < 2) {
      _snack(tr('room_items_too_few'));
      return;
    }
    final n = items.length;
    final stations = _stations.take(n).toList();
    final token = _token;
    setState(() => _building = true);
    try {
      final answer = await MetaAIService.roomPalaceLinks(
        stations: stations,
        items: items,
        locale: AppLocalizations.localeCode,
      );
      if (!mounted || token != _token) return;
      final id = 'room:${DateTime.now().millisecondsSinceEpoch}';
      final palace = RoomPalace(
        id: id,
        createdAt: DateTime.now(),
        imageRef: _photo,
        stations: stations,
        boxes: _boxes.length == _stations.length
            ? _boxes.take(n).toList()
            : const [],
        masks: _masks.length == _stations.length
            ? _masks.take(n).toList()
            : const [],
        items: items,
        links: answer.links,
        live: _live,
        card: FsrsCard(cardId: id, taskId: 'room_palace', due: DateTime.now()),
        sample: _sample,
      );
      await MemoryStore.upsertRoomPalace(palace);
      // A freshly built palace becomes the lesson palace on the spot.
      await ActivePalaceStore.setId(palace.id);
      if (!mounted || token != _token) return;
      setState(() {
        _activeId = palace.id;
        _palace = palace;
        _focus = 0;
        _dreams.clear();
        _storedDreams.clear();
        _revealedDreams.clear();
        _building = false;
        _step = _Step.encode;
      });
      _startDreams(palace, token);
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() => _building = false);
      _snack(tr('common_save_failed'));
    }
  }

  Future<void> _dreamOne(RoomPalace palace, int token, int i) async {
    final link = i < palace.links.length ? palace.links[i] : palace.items[i];
    final image = await MetaAIService.generateImage(
      MetaImageRequest(
        prompt: MetaAIService.roomDreamPrompt(
          palace.stations[i],
          palace.items[i],
          link,
        ),
        style: 'room-dream',
      ),
      timeoutSec: 60,
    );
    if (!mounted || token != _token) return;
    final url = image.fallback ? '' : image.url;
    setState(() => _dreams[i] = url);
    // Persist off the UI path: the scene is already visible above.
    _persistDream(palace, token, i, url);
  }

  /// Downscales one dream scene to a small JPEG data URL for storage.
  /// Returns '' for remote-download or decode failures. Never throws.
  Future<String> _downscaledDream(String url) async {
    try {
      final bytes = url.startsWith('http')
          ? (await http
                    .get(Uri.parse(url))
                    .timeout(const Duration(seconds: 15)))
                .bodyBytes
          : decodeDataImage(url);
      if (bytes == null || bytes.isEmpty) return '';
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return '';
      final small = img.copyResize(decoded, width: 384);
      return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(small, quality: 70))}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _persistDream(
    RoomPalace palace,
    int token,
    int i,
    String url,
  ) async {
    final stored = await _downscaledDream(url);
    if (!mounted || token != _token) return;
    _storedDreams[i] = stored;
    final count = palace.stations.length;
    final dreams = List<String>.filled(count, '');
    final current = _palace;
    if (current != null && current.id == palace.id) {
      for (var k = 0; k < count && k < current.dreams.length; k++) {
        dreams[k] = current.dreams[k];
      }
    }
    _storedDreams.forEach((k, v) {
      if (k >= 0 && k < count) dreams[k] = v;
    });
    final base = (current != null && current.id == palace.id)
        ? current
        : palace;
    final updated = base.copyWith(dreams: dreams);
    _persistChain = _persistChain.then(
      (_) => MemoryStore.upsertRoomPalace(updated),
    );
    await _persistChain;
    if (!mounted || token != _token) return;
    final latest = _palace;
    if (latest != null && latest.id == palace.id && mounted) {
      setState(() => _palace = updated);
    }
  }

  Future<void> _startDreams(RoomPalace palace, int token) async {
    if (!palace.live) return;
    for (var i = 0; i < palace.items.length; i += 2) {
      if (!mounted || token != _token) return;
      final pair = <Future<void>>[
        _dreamOne(palace, token, i),
        if (i + 1 < palace.items.length) _dreamOne(palace, token, i + 1),
      ];
      await Future.wait(pair);
    }
  }

  Future<void> _retryDream(int i) async {
    final palace = _palace;
    if (palace == null) return;
    final token = _token;
    setState(() {
      _dreams.remove(i);
      // A repainted dream is new again, so it reveals once more.
      _revealedDreams.remove(i);
    });
    await _dreamOne(palace, token, i);
  }

  Future<void> _check() async {
    final palace = _palace;
    if (palace == null || _awaitNext || _judging) return;
    final items = palace.items;
    if (_cue < 0 || _cue >= items.length) return;
    final input = _guessCtrl.text;
    if (input.trim().isEmpty) return;
    final token = _token;
    final cue = _cue;
    final m = localRecallAnswer(items[cue], input);
    if (m != RecallMatch.none) {
      _markCorrect(
        cue,
        token,
        feedback: tr(
          m == RecallMatch.exact ? 'room_correct' : 'room_correct_typo',
          {'item': items[cue]},
        ),
      );
      return;
    }
    for (var i = 0; i < items.length; i++) {
      if (i == cue) continue;
      if (localRecallAnswer(items[i], input) != RecallMatch.none) {
        setState(() {
          _feedbackGood = false;
          _feedback = tr('room_elsewhere', {'n': i + 1});
        });
        _guessFocus.requestFocus();
        _guessCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _guessCtrl.text.length,
        );
        return;
      }
    }
    setState(() => _judging = true);
    final verdict = await MetaAIService.judgeRecall(
      expected: items[cue],
      answer: input,
      locale: AppLocalizations.localeCode,
    );
    if (!mounted || token != _token) return;
    setState(() => _judging = false);
    if (cue != _cue || _awaitNext) return;
    if (verdict == 'correct') {
      _markCorrect(
        cue,
        token,
        feedback: tr('room_accepted', {'item': items[cue]}),
      );
    } else if (verdict == 'close') {
      setState(() {
        _revealed = {..._revealed, cue};
        _feedbackGood = false;
        _feedback = tr('room_almost', {'item': items[cue]});
        _awaitNext = true;
      });
    } else {
      AppFeedback.medium();
      final link = cue < palace.links.length ? palace.links[cue] : items[cue];
      setState(() {
        _feedbackGood = false;
        _feedback = tr('room_wrong_with_link', {'link': link});
      });
      // Keep focus and select the wrong text so the next keystroke
      // replaces it instead of appending to it.
      _guessFocus.requestFocus();
      _guessCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _guessCtrl.text.length,
      );
    }
  }

  /// Station centre in photo fractions for the spotlight and ripple.
  /// Falls back to an even spread when boxes are missing.
  Offset _stationCentre(RoomPalace palace, int i) {
    final boxes = palace.boxes;
    if (boxes.length == palace.items.length &&
        i >= 0 &&
        i < boxes.length &&
        boxes[i].length >= 4) {
      final b = boxes[i];
      return Offset(
        (b[0] + b[2] / 2).clamp(0.0, 1.0),
        (b[1] + b[3] / 2).clamp(0.0, 1.0),
      );
    }
    final n = palace.items.length.clamp(1, 99);
    return Offset(0.5, (i.clamp(0, n - 1) + 0.5) / n);
  }

  void _markCorrect(int cue, int token, {required String feedback}) {
    final palace = _palace;
    if (palace == null || !mounted || token != _token || cue != _cue) return;
    AppFeedback.select();
    _rippleAt = _stationCentre(palace, cue);
    _rippleKey++;
    final correct = _correct + 1;
    final revealed = {..._revealed, cue};
    final last = cue + 1 >= palace.items.length;
    final dream = _dreams[cue];
    _popTimer?.cancel();
    setState(() {
      _correct = correct;
      _revealed = revealed;
      _correctIdx = {..._correctIdx, cue};
      _feedback = feedback;
      _feedbackGood = true;
      _judging = false;
      _guessCtrl.clear();
      _popDream = (dream != null && dream.isNotEmpty) ? dream : null;
      _popOpacity = 1;
      if (!last) {
        _cue++;
      }
    });
    if (_popDream != null) {
      _popTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        setState(() => _popOpacity = 0);
      });
    }
    if (last) {
      setState(() => _step = _Step.result);
      _finishRun();
    }
  }

  void _reveal() {
    final palace = _palace;
    if (palace == null || _awaitNext) return;
    if (_cue < 0 || _cue >= palace.items.length) return;
    final link = _cue < palace.links.length
        ? palace.links[_cue]
        : palace.items[_cue];
    setState(() {
      _revealed = {..._revealed, _cue};
      _feedbackGood = false;
      _feedback = tr('room_wrong_with_link', {'link': link});
      _awaitNext = true;
    });
  }

  void _advance() {
    final palace = _palace;
    if (palace == null) return;
    if (_cue + 1 >= palace.items.length) {
      setState(() {
        _awaitNext = false;
        _feedback = '';
        _step = _Step.result;
      });
      _finishRun();
    } else {
      setState(() {
        _cue++;
        _awaitNext = false;
        _feedback = '';
        _guessCtrl.clear();
      });
    }
  }

  Future<void> _finishRun() async {
    final palace = _palace;
    if (palace == null || _rescheduled) return;
    // A blind run is practice: no rescheduling, no save, still a result.
    if (_blind) return;
    _rescheduled = true;
    final grade = roomGrade(_correct, palace.items.length);
    final card = FsrsScheduler.next(palace.card, grade);
    final updated = palace.copyWith(card: card);
    await MemoryStore.upsertRoomPalace(updated);
    if (!mounted) return;
    setState(() {
      _palace = updated;
      _nextDue = card.due;
    });
    BenchmarkStore.submit(
      'spatial',
      _correct,
      higherIsBetter: true,
      xpGain: 10 + _correct * 4,
    );
  }

  /// After "Done" show the palace list step (with the saved palace)
  /// instead of popping. Only pop when the page was opened directly into
  /// review and there is no list step behind it.
  Future<void> _doneFromResult() async {
    if (widget.reviewId != null && _palaces.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _loadList();
  }

  Future<void> _confirmDelete(RoomPalace p) async {
    final ok = await showAppDialog<bool>(
      context,
      title: tr('room_delete_title'),
      body: tr('room_delete_body'),
      icon: HugeIcons.strokeRoundedDelete02,
      iconColor: coral,
      destructive: true,
      primary: AppDialogAction(tr('common_delete'), value: true),
      secondary: AppDialogAction(tr('common_cancel'), value: false),
    );
    if (ok != true || !mounted) return;
    final token = _token;
    await MemoryStore.deleteRoomPalace(p.id);
    final activeId = await ActivePalaceStore.loadId();
    if (activeId == p.id) await ActivePalaceStore.clear();
    if (!mounted || token != _token) return;
    setState(() {
      _palaces = _palaces.where((e) => e.id != p.id).toList();
      if (activeId == p.id) _activeId = null;
      if (_palaces.isEmpty) _step = _Step.capture;
    });
  }

  bool get _needsLeaveConfirm =>
      _step == _Step.items || _step == _Step.encode || _step == _Step.recall;

  Future<bool> _confirmLeave() async {
    final leave = await showAppDialog<bool>(
      context,
      title: tr('room_leave_title'),
      body: tr('room_leave_body'),
      primary: AppDialogAction(tr('room_leave_stay'), value: false),
      secondary: AppDialogAction(tr('room_leave_leave'), value: true),
    );
    return leave == true;
  }

  /// Back from the baseline probe loses nothing (the photo and the typed
  /// items stay), so it returns to the items step without asking.
  void _backToItems() {
    _baselineTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _baselineRecall = false;
      _step = _Step.items;
    });
  }

  Future<void> _onBackPressed() async {
    if (_step == _Step.baseline) {
      _backToItems();
      return;
    }
    if (!_needsLeaveConfirm) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final leave = await _confirmLeave();
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palace = _palace;
    final recallBar =
        _ready &&
        _step == _Step.recall &&
        palace != null &&
        palace.items.isNotEmpty;
    return PopScope(
      canPop:
          !_needsLeaveConfirm &&
          _step != _Step.scanning &&
          _step != _Step.baseline,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_needsLeaveConfirm) {
          final leave = await _confirmLeave();
          if (leave && context.mounted) Navigator.of(context).pop();
          return;
        }
        if (_step == _Step.baseline) {
          _backToItems();
          return;
        }
        if (_step == _Step.scanning) _cancelScan();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppTopBar(
          title: _step == _Step.capture ? null : tr('room_title'),
          leading: EngramBackButton(onPressed: _onBackPressed),
        ),
        resizeToAvoidBottomInset: !recallBar,
        body: SafeArea(top: false, bottom: false, child: _body()),
        bottomNavigationBar: recallBar ? _recallBar() : null,
      ),
    );
  }

  /// Keyboard-safe answer bar for the recall step: field + actions ride
  /// above the keyboard instead of sitting at the end of the list.
  Widget _recallBar() {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        duration: const Duration(milliseconds: 180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_feedbackGood && _feedback.isNotEmpty) ...[
                Text(
                  _feedback,
                  style: AppText.body.copyWith(color: context.accentText(teal)),
                ),
                const SizedBox(height: 8),
              ],
              AppTextField(
                controller: _guessCtrl,
                focusNode: _guessFocus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _check(),
                onChanged: (_) {
                  if (!_feedbackGood && _feedback.isNotEmpty && mounted) {
                    setState(() => _feedback = '');
                  }
                },
                scrollPadding: const EdgeInsets.only(bottom: 160),
                errorText: !_feedbackGood && _feedback.isNotEmpty
                    ? _feedback
                    : null,
              ),
              const SizedBox(height: 8),
              if (_awaitNext)
                EngramButton(
                  label: tr('common_next'),
                  onPressed: () {
                    AppFeedback.light();
                    _advance();
                  },
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: EngramButton(
                        label: tr('room_check_btn'),
                        isLoading: _judging,
                        onPressed: () {
                          AppFeedback.light();
                          _check();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EngramButton(
                        label: tr('room_reveal_btn'),
                        variant: EngramButtonVariant.secondary,
                        onPressed: () {
                          AppFeedback.light();
                          _reveal();
                        },
                      ),
                    ),
                  ],
                ),
              if (_judging) ...[
                const SizedBox(height: 6),
                Text(
                  tr('room_judging'),
                  textAlign: TextAlign.center,
                  style: AppText.micro.copyWith(color: context.mutedText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (!_ready) {
      return const AppSkeletonList();
    }
    return switch (_step) {
      _Step.list => _listStep(),
      _Step.capture => _captureStep(),
      _Step.scanning => _scanningStep(),
      _Step.items => _itemsStep(),
      _Step.baseline => _baselineStep(),
      _Step.encode => _encodeStep(),
      _Step.recall => _recallStep(),
      _Step.result => _resultStep(),
    };
  }

  Widget _page(List<Widget> children) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        for (var i = 0; i < children.length; i++) _enter(i, children[i]),
      ],
    );
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: AppText.title.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _muted(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: AppText.caption.copyWith(color: context.mutedText),
      ),
    );
  }

  /// SAM covers over [imageUrl]; falls back to a word list when the
  /// picture failed to load, so the round still works photo-less.
  Widget _covers({
    required String imageUrl,
    required List<String> objects,
    required List<List<double>> boxes,
    required List<String> masks,
    required Set<int> revealed,
    required bool masked,
    int cue = -1,
    bool showWalk = false,
    bool highlight = false,
    double? maxSide,
  }) {
    // No stations yet (or nothing survived filtering): a plain photo,
    // never an empty MaskedPicture.
    if (objects.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxSide ?? 380),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _imageFailed
                  ? _wordFallback(objects)
                  : AiImage(imageRef: imageUrl, fit: BoxFit.cover),
            ),
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxSide ?? 380),
        child: AspectRatio(
          aspectRatio: 1,
          child: _imageFailed
              ? _wordFallback(objects)
              : MaskedPicture(
                  imageUrl: imageUrl,
                  scene: '',
                  objects: objects,
                  boxes: boxes.length == objects.length
                      ? boxes
                      : const <List<double>>[],
                  masks: masks.length == objects.length
                      ? masks
                      : const <String>[],
                  revealed: revealed,
                  masked: masked,
                  cue: cue,
                  version: _coverVersion,
                  showWalk: showWalk,
                  highlight: highlight,
                  onImageError: () {
                    if (!_imageFailed && mounted) {
                      setState(() => _imageFailed = true);
                    }
                  },
                ),
        ),
      ),
    );
  }

  Widget _wordFallback(List<String> words) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < words.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${i + 1}. ${words[i]}',
                  style: AppText.body.copyWith(
                    color: context.inkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _reviewPalace(RoomPalace p) {
    AppFeedback.light();
    setState(() {
      _photo = p.imageRef;
      _stations = p.stations;
      _boxes = p.boxes;
      _masks = p.masks;
      _live = p.live;
      _sample = p.sample;
      _imageFailed = false;
      _coverVersion++;
      _palace = p;
      _blind = false;
      _resetRecall();
      for (var i = 0; i < p.dreams.length; i++) {
        if (p.dreams[i].isNotEmpty) {
          _dreams[i] = p.dreams[i];
          // Stored scenes are not new arrivals: no replay, no haptic.
          _revealedDreams.add(i);
        }
      }
      _rescheduled = false;
      _nextDue = null;
      _step = _Step.recall;
    });
  }

  Future<void> _openRowSheet(RoomPalace p) {
    return showAppSheet<void>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tappable(
            onTap: () {
              Navigator.of(sheetContext).pop();
              _reviewPalace(p);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedEye,
                    color: context.inkText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('room_review_btn'),
                    style: AppText.body.copyWith(color: context.inkText),
                  ),
                ],
              ),
            ),
          ),
          Tappable(
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ActivePalaceStore.setId(p.id);
              if (!mounted) return;
              setState(() => _activeId = p.id);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedPin,
                    color: context.inkText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('palace_use'),
                    style: AppText.body.copyWith(color: context.inkText),
                  ),
                ],
              ),
            ),
          ),
          Tappable(
            onTap: () {
              Navigator.of(sheetContext).pop();
              _confirmDelete(p);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete02,
                    color: context.dangerText,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr('common_delete'),
                    style: AppText.body.copyWith(color: context.dangerText),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _listStep() {
    return _page([
      _header(tr('room_saved_title')),
      for (final p in _palaces) ...[
        Tappable(
          onTap: () => _reviewPalace(p),
          onLongPress: () => _confirmDelete(p),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.hairline, width: 2),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'room-${p.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.s),
                    child: AiImage(
                      imageRef: p.imageRef,
                      height: 56,
                      width: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _listTitle(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.copyWith(
                          color: context.inkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.card.isDue()
                            ? tr('room_due')
                            : tr('room_not_due', {
                                'date': MaterialLocalizations.of(context)
                                    .formatShortDate(p.card.due),
                              }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(
                          color: context.mutedText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            AppBadge(
                              label: tr(
                                p.live ? 'room_badge_live' : 'room_badge_local',
                              ),
                              color: p.live ? teal : blue,
                            ),
                            if (p.id == _activeId)
                              AppBadge(label: tr('palace_active')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppIconButton(
                  onTap: () => _openRowSheet(p),
                  icon: HugeIcons.strokeRoundedMoreVertical,
                  color: context.mutedText,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 8),
      EngramButton(
        label: tr('room_new_btn'),
        onPressed: () {
          AppFeedback.light();
          setState(() => _step = _Step.capture);
        },
      ),
    ]);
  }

  Widget _captureStep() {
    return _page([
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: const RoomPreviewArt(aspectRatio: 1.25),
      ),
      const SizedBox(height: 16),
      Text(
        tr('room_title'),
        style: AppText.display.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        tr('room_sub'),
        style: AppText.body.copyWith(color: context.mutedText),
      ),
      const SizedBox(height: 16),
      AppDisclosure(
        title: Text(
          tr('room_science_title'),
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w600,
            color: context.inkText,
          ),
        ),
        children: [
          Text(
            tr('room_science'),
            style: AppText.caption.copyWith(color: context.mutedText),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (roomCameraSupported) ...[
        EngramButton(
          label: tr('room_take_photo'),
          onPressed: () => _pick(ImageSource.camera),
        ),
        const SizedBox(height: 10),
      ],
      EngramButton(
        label: tr('room_pick_photo'),
        variant: EngramButtonVariant.secondary,
        onPressed: () => _pick(ImageSource.gallery),
      ),
      const SizedBox(height: 10),
      EngramTextButton(
        key: const ValueKey('room-try-sample'),
        label: tr('room_try_sample'),
        onPressed: _pickSample,
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedLockPassword,
            color: context.mutedText,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              tr('room_privacy'),
              style: AppText.micro.copyWith(color: context.mutedText),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _sampleBadge() {
    return Align(
      alignment: Alignment.centerLeft,
      child: AppBadge(label: tr('room_sample_badge'), color: blue),
    );
  }

  Widget _scanningStep() {
    return _page([
      if (_sample) ...[_sampleBadge(), const SizedBox(height: 8)],
      _ScanStage(
        photo: _photo,
        stage: _stage,
        samDone: _samDone,
        samTotal: _samTotal,
        labels: _scanLabels,
        boxes: _scanBoxes,
      ),
      const SizedBox(height: 20),
      EngramButton(
        label: tr('common_cancel'),
        variant: EngramButtonVariant.secondary,
        onPressed: _cancelScan,
      ),
    ]);
  }

  Widget _itemsStep() {
    return _page([
      _header(tr('room_items_title')),
      if (_sample) ...[_sampleBadge(), const SizedBox(height: 8)],
      _covers(
        imageUrl: _photo,
        objects: _stations,
        boxes: _boxes,
        masks: _masks,
        revealed: const {},
        masked: false,
        showWalk: true,
        highlight: true,
      ),
      const SizedBox(height: 12),
      Text(
        tr('room_stations_found', {'count': _stations.length}),
        style: AppText.body.copyWith(
          color: context.inkText,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _stations.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _stationColor(i),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: AppText.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _stations[i],
                  style: AppText.body.copyWith(
                    color: context.inkText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 20),
      AppTextField(
        controller: _itemsCtrl,
        label: tr('room_items_label'),
        hint: tr('room_items_hint', {'count': _stations.length}),
        minLines: 4,
        maxLines: 8,
        maxLength: 600,
      ),
      if (_itemsCtrl.text.isEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: AppLinkButton(
            key: const ValueKey('room-items-sample'),
            label: tr('room_items_sample'),
            icon: HugeIcons.strokeRoundedMagicWand01,
            onTap: () =>
                setState(() => _itemsCtrl.text = tr('room_sample_items')),
          ),
        ),
      const SizedBox(height: 8),
      EngramButton(
        label: tr('room_encode_btn'),
        isLoading: _building,
        onPressed: _building
            ? null
            : () {
                AppFeedback.light();
                _buildPalace();
              },
      ),
      const SizedBox(height: 10),
      EngramButton(
        label: tr('room_baseline_btn'),
        variant: EngramButtonVariant.secondary,
        onPressed: _baselineReady
            ? () {
                AppFeedback.light();
                _startBaseline();
              }
            : null,
      ),
    ]);
  }

  /// The baseline probe needs something to prove: at least 3 typed items.
  bool get _baselineReady => _parseItems().length >= 3;

  /// Shows the same items for 12 s, then hides them and asks what stuck.
  /// Scores locally and continues to the normal palace build.
  void _startBaseline() {
    final items = _parseItems();
    if (items.length < 3) return;
    _baselineTimer?.cancel();
    setState(() {
      _baselineItems = items;
      _baselineCorrect = null;
      _baselineLeft = 12;
      _baselineRecall = isFlutterTest;
      _baselineCtrl.clear();
      _step = _Step.baseline;
    });
    if (isFlutterTest) return;
    _baselineTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_step != _Step.baseline || _baselineRecall) {
        t.cancel();
        return;
      }
      setState(() {
        _baselineLeft--;
        if (_baselineLeft <= 0) {
          t.cancel();
          _baselineRecall = true;
        }
      });
    });
  }

  /// Scores the baseline recall with the local matcher: each typed line
  /// against each item, every item counted at most once. Then the normal
  /// build continues with the same items.
  void _scoreBaseline() {
    final items = _baselineItems;
    final lines = _baselineCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    var correct = 0;
    final used = <int>{};
    for (final line in lines) {
      for (var i = 0; i < items.length; i++) {
        if (used.contains(i)) continue;
        if (localRecallAnswer(items[i], line) != RecallMatch.none) {
          used.add(i);
          correct++;
          break;
        }
      }
    }
    _baselineTimer?.cancel();
    setState(() => _baselineCorrect = correct);
    _buildPalace();
  }

  Widget _baselineStep() {
    return _page([
      _header(tr('room_baseline_title')),
      if (!_baselineRecall) ...[
        _muted(tr('room_baseline_memorize', {'n': _baselineLeft})),
        const SizedBox(height: 4),
        for (var i = 0; i < _baselineItems.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _stationColor(i),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppText.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _baselineItems[i],
                    style: AppText.body.copyWith(
                      color: context.inkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Center(
          child: AppProgressRing(
            value: _baselineLeft / 12,
            child: Text(
              '$_baselineLeft',
              style: AppText.title.copyWith(color: context.inkText),
            ),
          ),
        ),
      ] else ...[
        AppTextField(
          controller: _baselineCtrl,
          label: tr('room_baseline_prompt'),
          minLines: 4,
          maxLines: 8,
        ),
        const SizedBox(height: 10),
        EngramButton(label: tr('room_check_btn'), onPressed: _scoreBaseline),
      ],
    ]);
  }

  Widget _encodeStep() {
    final palace = _palace;
    if (palace == null) return _page([_header(tr('room_title'))]);
    return _page([
      _muted(tr('room_encode_tip')),
      _covers(
        imageUrl: palace.imageRef,
        objects: palace.stations,
        boxes: palace.boxes,
        masks: palace.masks,
        revealed: const {},
        masked: false,
        cue: _focus,
        showWalk: true,
        highlight: true,
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < palace.items.length; i++) _stationCard(palace, i),
      const SizedBox(height: 8),
      if (palace.stations.isNotEmpty &&
          palace.items.length >= palace.stations.length)
        EngramButton(
          label: tr('room_tour_btn'),
          variant: EngramButtonVariant.secondary,
          onPressed: () {
            AppFeedback.light();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _TourPage(
                  palace: palace,
                  dreams: Map<int, String>.from(_dreams),
                  onDone: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _blind = false;
                      _resetRecall();
                      _rescheduled = false;
                      _nextDue = null;
                      _step = _Step.recall;
                    });
                  },
                ),
              ),
            );
          },
        ),
      if (palace.stations.isNotEmpty &&
          palace.items.length >= palace.stations.length)
        const SizedBox(height: 10),
      EngramButton(
        label: tr('room_walk_btn'),
        onPressed: () {
          AppFeedback.light();
          setState(() {
            _blind = false;
            _resetRecall();
            _rescheduled = false;
            _nextDue = null;
            _step = _Step.recall;
          });
        },
      ),
    ]);
  }

  Widget _stationCard(RoomPalace palace, int i) {
    final focused = i == _focus;
    final station = _stationColor(i);
    final dream = _dreams[i];
    final link = i < palace.links.length ? palace.links[i] : palace.items[i];
    return Tappable(
      onTap: () => setState(() => _focus = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: focused ? station : context.hairline,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: station,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppText.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    palace.stations[i],
                    style: AppText.heading.copyWith(color: context.inkText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              palace.items[i],
              style: AppText.body.copyWith(
                color: context.inkText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              link,
              style: AppText.body.copyWith(
                color: context.mutedText,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (dream != null && dream.isNotEmpty) ...[
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  child: _dreamImage(palace, i, dream),
                ),
              ),
            ] else if (dream == null && palace.live) ...[
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          AppSkeleton(height: constraints.maxHeight),
                          Positioned(
                            left: 12,
                            bottom: 12,
                            right: 12,
                            child: Row(
                              children: [
                                const AppBadge(
                                  label: 'Muse Image',
                                  color: orange,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    tr('room_dreaming', {
                                      'item': palace.items[i],
                                    }),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.micro.copyWith(
                                      color: context.mutedText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ] else if (dream != null && dream.isEmpty && palace.live) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: EngramTextButton(
                  icon: HugeIcons.strokeRoundedRefresh,
                  label: tr('room_dream_retry'),
                  onPressed: () => _retryDream(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The dream scene for station i. A brand-new arrival reveals once
  /// (blur + scale + fade, one haptic); stored scenes and rebuilds render
  /// the plain image. Only this image animates, never the whole photo.
  Widget _dreamImage(RoomPalace palace, int i, String dream) {
    if (_revealedDreams.contains(i)) {
      return AiImage(imageRef: dream, fit: BoxFit.cover);
    }
    _revealedDreams.add(i);
    AppFeedback.medium();
    return _DreamReveal(imageRef: dream);
  }

  Widget _recallStep() {
    final palace = _palace;
    if (palace == null || palace.items.isEmpty) {
      return _page([_header(tr('room_title'))]);
    }
    final done = _cue >= palace.items.length;
    // Keep the photo (and the keyboard) on screen on short phones.
    final side = min(
      380.0,
      MediaQuery.sizeOf(context).height - 380,
    ).clamp(220.0, 380.0).toDouble();
    return _page([
      if (_blind && !done)
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: side),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF16233B),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedViewOff,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('room_blind_card'),
                        textAlign: TextAlign.center,
                        style: AppText.body.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('room_station_n', {
                          'n': _cue + 1,
                          'name': palace.stations[_cue],
                        }),
                        textAlign: TextAlign.center,
                        style: AppText.title.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
      else
        Stack(
          clipBehavior: Clip.none,
          children: [
            Hero(
              tag: 'room-${palace.id}',
              child: _covers(
                imageUrl: palace.imageRef,
                objects: palace.items,
                boxes: palace.boxes,
                masks: palace.masks,
                revealed: _revealed,
                masked: true,
                cue: done ? -1 : _cue,
                maxSide: side,
              ),
            ),
            if (!done)
              Positioned.fill(
                child: RepaintBoundary(
                  child: TweenAnimationBuilder<Offset>(
                    key: ValueKey('spot-$_cue'),
                    tween: Tween(
                      begin: _cue > 0
                          ? _stationCentre(palace, _cue - 1)
                          : _stationCentre(palace, _cue),
                      end: _stationCentre(palace, _cue),
                    ),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeInOutCubic,
                    builder: (context, centre, _) =>
                        CustomPaint(painter: _SpotlightPainter(centre: centre)),
                  ),
                ),
              ),
            if (!done && _rippleKey > 0)
              Positioned.fill(
                child: RepaintBoundary(
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('ripple-$_rippleKey'),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, t, _) => CustomPaint(
                      painter: _RipplePainter(centre: _rippleAt, t: t),
                    ),
                  ),
                ),
              ),
            if (_popDream != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_cue),
                  tween: Tween(begin: 0.9, end: 1.0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  builder: (context, t, c) =>
                      Transform.scale(scale: t, child: c),
                  child: AnimatedOpacity(
                    opacity: _popOpacity,
                    duration: const Duration(milliseconds: 200),
                    onEnd: () {
                      if (_popOpacity == 0 && mounted) {
                        setState(() => _popDream = null);
                      }
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                        child: AiImage(
                          imageRef: _popDream!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      const SizedBox(height: 12),
      if (!done)
        Text(
          tr('room_walk_n', {
            'n': '${_cue + 1}',
            'total': '${palace.items.length}',
            'name': _cue < palace.stations.length
                ? palace.stations[_cue]
                : palace.items[_cue],
          }),
          style: TextStyle(
            color: context.mutedText,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      if (!done)
        Text(
          tr('room_recall_prompt', {'n': _cue + 1}),
          style: AppText.body.copyWith(
            color: context.inkText,
            fontWeight: FontWeight.w600,
          ),
        ),
    ]);
  }

  Widget _resultStep() {
    final palace = _palace;
    if (palace == null) return _page([_header(tr('room_title'))]);
    final total = palace.items.length;
    final missed = {
      for (var i = 0; i < palace.stations.length; i++)
        if (!_correctIdx.contains(i)) i,
    };
    final xp = 10 + _correct * 4;
    void startBlind() {
      AppFeedback.light();
      setState(() {
        _blind = true;
        _resetRecall();
        _rescheduled = false;
        _nextDue = null;
        _step = _Step.recall;
      });
    }

    void startAgain() {
      AppFeedback.light();
      setState(() {
        _blind = false;
        _resetRecall();
        _step = _Step.recall;
      });
    }

    void openShare() {
      AppFeedback.light();
      showAppSheet(
        context,
        builder: (_) => _ShareCard(palace: palace, correct: _correct),
      );
    }

    void openReceipt() async {
      AppFeedback.light();
      final log = await MetaAIService.loadLog();
      if (!mounted) return;
      showAppSheet(
        context,
        builder: (_) => _ReceiptCard(log: log, palace: palace),
      );
    }

    return _page([
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: MaskedPicture(
                imageUrl: palace.imageRef,
                scene: '',
                objects: palace.stations,
                boxes: palace.boxes.length == palace.stations.length
                    ? palace.boxes
                    : const <List<double>>[],
                masks: palace.masks.length == palace.stations.length
                    ? palace.masks
                    : const <String>[],
                revealed: const {},
                masked: false,
                highlight: true,
                dimmed: missed,
                version: _coverVersion,
                onImageError: () {
                  if (!_imageFailed && mounted) {
                    setState(() => _imageFailed = true);
                  }
                },
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (_baselineCorrect != null) ...[
        Center(
          child: _BaselineComparison(
            a: _baselineCorrect!,
            b: _correct,
            n: total,
            proof: _blind,
          ),
        ),
        const SizedBox(height: 12),
      ],
      if (!_blind)
        _ResultCelebration(
          correct: _correct,
          total: total,
          blind: _blind,
          sample: _sample,
        ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          AppBadge(label: '+$xp XP', color: orange),
          if (_nextDue != null)
            AppBadge(
              label: tr('room_next_short', {
                'date': MaterialLocalizations.of(context)
                    .formatShortDate(_nextDue!),
              }),
              color: blue,
            ),
        ],
      ),
      if (_blind) ...[
        const SizedBox(height: 16),
        Text(
          tr('room_proof_title', {'correct': _correct, 'total': total}),
          textAlign: TextAlign.center,
          style: AppText.display.copyWith(color: context.inkText),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < palace.stations.length; i++)
              AppBadge(
                label: i < palace.items.length
                    ? palace.items[i]
                    : palace.stations[i],
                color: _correctIdx.contains(i) ? teal : coral,
              ),
          ],
        ),
        const SizedBox(height: 16),
        EngramButton(
          label: tr('room_recall_again'),
          variant: EngramButtonVariant.secondary,
          onPressed: startAgain,
        ),
        const SizedBox(height: 8),
        EngramButton(
          label: tr('room_share_btn'),
          variant: EngramButtonVariant.secondary,
          onPressed: openShare,
        ),
        Center(
          child: EngramTextButton(
            label: tr('room_receipt_btn'),
            onPressed: openReceipt,
          ),
        ),
        Center(
          child: EngramTextButton(
            label: tr('common_done'),
            onPressed: _doneFromResult,
          ),
        ),
      ] else ...[
        const SizedBox(height: 16),
        EngramButton(label: tr('room_prove_btn'), onPressed: startBlind),
        const SizedBox(height: 8),
        EngramButton(
          label: tr('room_recall_again'),
          variant: EngramButtonVariant.secondary,
          onPressed: startAgain,
        ),
        const SizedBox(height: 8),
        EngramButton(
          label: tr('room_share_btn'),
          variant: EngramButtonVariant.secondary,
          onPressed: openShare,
        ),
        Center(
          child: EngramTextButton(
            label: tr('room_receipt_btn'),
            onPressed: openReceipt,
          ),
        ),
        Center(
          child: EngramTextButton(
            label: tr('common_done'),
            onPressed: _doneFromResult,
          ),
        ),
      ],
    ]);
  }
}

/// Before → after proof: same list, recalled today, once without the
/// palace and once with it. The "with" number renders in teal. Fires a
/// heavy haptic once when the palace run beats the baseline.
class _BaselineComparison extends StatefulWidget {
  final int a;
  final int b;
  final int n;

  /// After a blind run the "with it" half becomes "from memory".
  final bool proof;
  const _BaselineComparison({
    required this.a,
    required this.b,
    required this.n,
    this.proof = false,
  });

  @override
  State<_BaselineComparison> createState() => _BaselineComparisonState();
}

class _BaselineComparisonState extends State<_BaselineComparison> {
  @override
  void initState() {
    super.initState();
    if (widget.b > widget.a) AppFeedback.heavy();
  }

  @override
  Widget build(BuildContext context) {
    final full = tr(
      widget.proof ? 'room_baseline_vs_proof' : 'room_baseline_vs',
      {'a': widget.a, 'b': widget.b, 'n': widget.n},
    );
    final parts = full.split('→');
    final before = TextStyle(
      color: context.mutedText,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );
    final after = AppText.title.copyWith(color: teal);
    return Text.rich(
      TextSpan(
        children: parts.length > 1
            ? [
                TextSpan(text: '${parts[0].trimRight()} → ', style: before),
                TextSpan(text: parts[1].trim(), style: after),
              ]
            : [TextSpan(text: full, style: before)],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Result score with a count-up number and, on a perfect run, a burst
/// of 18 particles. Fires the result haptic once on first build.
class _ResultCelebration extends StatefulWidget {
  final int correct;
  final int total;

  /// A blind (photo-hidden) run earns a firmer haptic than a plain one.
  final bool blind;

  /// A palace built from the sample photo says so under the score.
  final bool sample;
  const _ResultCelebration({
    required this.correct,
    required this.total,
    this.blind = false,
    this.sample = false,
  });

  @override
  State<_ResultCelebration> createState() => _ResultCelebrationState();
}

class _ResultCelebrationState extends State<_ResultCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;

  bool get _perfect => widget.total > 0 && widget.correct >= widget.total;

  @override
  void initState() {
    super.initState();
    if (_perfect) {
      AppFeedback.heavy();
    } else if (widget.blind) {
      AppFeedback.medium();
    } else {
      AppFeedback.light();
    }
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (_perfect && !isFlutterTest) _burst.forward();
    if (_perfect && isFlutterTest) _burst.value = 1;
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (_perfect)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _burst,
              builder: (context, _) =>
                  CustomPaint(painter: _BurstPainter(progress: _burst.value)),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: widget.correct),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                '$v/${widget.total}',
                textAlign: TextAlign.center,
                style: AppText.display.copyWith(
                  fontSize: 44,
                  height: 1.1,
                  color: context.inkText,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(widget.sample ? 'room_recalled_sample' : 'room_result_sub'),
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: context.mutedText),
            ),
          ],
        ),
      ],
    );
  }
}

/// 18 small circles flying outward from the center, fading out.
class _BurstPainter extends CustomPainter {
  final double progress;
  _BurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    const colors = [teal, blue, orange, coral];
    final center = size.center(Offset.zero);
    for (var i = 0; i < 18; i++) {
      final angle = i * 2 * 3.1415926535 / 18;
      final frac = ((i * 37) % 10) / 10;
      final dist = (40 + frac * 60) * progress;
      final pos = center + Offset(dist * cos(angle), dist * sin(angle));
      final radius = (6 + frac * 4) * (1 - progress * 0.5);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = colors[i % colors.length].withValues(alpha: 1 - progress),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}

/// The AI wait as a show: desaturated photo with a sweeping scan line,
/// then a 3-row stage list with live SAM counts. No progress bar.
class _ScanStage extends StatefulWidget {
  final String photo;
  final String stage;
  final int samDone;
  final int samTotal;

  /// Live Muse Spark labels (and their aligned normalized boxes) reported
  /// by the round before the SAM loop starts. Empty until they arrive.
  final List<String> labels;
  final List<List<double>> boxes;
  const _ScanStage({
    required this.photo,
    required this.stage,
    required this.samDone,
    required this.samTotal,
    this.labels = const [],
    this.boxes = const [],
  });

  @override
  State<_ScanStage> createState() => _ScanStageState();
}

class _ScanStageState extends State<_ScanStage> with TickerProviderStateMixin {
  static const _grey60 = <double>[
    0.52756,
    0.42912,
    0.04332,
    0,
    0,
    0.12756,
    0.82912,
    0.04332,
    0,
    0,
    0.12756,
    0.42912,
    0.44332,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
  late final AnimationController _sweep;

  /// Staggered pop-in for the live landmark chips (900 ms, one interval
  /// per chip). No timers; jumps to the end under tests.
  late final AnimationController _pop;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Static scan line under tests so pumpAndSettle keeps working.
    if (!isFlutterTest) {
      _sweep.repeat(reverse: true);
    } else {
      _pop.value = 1;
    }
    if (widget.labels.isNotEmpty) _restartPop();
  }

  @override
  void didUpdateWidget(covariant _ScanStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.labels.isNotEmpty &&
        !listEquals(oldWidget.labels, widget.labels)) {
      _restartPop();
    }
  }

  void _restartPop() {
    if (isFlutterTest) {
      _pop.value = 1;
    } else {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _pop.dispose();
    super.dispose();
  }

  /// 0 = prepare, 1 = read, 2 = sam. 'done' lights all three.
  int get _active {
    return switch (widget.stage) {
      'read' => 1,
      'sam' => 2,
      'done' => 3,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final scanning = active < 2;
    final total = widget.samTotal;
    final done = widget.samDone.clamp(0, total == 0 ? 0 : total);
    final labels = widget.labels;
    final labelsArrived = labels.isNotEmpty;
    // Chips sit on real Spark boxes only; without aligned boxes there is
    // nothing honest to point at, so the overlay stays off.
    final showOverlay = labelsArrived && widget.boxes.length == labels.length;
    // The photo wakes up in colour as soon as Muse Spark names landmarks.
    final greyed = scanning && !labelsArrived;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AiImage(
                          imageRef: widget.photo,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedOpacity(
                        opacity: greyed ? 1 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: RepaintBoundary(
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.matrix(_grey60),
                            child: AiImage(
                              imageRef: widget.photo,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showOverlay)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _pop,
                            builder: (context, _) => LayoutBuilder(
                              builder: (context, constraints) {
                                final w = constraints.maxWidth;
                                final h = constraints.maxHeight;
                                final rects = <Rect>[
                                  for (final b in widget.boxes)
                                    Rect.fromLTWH(
                                      b[0] * w,
                                      b[1] * h,
                                      b[2] * w,
                                      b[3] * h,
                                    ),
                                ];
                                // Short labels stay readable; longer ones get
                                // an ellipsis after 16 characters.
                                String shortLabel(String s) => s.length > 16
                                    ? '${s.substring(0, 16)}…'
                                    : s;
                                const chipH = 26.0;
                                const chipGap = 4.0;
                                // Scan chips show the bare label (no walk
                                // number): Spark's order is not the walk
                                // order.
                                final chipW = <double>[
                                  for (var i = 0; i < labels.length; i++)
                                    min(
                                      w * 0.40,
                                      30 + 7.5 * shortLabel(labels[i]).length,
                                    ),
                                ];
                                // Simple collision pass (same idea as
                                // _spreadBadges): a chip overlapping an
                                // earlier chip moves down by chip height + 4,
                                // clamped inside the photo.
                                final chipXY = <Offset>[
                                  for (var i = 0; i < labels.length; i++)
                                    Offset(rects[i].left, rects[i].top),
                                ];
                                for (var i = 0; i < chipXY.length; i++) {
                                  var p = Offset(
                                    chipXY[i].dx.clamp(
                                      0.0,
                                      max(0.0, w - chipW[i]),
                                    ),
                                    chipXY[i].dy.clamp(
                                      0.0,
                                      max(0.0, h - chipH),
                                    ),
                                  );
                                  for (var k = 0; k < i; k++) {
                                    final q = chipXY[k];
                                    final overlaps =
                                        p.dx < q.dx + chipW[k] + chipGap &&
                                        q.dx < p.dx + chipW[i] + chipGap &&
                                        p.dy < q.dy + chipH + chipGap &&
                                        q.dy < p.dy + chipH + chipGap;
                                    if (overlaps) {
                                      p = Offset(
                                        p.dx,
                                        min(
                                          max(0.0, h - chipH),
                                          q.dy + chipH + chipGap,
                                        ),
                                      );
                                    }
                                  }
                                  chipXY[i] = p;
                                }
                                return Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _ScanBoxPainter(
                                          rects: rects,
                                          solid: done,
                                        ),
                                      ),
                                    ),
                                    for (var i = 0; i < labels.length; i++)
                                      Positioned(
                                        left: chipXY[i].dx,
                                        top: chipXY[i].dy,
                                        child: Builder(
                                          builder: (context) {
                                            final t = Interval(
                                              i * 0.12,
                                              min(1.0, i * 0.12 + 0.4),
                                              curve: Curves.easeOutBack,
                                            ).transform(_pop.value);
                                            return Transform.scale(
                                              scale: t,
                                              child: Opacity(
                                                opacity: t.clamp(0.0, 1.0),
                                                child: ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxWidth: w * 0.40,
                                                  ),
                                                  child: _ScanChip(
                                                    text: shortLabel(labels[i]),
                                                    color: _stationColor(i),
                                                    done: done > i,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    if (done > 0)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(done),
                          tween: Tween(begin: 0.6, end: 1.0),
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          builder: (context, t, c) =>
                              Transform.scale(scale: t, child: c),
                          child: AppBadge(
                            label: tr('room_found_n', {'n': '$done'}),
                            color: teal,
                          ),
                        ),
                      ),
                    if (scanning && !labelsArrived)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _sweep,
                          builder: (context, _) => LayoutBuilder(
                            builder: (context, constraints) {
                              final h = constraints.maxHeight;
                              final sweepT = Curves.easeInOut.transform(
                                _sweep.value,
                              );
                              final y = sweepT * h;
                              return Stack(
                                children: [
                                  Positioned(
                                    top: y - 40,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            teal.withValues(alpha: 0),
                                            teal.withValues(alpha: 0.25),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: y - 1.5,
                                    left: 0,
                                    right: 0,
                                    child: Container(height: 3, color: teal),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _stageRow(index: 0, active: active, label: tr('room_stage_prepare')),
        _stageRow(
          index: 1,
          active: active,
          label: tr('room_stage_read'),
          badge: const AppBadge(label: 'Muse Spark', color: blue),
        ),
        _stageRow(
          index: 2,
          active: active,
          label: total == 0
              ? tr('room_stage_sam_idle')
              : tr('room_stage_sam', {'done': done, 'total': total}),
          badge: const AppBadge(label: 'SAM 3.1', color: teal),
        ),
        const SizedBox(height: 8),
        // Fixed height from the start so the Cancel button below never
        // moves when the first ticker line arrives.
        SizedBox(
          height: 20,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: const Interval(0.5, 1),
            switchOutCurve: const Interval(0.5, 1),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: labelsArrived
                ? Padding(
                    key: ValueKey('scan-ticker-$done-${labels.length}'),
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      total > 0
                          ? tr('room_scan_sam_tracing', {
                              'name': labels[done.clamp(0, labels.length - 1)],
                            })
                          : tr('room_scan_spark_found', {'n': labels.length}),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(color: context.mutedText),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('scan-ticker-empty')),
          ),
        ),
        Text(
          tr('room_scan_eta'),
          style: AppText.micro.copyWith(color: context.mutedText),
        ),
      ],
    );
  }

  Widget _stageRow({
    required int index,
    required int active,
    required String label,
    Widget? badge,
  }) {
    final done = active > index || active == 3;
    final isActive = active == index;
    Widget node;
    if (done) {
      node = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        builder: (context, t, _) => Transform.scale(
          scale: t,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: success,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedTick02,
              color: Colors.white,
              size: 14,
            ),
          ),
        ),
      );
    } else if (isActive) {
      node = const AppLoader(size: 20, stroke: 2.5, color: teal);
    } else {
      node = Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.hairline, width: 2),
        ),
      );
    }
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          node,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body.copyWith(
                color: isActive ? context.inkText : context.mutedText,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          if (badge != null) ...[const SizedBox(width: 8), badge],
        ],
      ),
    );
  }
}

/// One live landmark chip on the scan photo: the station-coloured badge.
/// Gets a quick 1.0 → 1.15 → 1.0 scale pulse (220 ms) the moment SAM
/// finishes outlining its station. No timers; completes under tests.
class _ScanChip extends StatefulWidget {
  final String text;
  final Color color;
  final bool done;
  const _ScanChip({
    required this.text,
    required this.color,
    required this.done,
  });

  @override
  State<_ScanChip> createState() => _ScanChipState();
}

class _ScanChipState extends State<_ScanChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void didUpdateWidget(covariant _ScanChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done && !oldWidget.done) {
      if (isFlutterTest) {
        _pulse.value = 1;
      } else {
        _pulse.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final s = 1 + 0.15 * sin(pi * _pulse.value);
        return Transform.scale(scale: s, child: child);
      },
      child: AppBadge(label: widget.text, color: widget.color),
    );
  }
}

/// Live landmark boxes on the scan photo: 2 pt rounded rectangles in the
/// station colour, dashed until SAM outlines the station, solid after.
class _ScanBoxPainter extends CustomPainter {
  final List<Rect> rects;

  /// Indices below [solid] are already outlined by SAM.
  final int solid;
  const _ScanBoxPainter({required this.rects, required this.solid});

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < rects.length; i++) {
      final rect = rects[i];
      if (rect.width <= 0 || rect.height <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _stationColor(i);
      final rrect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(AppRadius.s),
      );
      if (i < solid) {
        canvas.drawRRect(rrect, paint);
        continue;
      }
      final path = Path()..addRRect(rrect);
      const dash = 6.0;
      const gap = 4.0;
      for (final metric in path.computeMetrics()) {
        var d = 0.0;
        while (d < metric.length) {
          canvas.drawPath(
            metric.extractPath(d, min(d + dash, metric.length)),
            paint,
          );
          d += dash + gap;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScanBoxPainter old) {
    return old.solid != solid || old.rects.length != rects.length;
  }
}

/// Cinematic "walk my palace" tour: the camera moves from station to
/// station over the palace photo, one 2200 ms segment each. Only the
/// Transform animates; the photo bitmap sits in a RepaintBoundary and
/// never rebuilds per frame. Tap anywhere advances; the last station
/// offers the recall step. No timers: segments hold until tapped, so
/// tests jump instantly.
/// Decoded SAM mask of one tour station, cached per station index so
/// the 2200 ms camera animation never decodes base64 per frame.
class _TourShape {
  final List<SamMaskRun> runs;
  final int rasterW;
  final int rasterH;
  const _TourShape({
    required this.runs,
    required this.rasterW,
    required this.rasterH,
  });
}

/// The current station's SAM outline (or its box when no mask decoded),
/// drawn in the station colour with a soft glow. Lives inside the same
/// Transform as the photo, so it zooms with it.
class _TourStationPainter extends CustomPainter {
  final Path? outline;
  final Rect box;
  final Color color;
  const _TourStationPainter({
    required this.outline,
    required this.box,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);
    final edge = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (outline != null) {
      canvas.drawPath(outline!, glow);
      canvas.drawPath(outline!, edge);
    } else {
      final rr = RRect.fromRectAndRadius(box, Radius.circular(AppRadius.m));
      canvas.drawRRect(rr, glow);
      canvas.drawRRect(rr, edge);
    }
  }

  @override
  bool shouldRepaint(_TourStationPainter oldDelegate) =>
      oldDelegate.outline != outline ||
      oldDelegate.box != box ||
      oldDelegate.color != color;
}

class _TourPage extends StatefulWidget {
  final RoomPalace palace;
  final Map<int, String> dreams;
  final VoidCallback onDone;
  const _TourPage({
    required this.palace,
    required this.dreams,
    required this.onDone,
  });

  @override
  State<_TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<_TourPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cam;
  int _i = 0;
  bool _finished = false;

  /// Cached SAM shapes per station index (decoded once, never per frame).
  final _tourShapes = <int, _TourShape?>{};

  /// Display-space outline path, rebuilt only when the station or the
  /// photo size changes (not on every animation tick).
  Path? _tourPath;
  int _tourPathFor = -1;
  double _tourPathSize = -1;

  int get _n => widget.palace.stations.length;

  @override
  void initState() {
    super.initState();
    _cam = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (isFlutterTest) {
      _cam.value = 1;
    } else {
      _cam.forward(from: 0);
      AppFeedback.select();
    }
  }

  @override
  void dispose() {
    _cam.dispose();
    super.dispose();
  }

  /// Camera target: the centre of boxes[i] as an Alignment. Without
  /// aligned boxes the camera stays centred on the photo.
  Alignment _alignment(int i) {
    final boxes = widget.palace.boxes;
    if (boxes.length != _n || i < 0 || i >= _n || boxes[i].length < 4) {
      return Alignment.center;
    }
    final b = boxes[i];
    final cx = (b[0] + b[2] / 2).clamp(0.0, 1.0);
    final cy = (b[1] + b[3] / 2).clamp(0.0, 1.0);
    return Alignment(cx * 2 - 1, cy * 2 - 1);
  }

  /// Display-space box of station i on a square photo of side [s].
  /// Boxes are normalised [x, y, w, h]; without one the whole photo
  /// is the fallback.
  Rect _tourBox(int i, double s) {
    final boxes = widget.palace.boxes;
    if (boxes.length == _n && i >= 0 && i < _n && boxes[i].length >= 4) {
      final b = boxes[i];
      return Rect.fromLTWH(b[0] * s, b[1] * s, b[2] * s, b[3] * s);
    }
    return Rect.fromLTWH(0, 0, s, s);
  }

  /// Decoded SAM shape of station i, or null when there is no mask.
  /// Cached: base64 is decoded once per station, never per frame.
  _TourShape? _tourShapeFor(int i) {
    if (_tourShapes.containsKey(i)) return _tourShapes[i];
    _TourShape? out;
    final masks = widget.palace.masks;
    if (i >= 0 && i < masks.length && masks[i].isNotEmpty) {
      final spec = parseSamMaskToken(masks[i]);
      final raster = decodeSamMaskToken(masks[i]);
      if (spec != null && raster != null) {
        final runs = samMaskRuns(raster, spec.width, spec.height);
        if (runs.isNotEmpty) {
          out = _TourShape(
            runs: runs,
            rasterW: spec.width,
            rasterH: spec.height,
          );
        }
      }
    }
    if (_tourShapes.length > 32) _tourShapes.clear();
    _tourShapes[i] = out;
    return out;
  }

  /// Display-space SAM outline for the current station on a square
  /// photo of side [s]; null means the painter falls back to the box.
  Path? _tourOutline(double s) {
    if (_tourPathFor == _i && _tourPathSize == s) return _tourPath;
    _tourPathFor = _i;
    _tourPathSize = s;
    final shape = _tourShapeFor(_i);
    _tourPath = shape == null
        ? null
        : buildSamOutline(
            rect: _tourBox(_i, s),
            runs: shape.runs,
            rasterW: shape.rasterW,
            rasterH: shape.rasterH,
          );
    return _tourPath;
  }

  void _next() {
    if (_finished) return;
    if (_i + 1 >= _n) {
      _finished = true;
      widget.onDone();
      return;
    }
    setState(() => _i++);
    if (isFlutterTest) {
      _cam.value = 1;
    } else {
      _cam.forward(from: 0);
      AppFeedback.select();
    }
  }

  void _done() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final palace = widget.palace;
    final last = _i + 1 >= _n;
    final dream = widget.dreams[_i];
    final hasDream = dream != null && dream.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFF16233B),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 60),
                  Expanded(
                    child: Text(
                      tr('room_tour_btn'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading.copyWith(color: Colors.white),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 60),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          EngramTextButton(
                            label: tr('common_close'),
                            color: Colors.white,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: _next,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: RepaintBoundary(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.xl,
                                ),
                                child: AnimatedBuilder(
                                  animation: _cam,
                                  builder: (context, child) {
                                    final t = Curves.easeInOutCubic.transform(
                                      _cam.value,
                                    );
                                    return Transform.scale(
                                      scale: 1.0 + 1.1 * t,
                                      alignment: _alignment(_i),
                                      child: child,
                                    );
                                  },
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final s = min(
                                        constraints.maxWidth,
                                        constraints.maxHeight.isFinite
                                            ? constraints.maxHeight
                                            : constraints.maxWidth,
                                      );
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          AiImage(
                                            imageRef: palace.imageRef,
                                            fit: BoxFit.cover,
                                          ),
                                          Positioned.fill(
                                            child: RepaintBoundary(
                                              child: CustomPaint(
                                                painter: _TourStationPainter(
                                                  outline: _tourOutline(s),
                                                  box: _tourBox(_i, s),
                                                  color: _stationColor(_i),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (hasDream)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.m,
                                    ),
                                    child: AiImage(
                                      imageRef: dream,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                if (hasDream) const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                    child: Text(
                                      tr('room_tour_line', {
                                        'n': '${_i + 1}',
                                        'station': palace.stations[_i],
                                        'item': palace.items[_i],
                                      }),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.body.copyWith(
                                        color: const Color(0xFF16233B),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (last) ...[
                              const SizedBox(height: 12),
                              EngramButton(
                                label: tr('room_tour_done'),
                                onPressed: _done,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-shot Muse Image reveal: blur + scale + fade over 700 ms, then the
/// plain image (no Opacity left in the settled tree). Only a newly arrived
/// scene is wrapped in this; every other station renders plain pixels.
class _DreamReveal extends StatefulWidget {
  final String imageRef;
  const _DreamReveal({required this.imageRef});

  @override
  State<_DreamReveal> createState() => _DreamRevealState();
}

class _DreamRevealState extends State<_DreamReveal> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done || isFlutterTest) {
      return AiImage(imageRef: widget.imageRef, fit: BoxFit.cover);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (mounted) setState(() => _done = true);
      },
      builder: (context, t, _) => Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 1.06 - 0.06 * t,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 14 * (1 - t),
              sigmaY: 14 * (1 - t),
            ),
            child: AiImage(imageRef: widget.imageRef, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// Screenshot-ready share card: the palace photo with the score over it,
/// the model badges, and clipboard-only sharing. The photo never uploads.
/// "What the AI did": one row per model that worked on this palace,
/// counted from the real MetaAIService call log (never invented).
/// Models with no live calls say "local fallback" honestly.
/// Soft spotlight ring that walks the room during recall, plus the
/// teal answer ripple. Both paint in fractions of the photo, so they
/// stay exact on any photo size.
class _SpotlightPainter extends CustomPainter {
  final Offset centre;
  const _SpotlightPainter({required this.centre});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(centre.dx * size.width, centre.dy * size.height);
    final r = size.width * 0.14;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.centre != centre;
}

/// One-shot teal ripple where a correct answer landed: scale 0.8 → 1.6,
/// opacity 0.5 → 0 over 500 ms.
class _RipplePainter extends CustomPainter {
  final Offset centre;
  final double t;
  const _RipplePainter({required this.centre, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = Offset(centre.dx * size.width, centre.dy * size.height);
    canvas.drawCircle(
      c,
      size.width * 0.14 * (0.8 + 0.8 * t),
      Paint()
        ..color = teal.withValues(alpha: 0.5 * (1 - t))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.centre != centre || oldDelegate.t != t;
}

class _ReceiptCard extends StatelessWidget {
  final List<MetaCallEntry> log;
  final RoomPalace palace;
  const _ReceiptCard({required this.log, required this.palace});

  /// Entries of one pipeline step ([kind]) logged since the palace scan.
  List<MetaCallEntry> _since(String kind) => [
    for (final e in log)
      if (e.kind == kind && !e.at.isBefore(palace.createdAt)) e,
  ];

  String _callsLine(List<MetaCallEntry> entries) {
    final live = entries.where((e) => !e.fallback).length;
    final fb = entries.where((e) => e.fallback).length;
    if (live > 0 && fb > 0) {
      return '${tr('room_receipt_live', {'n': '$live'})} · '
          '${tr('room_receipt_fb', {'n': '$fb'})}';
    }
    if (live > 0) return tr('room_receipt_live', {'n': '$live'});
    if (fb > 0) return tr('room_receipt_fb', {'n': '$fb'});
    return tr('room_receipt_local');
  }

  Widget _row(
    BuildContext context, {
    required String model,
    required Color color,
    required List<MetaCallEntry> entries,
    required String produced,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppBadge(label: model, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _callsLine(entries),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.micro.copyWith(color: context.mutedText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          produced,
          style: AppText.body.copyWith(
            color: context.inkText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final spark = _since('picture-objects');
    final sam = _since('segment');
    final image = _since('image');
    final sparkLive = spark.any((e) => !e.fallback);
    final samLive = sam.any((e) => !e.fallback);
    final imageLive = image.any((e) => !e.fallback);
    final outlines = palace.masks.where((m) => m.isNotEmpty).length;
    final scenes = palace.dreams.where((d) => d.isNotEmpty).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('room_receipt_btn'),
          textAlign: TextAlign.center,
          style: AppText.heading.copyWith(color: context.inkText),
        ),
        const SizedBox(height: 16),
        _row(
          context,
          model: 'Muse Spark',
          color: blue,
          entries: spark,
          produced: palace.live && sparkLive
              ? tr('room_receipt_landmarks', {'n': '${palace.stations.length}'})
              : tr('room_receipt_local'),
        ),
        const SizedBox(height: 12),
        _row(
          context,
          model: 'SAM 3.1',
          color: teal,
          entries: sam,
          produced: samLive && outlines > 0
              ? tr('room_receipt_outlines', {'n': '$outlines'})
              : tr('room_receipt_local'),
        ),
        const SizedBox(height: 12),
        _row(
          context,
          model: 'Muse Image',
          color: orange,
          entries: image,
          produced: imageLive && scenes > 0
              ? tr('room_receipt_scenes', {'n': '$scenes'})
              : tr('room_receipt_local'),
        ),
        const SizedBox(height: 16),
        Center(
          child: EngramTextButton(
            label: tr('common_close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _ShareCard extends StatelessWidget {
  final RoomPalace palace;
  final int correct;
  const _ShareCard({required this.palace, required this.correct});

  @override
  Widget build(BuildContext context) {
    final total = palace.items.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MaskedPicture(
                        imageUrl: palace.imageRef,
                        scene: '',
                        objects: palace.stations,
                        boxes: palace.boxes.length == palace.stations.length
                            ? palace.boxes
                            : const <List<double>>[],
                        masks: palace.masks.length == palace.stations.length
                            ? palace.masks
                            : const <String>[],
                        revealed: const {},
                        masked: false,
                        highlight: true,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0),
                              Colors.black.withValues(alpha: 0.72),
                            ],
                          ),
                        ),
                        child: Text(
                          tr(
                            palace.sample
                                ? 'room_share_title_sample'
                                : 'room_share_title',
                            {'correct': '$correct', 'total': '$total'},
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const AppBadge(label: 'Muse Spark', color: blue),
            const AppBadge(label: 'SAM 3.1', color: teal),
            const AppBadge(label: 'Muse Image', color: orange),
            Text(
              'Engrammo',
              style: AppText.micro.copyWith(color: context.mutedText),
            ),
          ],
        ),
        const SizedBox(height: 16),
        EngramButton(
          label: tr('room_share_copy'),
          variant: EngramButtonVariant.secondary,
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: tr(
                  palace.sample ? 'room_share_text_sample' : 'room_share_text',
                  {'correct': '$correct', 'total': '$total'},
                ),
              ),
            );
            AppFeedback.light();
            if (context.mounted) {
              showAppToast(
                context,
                tr('common_copied'),
                kind: ToastKind.success,
              );
            }
          },
        ),
        Center(
          child: EngramTextButton(
            label: tr('common_close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('room_share_private'),
          textAlign: TextAlign.center,
          style: AppText.micro.copyWith(color: context.mutedText),
        ),
      ],
    );
  }
}
