import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../screens/battle_duel_page.dart';
import '../services/bot_arena_store.dart';
import '../services/connectivity_service.dart';
import '../services/memory_store.dart';
import '../theme/app_colors.dart' show orange;
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'app_buttons.dart';
import 'app_kit.dart';

/// Connectivity gate in front of the app root: with no internet it shows a
/// "Connect to the internet" message with a retry button instead of the
/// full app, plus one offline exception: bot duels start without internet
/// because the device builds all 3 tasks and results save locally.
/// Re-measures automatically when the app returns to the foreground.
class ConnectivityGate extends StatefulWidget {
  final Widget child;

  const ConnectivityGate({super.key, required this.child});

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    connectivityService.addListener(_onChanged);
    connectivityService.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    connectivityService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        connectivityService.online == false) {
      connectivityService.check();
    }
  }

  @override
  Widget build(BuildContext context) {
    // No gate: the child renders immediately, even offline or while the
    // probe is still measuring. Offline only shows a slim banner on top.
    final offline = connectivityService.online == false;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: offline
              ? Material(
                  type: MaterialType.transparency,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 36,
                      width: double.infinity,
                      color: orange.withValues(alpha: 0.14),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedWifiDisconnected01,
                            color: orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              tr('offline_banner'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.micro.copyWith(
                                color: context.accentText(orange),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: offline,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// Offline exception under the gate: bot-duel launcher without internet.
/// The device generates all three duel tasks; results, stats and the
/// league row save locally.
class OfflineBattleEntryPage extends StatefulWidget {
  const OfflineBattleEntryPage({super.key});

  @override
  State<OfflineBattleEntryPage> createState() => _OfflineBattleEntryPageState();
}

class _OfflineBattleEntryPageState extends State<OfflineBattleEntryPage> {
  bool _ready = false;
  int _kind = 0;
  int _rating = 1000;

  @override
  void initState() {
    super.initState();
    botArena.addListener(_onArena);
    botArena.ensureLoaded().then((_) {
      if (!mounted) return;
      _onArena();
    });
    MemoryStore.loadBattleKind().then((kind) {
      if (!mounted || kind == null) return;
      setState(() => _kind = kind.clamp(0, 5));
    });
  }

  void _onArena() {
    if (!mounted) return;
    setState(() => _ready = botArena.roster.isNotEmpty);
    MemoryStore.loadBattleRating(defaultRating: 1000).then((rating) {
      if (!mounted) return;
      setState(() => _rating = rating);
    });
  }

  @override
  void dispose() {
    botArena.removeListener(_onArena);
    super.dispose();
  }

  void _startDuel() {
    final opponent =
        botArena.matchOpponent() ??
        (botArena.roster.isEmpty ? null : botArena.roster.first);
    if (opponent == null || !mounted) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) =>
                BattleDuelPage.duel(opponent: opponent, kind: _kind),
          ),
        )
        .then((_) {
          if (mounted) _onArena();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppTopBar(
        title: tr('gate_offline_title'),
        leading: const EngramBackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.hairline, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('gate_offline_subtitle'),
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('gate_offline_body'),
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _ready
                        ? tr('gate_offline_score', {
                            'rating': _rating,
                            'matches': botArena.stats.matches,
                          })
                        : tr('gate_offline_loading'),
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            EngramButton(
              label: tr('gate_start_bot_duel'),
              isLoading: !_ready,
              onPressed: _ready ? _startDuel : null,
            ),
          ],
        ),
      ),
    );
  }
}
