import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_kit.dart';
import '../widgets/honesty_sheet.dart';
import 'memory_profile.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingPage({super.key, required this.onDone});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Primer {
  final String titleKey;
  final String bodyKey;
  final String? sourceKey;
  final String? source;
  final List<List<dynamic>> icon;
  const _Primer(
    this.titleKey,
    this.bodyKey,
    this.icon, {
    this.sourceKey,
    this.source,
  });
}

const _primers = [
  _Primer(
    'onboarding_myth_title',
    'onboarding_myth_body',
    HugeIcons.strokeRoundedShield01,
    source: 'Haber (1979); Parker, Cahill & McGaugh (2006)',
  ),
  _Primer(
    'onboarding_palace_title',
    'onboarding_palace_body',
    HugeIcons.strokeRoundedCastle01,
    source: 'Maguire et al. 2003; Dresler et al. 2017',
  ),
  _Primer(
    'onboarding_chunking_title',
    'onboarding_chunking_body',
    HugeIcons.strokeRoundedLayers01,
    source: 'Miller 1956; Cowan 2001',
  ),
  _Primer(
    'onboarding_vivid_title',
    'onboarding_vivid_body',
    HugeIcons.strokeRoundedEye,
    source: 'Paivio dual-coding; Standing 1973',
  ),
  _Primer(
    'onboarding_keyword_title',
    'onboarding_keyword_body',
    HugeIcons.strokeRoundedTranslate,
    source: 'Atkinson & Raugh 1975',
  ),
  _Primer(
    'onboarding_spaced_title',
    'onboarding_spaced_body',
    HugeIcons.strokeRoundedTimer01,
    source: 'Dunlosky et al. 2013; Cepeda et al. 2008',
  ),
  _Primer(
    'onboarding_goals_title',
    'onboarding_goals_body',
    HugeIcons.strokeRoundedTarget01,
    sourceKey: 'onboarding_goals_source',
  ),
  _Primer(
    'onboarding_station_title',
    'onboarding_station_body',
    HugeIcons.strokeRoundedDumbbell01,
    sourceKey: 'onboarding_station_source',
  ),
  _Primer(
    'onboarding_stars_title',
    'onboarding_stars_body',
    HugeIcons.strokeRoundedStar,
    sourceKey: 'onboarding_stars_source',
  ),
  _Primer(
    'onboarding_help_title',
    'onboarding_help_body',
    HugeIcons.strokeRoundedBubbleChatQuestion,
    sourceKey: 'onboarding_help_source',
  ),
];

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    AppFeedback.light();
    await MemoryStore.saveOnboardingDone();
    widget.onDone();
  }

  Future<void> _startAssessment() async {
    if (_busy) return;
    setState(() => _busy = true);
    AppFeedback.medium();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MemoryAssessmentIntroPage()),
    );
    final scores = await MemoryStore.loadScores();
    if (!mounted) return;
    setState(() => _busy = false);
    if (scores != null && scores.isNotEmpty) {
      await MemoryStore.saveOnboardingDone();
      widget.onDone();
    }
  }

  void _next() {
    _pages.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    const total = 4;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < total; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            height: 8,
                            width: _index == i ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _index == i ? blue : context.hairline,
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const AiHelpButton(topic: AiHelpTopics.assessment),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: _skip,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        tr('onboarding_skip'),
                        style: AppText.body.copyWith(color: context.mutedText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) {
                  AppFeedback.select();
                  setState(() => _index = i);
                },
                children: [
                  _welcomeCard(),
                  _featurePage(
                    index: 1,
                    icon: HugeIcons.strokeRoundedCamera01,
                    titleKey: 'onb_room_title',
                    bodyKey: 'onb_room_body',
                  ),
                  _featurePage(
                    index: 2,
                    icon: HugeIcons.strokeRoundedAiBrain01,
                    titleKey: 'onb_coach_title',
                    bodyKey: 'onb_coach_body',
                  ),
                  _ctaCard(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _index == total - 1
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EngramButton(
                          label: _busy
                              ? tr('onboarding_opening')
                              : tr('onboarding_find_my_type'),
                          isLoading: _busy,
                          haptic: false,
                          onPressed: _busy ? null : _startAssessment,
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: GestureDetector(
                            onTap: _skip,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                tr('onboarding_skip_for_now'),
                                style: AppText.body.copyWith(
                                  color: context.mutedText,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : EngramButton(
                      label: tr('onboarding_next'),
                      onPressed: _next,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      children: [
        Text(
          tr('onboarding_welcome_title'),
          style: AppText.display.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr('onboarding_welcome_body'),
          style: AppText.body.copyWith(color: context.inkText),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.washBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.washBorder, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('onboarding_honest_note'),
                style: AppText.body.copyWith(color: context.inkText),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => showHonestySheet(context),
                child: Text(
                  tr('onboarding_honesty_link'),
                  style: AppText.body.copyWith(color: context.accentText(blue)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _featurePage({
    required int index,
    required List<List<dynamic>> icon,
    required String titleKey,
    required String bodyKey,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey('onb-tile-$index'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - t)),
              child: child,
            ),
          ),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.washBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.washBorder, width: 2),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: icon,
              color: blue,
              size: 30,
              strokeWidth: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr(titleKey),
          style: AppText.title.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(tr(bodyKey), style: AppText.body.copyWith(color: context.inkText)),
      ],
    );
  }

  Future<void> _openScience() {
    return showAppSheet<void>(
      context,
      builder: (_) => ListView(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 24),
        shrinkWrap: true,
        children: [
          for (var i = 0; i < _primers.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            Text(
              tr(_primers[i].titleKey),
              style: AppText.heading.copyWith(color: context.inkText),
            ),
            const SizedBox(height: 4),
            Text(
              tr(_primers[i].bodyKey),
              style: AppText.caption.copyWith(color: context.inkText),
            ),
            const SizedBox(height: 4),
            Text(
              _primers[i].sourceKey == null
                  ? (_primers[i].source ?? '')
                  : tr(_primers[i].sourceKey!),
              style: AppText.micro.copyWith(
                color: context.mutedText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ctaCard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      children: [
        Text(
          tr('onboarding_cta_title'),
          style: AppText.display.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          tr('onboarding_cta_body'),
          style: AppText.body.copyWith(color: context.inkText),
        ),
        const SizedBox(height: 12),
        EngramTextButton(
          label: tr('onb_science_link'),
          onPressed: _openScience,
        ),
      ],
    );
  }
}
