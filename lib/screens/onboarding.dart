import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_kit.dart';
import '../widgets/honesty_sheet.dart';
import '../widgets/room_preview_art.dart';
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
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
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: Tappable(
                        onTap: _skip,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          child: Center(
                            child: Text(
                              tr('onboarding_skip'),
                              style: AppText.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: context.mutedText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                    visual: const RoomPreviewArt(),
                  ),
                  _featurePage(
                    index: 2,
                    icon: HugeIcons.strokeRoundedAiBrain01,
                    titleKey: 'onb_coach_title',
                    bodyKey: 'onb_coach_body',
                    visual: _coachTimelineCard(),
                  ),
                  _ctaCard(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: _index == total - 1
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EngramButton(
                          label: tr('onboarding_start'),
                          haptic: false,
                          onPressed: _skip,
                        ),
                        const SizedBox(height: 8),
                        EngramButton(
                          label: _busy
                              ? tr('onboarding_opening')
                              : tr('onboarding_find_my_type'),
                          variant: EngramButtonVariant.secondary,
                          isLoading: _busy,
                          haptic: false,
                          onPressed: _busy ? null : _startAssessment,
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

  /// One page body: vertically centred, scrollable when content is tall.
  Widget _centered(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    return _centered([
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
      const SizedBox(height: 8),
      EngramTextButton(
        label: tr('onboarding_honesty_link'),
        onPressed: () => showHonestySheet(context),
      ),
    ]);
  }

  Widget _featurePage({
    required int index,
    required List<List<dynamic>> icon,
    required String titleKey,
    required String bodyKey,
    Widget? visual,
  }) {
    return _centered([
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
        child:
            visual ??
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: context.washBg,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: context.washBorder, width: 2),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: icon,
                  color: blue,
                  size: 40,
                  strokeWidth: 2.0,
                ),
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
    ]);
  }

  /// Static Session-Coach-style timeline card for the coach page.
  Widget _coachTimelineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        children: [
          _timelineRow('coach_step_due'),
          const SizedBox(height: 12),
          _timelineRow('coach_step_snapshot'),
          const SizedBox(height: 12),
          _timelineRow('coach_trace_accepted'),
        ],
      ),
    );
  }

  Widget _timelineRow(String labelKey) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: teal, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedTick02,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tr(labelKey),
            style: AppText.body.copyWith(color: context.inkText),
          ),
        ),
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
    return _centered([
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
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: Tappable(
          onTap: _openScience,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              tr('onb_science_link'),
              style: AppText.body.copyWith(
                color: context.accentText(blue),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
