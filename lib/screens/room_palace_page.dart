import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
import 'benchmark.dart' show BenchmarkStore, MaskedPicture;

/// Station colour cycle, matching the highlight fills.
Color _stationColor(int i) {
  const cycle = [teal, blue, orange, coral];
  return cycle[i % cycle.length];
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

enum _Step { list, capture, scanning, items, encode, recall, result }

class _RoomPalacePageState extends State<RoomPalacePage> {
  _Step _step = _Step.capture;
  int _token = 0;
  bool _ready = false;

  List<RoomPalace> _palaces = [];

  // Scan state.
  String _photo = '';
  String _stage = 'image';
  int _samDone = 0;
  int _samTotal = 0;
  List<String> _stations = [];
  List<List<double>> _boxes = [];
  List<String> _masks = [];
  bool _live = false;
  bool _imageFailed = false;
  int _coverVersion = 0;

  // Items + encode state.
  final _itemsCtrl = TextEditingController();
  bool _building = false;
  RoomPalace? _palace;
  int _focus = 0;
  final Map<int, String> _dreams = {};

  // Recall state.
  int _cue = 0;
  int _correct = 0;
  Set<int> _revealed = {};
  Set<int> _correctIdx = {};
  final _guessCtrl = TextEditingController();
  String _feedback = '';
  bool _feedbackGood = false;
  bool _awaitNext = false;
  bool _judging = false;
  bool _blind = false;
  bool _rescheduled = false;
  DateTime? _nextDue;
  String? _popDream;
  Timer? _popTimer;

  @override
  void initState() {
    super.initState();
    final reviewId = widget.reviewId;
    if (reviewId != null) {
      _openReview(reviewId);
    } else {
      _loadList();
    }
  }

  @override
  void dispose() {
    _token++;
    _popTimer?.cancel();
    _itemsCtrl.dispose();
    _guessCtrl.dispose();
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
    if (!mounted || token != _token) return;
    setState(() {
      _palaces = list;
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
        }
      }
      _rescheduled = false;
      _nextDue = null;
      _step = _Step.recall;
    });
  }

  void _resetRecall() {
    _cue = 0;
    _correct = 0;
    _revealed = {};
    _correctIdx = {};
    _feedback = '';
    _feedbackGood = false;
    _awaitNext = false;
    _popTimer?.cancel();
    _popDream = null;
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
        _stage = 'image';
        _samDone = 0;
        _samTotal = 0;
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

  /// Cancel (and blocked back navigation) while scanning: drop the
  /// in-flight round and go back to capture.
  void _cancelScan() {
    AppFeedback.light();
    _token++;
    if (!mounted) return;
    setState(() {
      _stage = 'image';
      _samDone = 0;
      _samTotal = 0;
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
          setState(() {
            _samDone = done;
            _samTotal = total;
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
      );
      await MemoryStore.upsertRoomPalace(palace);
      if (!mounted || token != _token) return;
      setState(() {
        _palace = palace;
        _focus = 0;
        _dreams.clear();
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
    final count = palace.stations.length;
    final dreams = List<String>.filled(count, '');
    final current = _palace;
    if (current != null &&
        current.id == palace.id &&
        current.dreams.length == count) {
      for (var k = 0; k < count; k++) {
        dreams[k] = current.dreams[k];
      }
    }
    _dreams.forEach((k, v) {
      if (k >= 0 && k < count) dreams[k] = v;
    });
    dreams[i] = stored;
    final base = (current != null && current.id == palace.id)
        ? current
        : palace;
    final updated = base.copyWith(dreams: dreams);
    await MemoryStore.upsertRoomPalace(updated);
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
    setState(() => _dreams.remove(i));
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
      setState(() {
        _feedbackGood = false;
        _feedback = tr('room_wrong');
      });
    }
  }

  void _markCorrect(int cue, int token, {required String feedback}) {
    final palace = _palace;
    if (palace == null || !mounted || token != _token || cue != _cue) return;
    AppFeedback.select();
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
      if (!last) {
        _cue++;
      }
    });
    showAppToast(context, tr('room_correct'), kind: ToastKind.success);
    if (_popDream != null) {
      _popTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        setState(() => _popDream = null);
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
    if (!mounted || token != _token) return;
    setState(() {
      _palaces = _palaces.where((e) => e.id != p.id).toList();
      if (_palaces.isEmpty) _step = _Step.capture;
    });
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
      canPop: _step != _Step.scanning,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelScan();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppTopBar(
          title: tr('room_title'),
          leading: const EngramBackButton(),
        ),
        resizeToAvoidBottomInset: !recallBar,
        body: SafeArea(top: false, child: _body()),
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
              if (_popDream != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    builder: (context, t, c) =>
                        Transform.scale(scale: t, child: c),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      child: AiImage(
                        imageRef: _popDream!,
                        height: 120,
                        width: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              AppTextField(
                controller: _guessCtrl,
                autofocus: true,
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
      _Step.encode => _encodeStep(),
      _Step.recall => _recallStep(),
      _Step.result => _resultStep(),
    };
  }

  Widget _page(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
  }) {
    // No stations yet (or nothing survived filtering): a plain photo,
    // never an empty MaskedPicture.
    if (objects.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
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
        constraints: const BoxConstraints(maxWidth: 380),
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
      _imageFailed = false;
      _coverVersion++;
      _palace = p;
      _blind = false;
      _resetRecall();
      for (var i = 0; i < p.dreams.length; i++) {
        if (p.dreams[i].isNotEmpty) _dreams[i] = p.dreams[i];
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
        GestureDetector(
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
                        roomPalaceName(p),
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
                        child: AppBadge(
                          label: tr(
                            p.live ? 'room_badge_live' : 'room_badge_local',
                          ),
                          color: p.live ? teal : blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                EngramTextButton(
                  label: tr('room_review_btn'),
                  onPressed: () => _reviewPalace(p),
                ),
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
      const _CapturePreview(),
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
      const SizedBox(height: 12),
      AppDisclosure(
        title: Text(tr('room_science_title')),
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

  Widget _scanningStep() {
    return _page([
      _header(tr('room_title')),
      _ScanStage(
        photo: _photo,
        stage: _stage,
        samDone: _samDone,
        samTotal: _samTotal,
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
      const SizedBox(height: 12),
      AppTextField(
        controller: _itemsCtrl,
        label: tr('room_items_label'),
        hint: tr('room_items_hint', {'count': _stations.length}),
        minLines: 4,
        maxLines: 8,
        maxLength: 600,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: EngramTextButton(
          label: tr('room_items_sample'),
          onPressed: () {
            setState(() => _itemsCtrl.text = tr('room_sample_items'));
          },
        ),
      ),
      const SizedBox(height: 4),
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
    ]);
  }

  Widget _encodeStep() {
    final palace = _palace;
    if (palace == null) return _page([_header(tr('room_title'))]);
    return _page([
      _header(tr('room_title')),
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
                  child: AiImage(imageRef: dream, fit: BoxFit.cover),
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
                                    tr('room_dream_loading'),
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

  Widget _recallStep() {
    final palace = _palace;
    if (palace == null || palace.items.isEmpty) {
      return _page([_header(tr('room_title'))]);
    }
    final done = _cue >= palace.items.length;
    return _page([
      _header(tr('room_title')),
      if (_blind && !done)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.hairline, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('room_blind_tip'),
                style: AppText.caption.copyWith(color: context.mutedText),
              ),
              const SizedBox(height: 12),
              Text(
                tr('room_station_n', {
                  'n': _cue + 1,
                  'name': palace.stations[_cue],
                }),
                style: AppText.title.copyWith(color: context.inkText),
              ),
            ],
          ),
        )
      else
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
          ),
        ),
      const SizedBox(height: 12),
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
      _ResultCelebration(correct: _correct, total: total),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          AppBadge(label: '+$xp XP', color: orange),
          if (_nextDue != null)
            AppBadge(
              label: tr('room_next_review', {
                'date': MaterialLocalizations.of(context)
                    .formatShortDate(_nextDue!),
              }),
              color: blue,
            ),
        ],
      ),
      const SizedBox(height: 16),
      EngramButton(
        label: tr('common_done'),
        onPressed: () => Navigator.of(context).pop(),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: Center(
              child: EngramTextButton(
                label: tr('room_blind_btn'),
                onPressed: () {
                  AppFeedback.light();
                  setState(() {
                    _blind = true;
                    _resetRecall();
                    _rescheduled = false;
                    _nextDue = null;
                    _step = _Step.recall;
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: EngramTextButton(
                label: tr('room_recall_again'),
                onPressed: () {
                  AppFeedback.light();
                  setState(() {
                    _blind = false;
                    _resetRecall();
                    _step = _Step.recall;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    ]);
  }
}

/// Result score with a count-up number and, on a perfect run, a burst
/// of 18 particles. Fires the result haptic once on first build.
class _ResultCelebration extends StatefulWidget {
  final int correct;
  final int total;
  const _ResultCelebration({required this.correct, required this.total});

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
              tr('room_result_sub'),
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: context.mutedText),
            ),
          ],
        ),
        if (_perfect)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _burst,
              builder: (context, _) =>
                  CustomPaint(painter: _BurstPainter(progress: _burst.value)),
            ),
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

/// 1:1 dark preview of what the learner gets: four furniture silhouettes
/// fading in one after another, then breathing gently.
class _CapturePreview extends StatefulWidget {
  const _CapturePreview();

  @override
  State<_CapturePreview> createState() => _CapturePreviewState();
}

class _CapturePreviewState extends State<_CapturePreview>
    with TickerProviderStateMixin {
  late final AnimationController _stagger;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300 + 120 * 3),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    // A repeating ticker never settles: static preview under tests.
    if (!isFlutterTest) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _stagger.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF16233B), Color(0xFF0E3B4A)],
                ),
              ),
              child: AnimatedBuilder(
                animation: Listenable.merge([_stagger, _pulse]),
                builder: (context, _) {
                  final elapsed =
                      _stagger.value * _stagger.duration!.inMilliseconds;
                  final breath = 0.3 + 0.15 * _pulse.value;
                  return CustomPaint(
                    painter: _PreviewPainter(
                      opacities: [
                        for (var i = 0; i < 4; i++)
                          Curves.easeOutCubic.transform(
                                ((elapsed - i * 120) / 300).clamp(0.0, 1.0),
                              ) *
                              breath,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four furniture silhouettes with numbered badges, drawn on the
/// capture preview card.
class _PreviewPainter extends CustomPainter {
  final List<double> opacities;
  _PreviewPainter({required this.opacities});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shapes = [
      (teal, Rect.fromLTWH(0.06 * w, 0.69 * h, 0.40 * w, 0.25 * h)),
      (blue, Rect.fromLTWH(0.62 * w, 0.60 * h, 0.32 * w, 0.22 * h)),
      (coral, Rect.fromLTWH(0.06 * w, 0.08 * h, 0.30 * w, 0.16 * h)),
      (orange, Rect.fromLTWH(0.76 * w, 0.08 * h, 0.16 * w, 0.22 * h)),
    ];
    for (var i = 0; i < shapes.length; i++) {
      final color = shapes[i].$1;
      final rect = shapes[i].$2;
      final ease = (i < opacities.length ? opacities[i] : 0.38) / 0.45;
      final op = i < opacities.length ? opacities[i] : 0.38;
      if (op <= 0) continue;
      final r = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      canvas.drawRRect(r, Paint()..color = color.withValues(alpha: op));
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (ease * 0.9).clamp(0.0, 1.0)),
      );
      final c = rect.center;
      canvas.drawCircle(
        c,
        13,
        Paint()..color = Colors.white.withValues(alpha: ease.clamp(0.0, 1.0)),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) {
    if (old.opacities.length != opacities.length) return true;
    for (var i = 0; i < opacities.length; i++) {
      if (old.opacities[i] != opacities[i]) return true;
    }
    return false;
  }
}

/// The AI wait as a show: desaturated photo with a sweeping scan line,
/// then a 3-row stage list with live SAM counts. No progress bar.
class _ScanStage extends StatefulWidget {
  final String photo;
  final String stage;
  final int samDone;
  final int samTotal;
  const _ScanStage({
    required this.photo,
    required this.stage,
    required this.samDone,
    required this.samTotal,
  });

  @override
  State<_ScanStage> createState() => _ScanStageState();
}

class _ScanStageState extends State<_ScanStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    // Static scan line under tests so pumpAndSettle keeps working.
    if (!isFlutterTest) _sweep.repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweep.dispose();
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
                child: AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, constraints) {
                      final h = constraints.maxHeight;
                      final sweepT = Curves.easeInOut.transform(_sweep.value);
                      final y = sweepT * h;
                      Widget photo = AiImage(
                        imageRef: widget.photo,
                        fit: BoxFit.cover,
                      );
                      if (scanning) {
                        photo = ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
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
                          ]),
                          child: photo,
                        );
                      }
                      return Stack(
                        children: [
                          Positioned.fill(child: photo),
                          if (scanning) ...[
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
                        ],
                      );
                    },
                  ),
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
          label: tr('room_stage_sam', {'done': done, 'total': total}),
          badge: const AppBadge(label: 'SAM 3.1', color: teal),
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
