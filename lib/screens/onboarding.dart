import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../services/app_feedback.dart';
import '../services/memory_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import 'memory_profile.dart';

/// First-launch onboarding: short, English, direct.
///
/// It teaches the 5 core techniques up front (so every later lesson
/// has something to build on), busts the photographic-memory myth,
/// then hands the user to the 12-item assessment that determines
/// their level and dominant memory type.
class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingPage({super.key, required this.onDone});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Primer {
  final String title;
  final String body;
  final String source;
  final List<List<dynamic>> icon;
  const _Primer(this.title, this.body, this.source, this.icon);
}

const _primers = [
  _Primer(
    'Memory Palace',
    'Pick a route you know — your home. Put one vivid image at each '
        'stop, then walk the route to recall. This single method wins '
        'memory championships.',
    'Maguire et al. 2003; Dresler et al. 2017',
    HugeIcons.strokeRoundedCastle01,
  ),
  _Primer(
    'Chunking',
    'Your mind holds ~4 chunks, but a chunk can be huge. Turn '
        '491625 into two images instead of six digits and it fits.',
    'Miller 1956; Cowan 2001',
    HugeIcons.strokeRoundedLayers01,
  ),
  _Primer(
    'Vivid Images',
    'Pictures stick twice as well as words. Make every item big, '
        'bright, moving — and let items interact with each other.',
    'Paivio dual-coding; Standing 1973',
    HugeIcons.strokeRoundedEye,
  ),
  _Primer(
    'Keyword Hook',
    'Foreign word? Find a native word that sounds like it, picture '
        'the two interacting. Recall jumps from 46% to 72%.',
    'Atkinson & Raugh 1975',
    HugeIcons.strokeRoundedTranslate,
  ),
  _Primer(
    'Spaced Retrieval',
    'Test yourself, spaced out, instead of re-reading. It is the '
        'highest-utility study strategy ever measured.',
    'Dunlosky et al. 2013; Cepeda et al. 2008',
    HugeIcons.strokeRoundedTimer01,
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
    // A rezgést az EngramButton adja, itt már nem rezgünk duplán.
    _pages.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _primers.length + 2;
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: (_index + 1) / total,
                        minHeight: 6,
                        backgroundColor: context.hairline,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF45A3FF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _skip,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: context.mutedText,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _welcomeCard(),
                  for (final p in _primers) _primerCard(p),
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
                          label: _busy ? 'OPENING…' : 'FIND MY MEMORY TYPE',
                          isLoading: _busy,
                          // A kezelő adja a medium jelzést, a gomb nem rezeg rá.
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
                                'Skip for now',
                                style: TextStyle(
                                  color: context.mutedText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : EngramButton(label: 'NEXT', onPressed: _next),
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
          'Your memory is trainable.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 30,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Memory champions are not born. Their brains look ordinary — '
          'they just use 2,500-year-old techniques. You are about to '
          'learn all of them.',
          style: TextStyle(color: context.inkText, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.washBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.washBorder, width: 2),
          ),
          child: Text(
            'One honest note: photographic memory is a myth — it has '
            'never been proven. What you get instead is better: trained '
            'supermemory that actually works.',
            style: TextStyle(color: context.inkText, fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _primerCard(_Primer p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: context.washBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.washBorder, width: 2),
          ),
          alignment: Alignment.center,
          child: HugeIcon(
            icon: p.icon,
            color: const Color(0xFF45A3FF),
            size: 30,
            strokeWidth: 2.0,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          p.title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          p.body,
          style: TextStyle(color: context.inkText, fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 16),
        Text(
          p.source,
          style: TextStyle(
            color: context.mutedText,
            fontStyle: FontStyle.italic,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _ctaCard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      children: [
        Text(
          'First, find your type.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 28,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'A 12-task checkup — 2 quick probes for each of your 6 memory '
          'types. About 3 minutes. Then your training path adapts to '
          'your strongest type.',
          style: TextStyle(color: context.inkText, fontSize: 16, height: 1.5),
        ),
      ],
    );
  }
}
