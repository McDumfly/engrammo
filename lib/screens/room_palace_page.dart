import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../models/fsrs_card.dart';
import '../models/meta_image.dart';
import '../models/palace_drill.dart' show matchRecallAnswer;
import '../models/room_palace.dart';
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../services/room_photo.dart';
import '../theme/app_colors.dart' show blueDark, coral, teal;
import '../theme/app_theme.dart';
import '../widgets/ai_image.dart';
import '../widgets/app_buttons.dart'
    show EngramBackButton, EngramButton, EngramButtonVariant;
import 'benchmark.dart' show BenchmarkStore, MaskedPicture;

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
  double _progress = 0;
  String _stage = 'image';
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
  final _guessCtrl = TextEditingController();
  String _feedback = '';
  bool _feedbackGood = false;
  bool _awaitNext = false;
  bool _rescheduled = false;
  DateTime? _nextDue;

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
    _itemsCtrl.dispose();
    _guessCtrl.dispose();
    super.dispose();
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
    setState(() {
      _palaces = list;
      _ready = true;
      _photo = found!.imageRef;
      _stations = found.stations;
      _boxes = found.boxes;
      _masks = found.masks;
      _live = found.live;
      _imageFailed = false;
      _coverVersion++;
      _palace = found;
      _resetRecall();
      _rescheduled = false;
      _nextDue = null;
      _step = _Step.recall;
    });
  }

  void _resetRecall() {
    _cue = 0;
    _correct = 0;
    _revealed = {};
    _feedback = '';
    _feedbackGood = false;
    _awaitNext = false;
    _guessCtrl.clear();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
        _progress = 0;
        _stage = 'image';
        _imageFailed = false;
        _step = _Step.scanning;
      });
      _scan(url, token);
    } catch (_) {
      if (!mounted) return;
      _snack(tr('common_save_failed'));
    }
  }

  Future<void> _scan(String dataUrl, int token) async {
    final round = await MetaAIService.pictureRecallRound(
      seed: 'room:${DateTime.now().millisecondsSinceEpoch}',
      count: 6,
      locale: AppLocalizations.localeCode,
      imageRefOverride: dataUrl,
      sceneOverride: 'a real photo of the learner\'s own room or desk',
      onProgress: (p, stage) {
        if (!mounted || token != _token) return;
        setState(() {
          _progress = p;
          _stage = stage;
        });
      },
    );
    if (!mounted || token != _token) return;
    final aiOk =
        round.live && round.imageUrl == dataUrl && round.objects.length >= 2;
    if (aiOk) {
      setState(() {
        _stations = round.objects;
        _boxes = round.boxes;
        _masks = round.masks;
        _live = true;
        _coverVersion++;
        _step = _Step.items;
      });
    } else {
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
      _snack(tr('room_no_stations'));
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

  Future<void> _startDreams(RoomPalace palace, int token) async {
    if (!palace.live) return;
    for (var i = 0; i < palace.items.length; i++) {
      if (!mounted || token != _token) return;
      final link = i < palace.links.length ? palace.links[i] : palace.items[i];
      final img = await MetaAIService.generateImage(
        MetaImageRequest(
          prompt: MetaAIService.roomDreamPrompt(
            palace.stations[i],
            palace.items[i],
            link,
          ),
          style: 'room-dream',
        ),
      );
      if (!mounted || token != _token) return;
      setState(() => _dreams[i] = img.fallback ? '' : img.url);
    }
  }

  void _check() {
    final palace = _palace;
    if (palace == null || _awaitNext) return;
    final items = palace.items;
    if (_cue < 0 || _cue >= items.length) return;
    final others = {
      for (var i = 0; i < items.length; i++)
        if (i != _cue) i,
    };
    final hit = matchRecallAnswer(_guessCtrl.text, items, others);
    if (hit == _cue) {
      final correct = _correct + 1;
      final revealed = {..._revealed, _cue};
      final feedback = tr('room_correct', {'item': items[_cue]});
      final last = _cue + 1 >= items.length;
      setState(() {
        _correct = correct;
        _revealed = revealed;
        _feedback = feedback;
        _feedbackGood = true;
        _guessCtrl.clear();
        if (!last) {
          _cue++;
        }
      });
      if (last) {
        setState(() => _step = _Step.result);
        _finishRun();
      }
      return;
    }
    final elsewhere = matchRecallAnswer(_guessCtrl.text, items, {});
    setState(() {
      _feedbackGood = false;
      _feedback = elsewhere >= 0 && elsewhere != _cue
          ? tr('room_elsewhere', {'n': elsewhere + 1})
          : tr('room_wrong');
    });
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
      _feedback = '${tr('room_wrong')} $link';
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(tr('room_delete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('common_delete')),
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
        title: Text(
          tr('room_title'),
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(top: false, child: _body()),
    );
  }

  Widget _body() {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
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
      children: children,
    );
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    );
  }

  Widget _muted(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(color: context.mutedText, fontSize: 14),
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
  }) {
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
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        ),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AiImage(
                    imageRef: p.imageRef,
                    height: 56,
                    width: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomPalaceName(p),
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                        style: TextStyle(
                          color: context.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
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
                      _resetRecall();
                      _rescheduled = false;
                      _nextDue = null;
                      _step = _Step.recall;
                    });
                  },
                  child: Text(tr('room_review_btn')),
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
      _header(tr('room_title')),
      _muted(tr('room_sub')),
      _muted(tr('room_science')),
      const SizedBox(height: 4),
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
      Text(
        tr('room_privacy'),
        style: TextStyle(color: context.mutedText, fontSize: 12),
      ),
    ]);
  }

  String _stageText() {
    return switch (_stage) {
      'image' => tr('room_stage_prepare'),
      'read' => tr('room_stage_read'),
      _ => tr('room_stage_sam'),
    };
  }

  Widget _scanningStep() {
    return _page([
      _header(tr('room_title')),
      _covers(
        imageUrl: _photo,
        objects: const [],
        boxes: const [],
        masks: const [],
        revealed: const {},
        masked: false,
      ),
      const SizedBox(height: 16),
      LinearProgressIndicator(value: _progress),
      const SizedBox(height: 8),
      Center(
        child: Text(
          _stageText(),
          style: TextStyle(color: context.mutedText, fontSize: 14),
        ),
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
      ),
      const SizedBox(height: 12),
      Text(
        tr('room_stations_found', {'count': _stations.length}),
        style: TextStyle(
          color: context.inkText,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      const SizedBox(height: 6),
      for (var i = 0; i < _stations.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            tr('room_station_n', {'n': i + 1, 'name': _stations[i]}),
            style: TextStyle(color: context.mutedText, fontSize: 14),
          ),
        ),
      const SizedBox(height: 12),
      TextField(
        controller: _itemsCtrl,
        minLines: 4,
        maxLines: 8,
        maxLength: 600,
        decoration: InputDecoration(
          hintText: tr('room_items_hint', {'count': _stations.length}),
          border: const OutlineInputBorder(),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {
            setState(() => _itemsCtrl.text = tr('room_sample_items'));
          },
          child: Text(tr('room_items_sample')),
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
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < palace.items.length; i++) _stationCard(palace, i),
      const SizedBox(height: 8),
      EngramButton(
        label: tr('room_walk_btn'),
        onPressed: () {
          AppFeedback.light();
          setState(() {
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
    final dream = _dreams[i];
    final link = i < palace.links.length ? palace.links[i] : palace.items[i];
    return GestureDetector(
      onTap: () => setState(() => _focus = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: focused ? blueDark : context.hairline,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('room_station_n', {'n': i + 1, 'name': palace.stations[i]}),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              palace.items[i],
              style: TextStyle(
                color: context.inkText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(link, style: TextStyle(color: context.inkText, fontSize: 14)),
            if (dream != null && dream.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AiImage(imageRef: dream, height: 160, fit: BoxFit.cover),
              ),
            ] else if (dream == null && palace.live) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('room_dream_loading'),
                      style: TextStyle(color: context.mutedText, fontSize: 13),
                    ),
                  ),
                ],
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
      _covers(
        imageUrl: palace.imageRef,
        objects: palace.items,
        boxes: palace.boxes,
        masks: palace.masks,
        revealed: _revealed,
        masked: true,
        cue: done ? -1 : _cue,
      ),
      const SizedBox(height: 12),
      if (!done) ...[
        Text(
          tr('room_recall_prompt', {'n': _cue + 1}),
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _guessCtrl,
          onSubmitted: (_) => _check(),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        if (_feedback.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _feedback,
              style: TextStyle(
                color: _feedbackGood ? teal : coral,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
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
      ],
    ]);
  }

  Widget _resultStep() {
    final palace = _palace;
    if (palace == null) return _page([_header(tr('room_title'))]);
    final total = palace.items.length;
    return _page([
      _header(tr('room_title')),
      Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedCastle01,
          color: blueDark,
          size: 56,
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          tr('room_result', {'correct': _correct, 'total': total}),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      if (_nextDue != null) ...[
        const SizedBox(height: 8),
        Center(
          child: Text(
            tr('room_next_review', {
              'date': MaterialLocalizations.of(context)
                  .formatShortDate(_nextDue!),
            }),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.mutedText, fontSize: 14),
          ),
        ),
      ],
      const SizedBox(height: 16),
      EngramButton(
        label: tr('room_review_btn'),
        variant: EngramButtonVariant.secondary,
        onPressed: () {
          AppFeedback.light();
          setState(() {
            _resetRecall();
            _step = _Step.recall;
          });
        },
      ),
      const SizedBox(height: 10),
      EngramButton(
        label: tr('common_close'),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ]);
  }
}
