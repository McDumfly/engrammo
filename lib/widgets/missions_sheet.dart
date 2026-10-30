import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/claims_policy.dart' show honestPromise;
import '../models/curriculum.dart' show memoryTracks;
import '../models/transfer_missions.dart'
    show TransferMission, missionsForTrack;
import '../services/memory_store.dart';
import '../theme/app_theme.dart';

Future<void> showMissionsSheet(BuildContext context, int track) {
  final t = track.clamp(0, memoryTracks.length - 1);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _MissionsSheet(track: t),
  );
}

class _MissionsSheet extends StatefulWidget {
  final int track;
  const _MissionsSheet({required this.track});

  @override
  State<_MissionsSheet> createState() => _MissionsSheetState();
}

class _MissionsSheetState extends State<_MissionsSheet> {
  Set<String> _done = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final done = await MemoryStore.loadDoneMissions();
      if (!mounted) return;
      setState(() {
        _done = done;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loaded = true);
    }
  }

  Future<void> _toggle(TransferMission mission, bool done) async {
    setState(() {
      if (done) {
        _done.add(mission.id);
      } else {
        _done.remove(mission.id);
      }
    });
    await MemoryStore.saveMissionDone(mission.id, done: done);
  }

  @override
  Widget build(BuildContext context) {
    final missions = missionsForTrack(widget.track);
    final doneCount = missions.where((m) => _done.contains(m.id)).length;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.washBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr('missions_title', {
                'track': tr('track_${widget.track}_name'),
              }),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr('missions_progress', {
                'done': doneCount,
                'total': missions.length,
              }),
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (final mission in missions) _missionCard(mission),
            const SizedBox(height: 8),
            Text(
              honestPromise,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
            if (!_loaded) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _missionCard(TransferMission mission) {
    final done = _done.contains(mission.id);
    final code = AppLocalizations.localeCode;
    final steps = mission.stepsIn(code);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.washBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.titleIn(code),
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mission.source,
                      style: TextStyle(color: context.mutedText, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: done,
                onChanged: (v) => _toggle(mission, v ?? false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mission.briefingIn(code),
            style: TextStyle(color: context.inkText, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${i + 1}. ${steps[i]}',
                style: TextStyle(color: context.inkText, fontSize: 13),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            tr('missions_selfcheck', {'text': mission.selfCheckIn(code)}),
            style: TextStyle(
              color: context.mutedText,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
