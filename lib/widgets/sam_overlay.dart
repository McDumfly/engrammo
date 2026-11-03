import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ai_image.dart';

/// AI palace picture with the SAM walk overlaid.
///
/// The image is painted by Muse Image; the numbered chips are the walk
/// order ([stations]) matched against what SAM 3.1 spotted ([samLabels]).
/// Without box geometry the chips sit in a bottom strip instead of on the
/// exact pixels — the numbers still match the loci list 1:1, so the player
/// walks the same order on the picture and in the list.
class SamOverlay extends StatelessWidget {
  final String imageUrl;
  final List<String> stations;
  final List<String> samLabels;
  final double height;

  const SamOverlay({
    super.key,
    required this.imageUrl,
    this.stations = const [],
    this.samLabels = const [],
    this.height = 170,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();
    final chips = stations.isNotEmpty ? stations : samLabels;
    return Padding(
      key: const ValueKey('sam-overlay'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                AiImage(
                  imageRef: imageUrl,
                  height: height,
                  width: double.infinity,
                  loading: Text(
                    tr('ai_picture_loading'),
                    style: TextStyle(color: context.mutedText, fontSize: 12),
                  ),
                ),
                if (chips.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < chips.length.clamp(0, 6); i++)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              child: Text(
                                '${i + 1} · ${chips[i]}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (chips.length > 6)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              child: Text(
                                '+${chips.length - 6}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (samLabels.isNotEmpty || stations.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tr('sam_overlay_title', {
                'n': (samLabels.isNotEmpty ? samLabels : stations).length,
              }),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.accentText(teal),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
