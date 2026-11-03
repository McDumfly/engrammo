import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/meta_ai_service.dart';

class MetaCallLogView extends StatefulWidget {
  const MetaCallLogView({super.key});

  @override
  State<MetaCallLogView> createState() => _MetaCallLogViewState();
}

class _MetaCallLogViewState extends State<MetaCallLogView> {
  late final Future<List<MetaCallEntry>> _future = MetaAIService.loadLog();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        final calls = snapshot.data ?? MetaAIService.lastCalls;
        if (calls.isEmpty) {
          return Text(tr('metalog_empty'));
        }
        // Per-model live/local summary, most live calls first.
        final liveByModel = <String, int>{};
        final localByModel = <String, int>{};
        for (final c in calls) {
          if (c.success && !c.fallback) {
            liveByModel[c.model] = (liveByModel[c.model] ?? 0) + 1;
          } else {
            localByModel[c.model] = (localByModel[c.model] ?? 0) + 1;
          }
        }
        final models =
            <String>{...liveByModel.keys, ...localByModel.keys}.toList()..sort(
              (a, b) => (liveByModel[b] ?? 0).compareTo(liveByModel[a] ?? 0),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('meta_proof_title'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final model in models)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        model,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                    Text(
                      tr('meta_proof_counts', {
                        'live': liveByModel[model] ?? 0,
                        'local': localByModel[model] ?? 0,
                      }),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            for (final c in calls.take(10))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${c.at.toIso8601String()} • ${c.model} • '
                  '${c.kind} • ${c.success ? tr('metalog_ok') : tr('metalog_error')} • '
                  '${c.fallback ? tr('metalog_fallback') : tr('metalog_live')}'
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
