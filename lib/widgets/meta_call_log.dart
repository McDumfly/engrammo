import 'package:flutter/material.dart';

import '../services/meta_ai_service.dart';

/// Verseny-demó megfigyelhetőség: utolsó Meta-hívások listája.
///
/// Best-effort: üres állapotban egy mondatos magyarázatot mutat
/// (nincs API-kulcs / még nem futott hívás). Nem dob hibát offline.
class MetaCallLogView extends StatelessWidget {
  const MetaCallLogView({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: MetaAIService.loadLog(),
      builder: (context, snapshot) {
        final calls =
            snapshot.data ?? MetaAIService.lastCalls;
        if (calls.isEmpty) {
          return const Text(
            'Még nem futott Meta-hívás. Offline módban a helyi '
            'generátorok adják a tartalmat.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in calls.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${c.at.toIso8601String()} • ${c.model} • '
                  '${c.kind} • ${c.success ? "ok" : "hiba"} • '
                  '${c.fallback ? "fallback" : "élő"}'
                  '${c.note.isEmpty ? "" : " • ${c.note}"}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        );
      },
    );
  }
}
