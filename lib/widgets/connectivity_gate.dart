import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/battle_duel_page.dart';
import '../services/bot_arena_store.dart';
import '../services/connectivity_service.dart';
import '../services/memory_store.dart';
import '../theme/app_theme.dart';
import 'app_buttons.dart';

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
    final online = connectivityService.online;
    if (online == true) return widget.child;
    if (online == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('gate_connect_title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: context.inkText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('gate_connect_body'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                EngramButton(
                  label: tr('gate_retry'),
                  isLoading: connectivityService.checking,
                  onPressed: () => connectivityService.check(),
                ),
                const SizedBox(height: 12),
                EngramButton(
                  label: tr('gate_offline_duel'),
                  variant: EngramButtonVariant.secondary,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OfflineBattleEntryPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
        title: Text(
          tr('gate_offline_title'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
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
                      fontWeight: FontWeight.w900,
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
