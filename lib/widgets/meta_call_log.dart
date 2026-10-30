import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/meta_ai_service.dart';

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
          return Text(tr('metalog_empty'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
