import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/active_palace.dart';
import '../models/room_palace.dart' show RoomPalace, roomPalaceName;
import '../screens/room_palace_page.dart' show RoomPalacePage;
import '../services/active_palace_store.dart';
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../theme/app_colors.dart' show blue, teal;
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'ai_image.dart';
import 'app_buttons.dart';
import 'app_kit.dart';

/// Palace picker: the learner's rooms plus the three named practice
/// palaces. The choice is lesson-only (duels stay generic) and is
/// persisted with [ActivePalaceStore.setId].
Future<void> showPalacePicker(BuildContext context) {
  return showAppSheet<void>(
    context,
    builder: (_) => const _PalacePickerSheet(),
  );
}

class _PalacePickerSheet extends StatefulWidget {
  const _PalacePickerSheet();

  @override
  State<_PalacePickerSheet> createState() => _PalacePickerSheetState();
}

class _PalacePickerSheetState extends State<_PalacePickerSheet> {
  List<RoomPalace> _rooms = const [];
  String? _selected;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final rooms = await MemoryStore.loadRoomPalaces();
      final current = await ActivePalaceStore.load(AppLocalizations.localeCode);
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _selected = current?.id;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _pick(String id) async {
    AppFeedback.select();
    await ActivePalaceStore.setId(id);
    if (!mounted) return;
    setState(() => _selected = id);
    Navigator.of(context).maybePop();
  }

  Future<void> _openBuilder() async {
    AppFeedback.select();
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RoomPalacePage()));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              children: [
                if (_loaded && _rooms.isNotEmpty) ...[
                  Text(
                    tr('palace_picker_rooms'),
                    style: AppText.heading.copyWith(color: context.inkText),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 148,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _rooms.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _roomThumb(_rooms[i]),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  tr('palace_picker_practice'),
                  style: AppText.heading.copyWith(color: context.inkText),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < 3; i++) ...[
                  _practiceCard(i),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: EngramButton(
              label: tr('palace_build_own'),
              onPressed: _openBuilder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomThumb(RoomPalace room) {
    final selected = _selected == room.id;
    return Tappable(
      haptic: false,
      semanticLabel: roomPalaceName(room, AppLocalizations.localeCode),
      onTap: () => _pick(room.id),
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(
                  color: selected ? blue : context.hairline,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.m),
                child: AiImage(imageRef: room.imageRef, width: 96, height: 96),
              ),
            ),
            const SizedBox(height: 4),
            if (room.sample)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: AppBadge(label: tr('palace_sample_title'), color: teal),
              ),
            Text(
              tr('bench_stations_n', {'n': room.stations.length}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: context.mutedText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _practiceCard(int index) {
    final locale = AppLocalizations.localeCode;
    final palace = ActivePalace.fromRoute(index, locale);
    final selected = _selected == palace.id;
    return Tappable(
      haptic: false,
      semanticLabel: tr('palace_practice_title', {'name': palace.title}),
      onTap: () => _pick(palace.id),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.m),
          border: Border.all(
            color: selected ? blue : context.hairline,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('palace_practice_title', {'name': palace.title}),
              style: AppText.heading.copyWith(color: context.inkText),
            ),
            const SizedBox(height: 12),
            _dotsStrip(),
            const SizedBox(height: 8),
            Text(
              palace.stations.take(6).join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: context.mutedText),
            ),
          ],
        ),
      ),
    );
  }

  /// Six numbered dots joined by a dotted line, the learning-path look.
  Widget _dotsStrip() {
    return Row(
      children: [
        for (var i = 0; i < 6; i++) ...[
          if (i > 0)
            Expanded(
              child: CustomPaint(
                painter: _DottedPainter(color: context.washBorder),
                child: const SizedBox(height: 24),
              ),
            ),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.washBg,
              shape: BoxShape.circle,
              border: Border.all(color: context.washBorder, width: 2),
            ),
            child: Text(
              '${i + 1}',
              style: TextStyle(
                color: context.inkText,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DottedPainter extends CustomPainter {
  final Color color;
  const _DottedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const step = 8.0;
    final y = size.height / 2;
    for (var x = 4.0; x < size.width - 2; x += step) {
      canvas.drawLine(Offset(x, y), Offset(x + 3, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedPainter old) => old.color != color;
}
