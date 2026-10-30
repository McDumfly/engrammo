import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../models/battle_bot.dart';
import '../models/battle_match.dart';
import '../models/battle_rating.dart';
import '../models/battle_rewards.dart';
import '../models/battle_round.dart';
import '../models/meta_task.dart';
import '../models/validated_tasks.dart' show localValidatedTask;
import '../services/app_feedback.dart';
import '../services/bot_arena_store.dart';
import '../services/connectivity_service.dart';
import '../services/memory_growth.dart';
import '../services/memory_store.dart';
import '../services/meta_ai_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/recall_inputs.dart' show RecallTextField;
import 'memory_profile.dart' show violet, violetDark, teal, amber, memoryKinds;

enum _Phase { matchmaking, countdown, encode, recall, reveal, result }

class _Lock {
  final int answer;
  final int ms;
  final bool correct;
  final double proportion;
  final bool exact;
  final String response;
  final String detail;
  const _Lock({
    required this.answer,
    required this.ms,
    required this.correct,
    this.proportion = 0,
    this.exact = false,
    this.response = '',
    this.detail = '',
  });
}

class _DuelBot {
  final BotPersona bot;
  final bool isFoe;
  const _DuelBot({required this.bot, required this.isFoe});
}

/// Live duel against arena bots (1v1, 2v2 squad or spectated exhibition).
///
/// Every round runs encode -> hide -> recall: the stimulus shows briefly,
/// auto-hides, and only then does the question appear. Typed and tapped
/// answers replace 4-option recognition wherever the paradigm allows it
/// (recall beats recognition; Rowland 2014, Adesope et al. 2017), the
/// backward-span direction stays hidden until recall (Baddeley 1986), and
/// both sides share the same tasks on the same clocks. Bot answers are
/// purely local seeded policy and never peek at the player's pick.
class BattleDuelPage extends StatefulWidget {
  final int kind;
  final bool team;
  final bool spectate;
  final bool skipMatchmaking;

  const BattleDuelPage.duel({
    super.key,
    required this.opponent,
    required this.kind,
    this.skipMatchmaking = false,
  }) : team = false,
       spectate = false,
       squad = null,
       home = null,
       away = null;

  const BattleDuelPage.team({
    super.key,
    required this.squad,
    required this.kind,
    this.skipMatchmaking = false,
  }) : team = true,
       spectate = false,
       opponent = null,
       home = null,
       away = null;

  const BattleDuelPage.spectate({
    super.key,
    required this.home,
    required this.away,
    required this.kind,
  }) : team = false,
       spectate = true,
       skipMatchmaking = true,
       opponent = null,
       squad = null;

  final BotPersona? opponent;
  final BattleSquad? squad;
  final BotPersona? home;
  final BotPersona? away;

  @override
  State<BattleDuelPage> createState() => _BattleDuelPageState();
}

class _BattleDuelPageState extends State<BattleDuelPage> {
  static const _questionCount = 3;
  static const _difficulties = [2, 2, 3];

  late String _matchId;
  late int _matchSeed;
  late List<_DuelBot> _bots;
  late String _foeLabel;
  late String _sideLabel;
  late List<int> _roundKinds;

  _Phase _phase = _Phase.matchmaking;
  int _countdown = 3;
  int _questionIndex = 0;
  List<MetaTask> _tasks = const [];
  int _encodeMs = 5000;
  int _encodeElapsedMs = 0;
  int _recallMs = BattleScore.questionClockMs;
  int _elapsedMs = 0;

  _Lock? _playerLock;
  Map<String, _Lock> _botLocks = {};
  final Map<String, ({int base, bool exact, double proportion, int latencyMs})>
  _botPlanned = {};

  int _playerTotal = 0;
  int _foeTotal = 0;
  int _playerMsTotal = 0;
  int _foeMsTotal = 0;
  int _fastestBonuses = 0;
  int _answered = 0;
  final List<BattleRoundRecord> _rounds = [];

  BattleOutcome? _outcome;
  int _delta = 0;
  int _xp = 0;
  int _dailyBonus = 0;
  int _streakBonus = 0;
  int _playerRating = BattleRating.startingRating;

  final List<Timer> _timers = [];
  bool _active = true;
  bool _recorded = false;
  Future<void>? _taskFuture;

  @override
  void initState() {
    super.initState();
    _setupMatch(rematch: widget.skipMatchmaking);
    // Pre-generate the 3 duel tasks during matchmaking so the countdown
    // starts instantly and offline duels never wait on the network.
    _taskFuture = _generateTasks();
    MemoryStore.loadBattleRating(
      defaultRating: BattleRating.startingRating,
    ).then((rating) {
      if (!mounted) return;
      setState(() => _playerRating = rating);
    });
    if (widget.skipMatchmaking) {
      _startCountdown();
    } else {
      final delay = matchmakingDelay(Random());
      _later(delay, () {
        if (!_active || _phase != _Phase.matchmaking) return;
        _startCountdown();
      });
    }
  }

  void _setupMatch({required bool rematch}) {
    _matchId = DateTime.now().microsecondsSinceEpoch.toString();
    _matchSeed = botSeedHash('duel:$_matchId');
    _roundKinds = battleRoundKinds(widget.kind);
    if (widget.spectate) {
      final home = widget.home!;
      final away = widget.away!;
      _bots = [
        _DuelBot(bot: home, isFoe: false),
        _DuelBot(bot: away, isFoe: true),
      ];
      _foeLabel = away.name;
      _sideLabel = home.name;
    } else if (widget.team) {
      final squad = widget.squad!;
      _bots = [
        _DuelBot(bot: squad.ally, isFoe: false),
        _DuelBot(bot: squad.foe1, isFoe: true),
        _DuelBot(bot: squad.foe2, isFoe: true),
      ];
      _foeLabel = '${squad.foe1.name} + ${squad.foe2.name}';
      _sideLabel = tr('btd_you_ally', {'name': squad.ally.name});
    } else {
      final opp = widget.opponent!;
      _bots = [_DuelBot(bot: opp, isFoe: true)];
      _foeLabel = opp.name;
      _sideLabel = tr('btd_you');
    }
    if (rematch) {
      _phase = _Phase.countdown;
    }
  }

  @override
  void dispose() {
    _active = false;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  void _later(Duration delay, void Function() fn) {
    if (!_active) return;
    final timer = Timer(delay, () {
      if (!_active) return;
      fn();
    });
    _timers.add(timer);
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  Future<void> _startCountdown() async {
    if (!_active) return;
    setState(() {
      _phase = _Phase.countdown;
      _countdown = 3;
    });
    await (_taskFuture ?? _generateTasks());
    _taskFuture = null;
    if (!_active) return;
    AppFeedback.light();
    for (var i = 3; i >= 1; i--) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!_active || _phase != _Phase.countdown) return;
      setState(() => _countdown = i - 1);
      if (i - 1 > 0) {
        AppFeedback.light();
      } else {
        AppFeedback.medium();
      }
    }
    if (!_active || _phase != _Phase.countdown) return;
    _startEncode(0);
  }

  Future<void> _generateTasks() async {
    // Offline-first: when the gate measured no connection, skip the network
    // entirely so bot duels start instantly with local tasks.
    final offline = connectivityService.online == false;
    Future<MetaTask> one(int i) async {
      final seed = 'battle:$_matchId:q$i';
      final req = MetaTaskRequest(
        kind: battleRequestKindFor(_roundKinds[i]),
        difficulty: _difficulties[i],
        seed: seed,
        locale: AppLocalizations.localeCode,
      );
      if (offline) return localValidatedTask(req);
      MetaTask task;
      try {
        task = await MetaAIService.generateTask(req);
      } catch (_) {
        task = localValidatedTask(req);
      }
      // Imagery rounds get a Muse Image illustration plus SAM detail labels
      // (stored on stations); digit spans and the tap grid stay clean.
      if (battleTaskWantsImage(task)) {
        try {
          task = await MetaAIService.enrichVisualTask(task, seed: seed);
        } catch (_) {}
      }
      return task;
    }

    final tasks = await Future.wait([
      for (var i = 0; i < _questionCount; i++) one(i),
    ]);
    if (!_active) return;
    setState(() => _tasks = tasks);
  }

  BattleResponseKind _responseKindFor(MetaTask task) =>
      battleResponseKindForParadigm(task.paradigm);

  /// Encode phase: stimulus shows briefly, then auto-hides. No question, no
  /// options, no paradigm name (the backward direction stays blind). Choice
  /// judgments skip encode: there is nothing to memorize.
  void _startEncode(int index) {
    if (!_active) return;
    _cancelTimers();
    final task = _tasks[index];
    final kind = _responseKindFor(task);
    final encodeMs = battleEncodeMs(task, difficulty: _difficulties[index]);
    if (kind == BattleResponseKind.choice4 || encodeMs <= 0) {
      _startRecall(index);
      return;
    }
    setState(() {
      _phase = _Phase.encode;
      _questionIndex = index;
      _encodeMs = encodeMs;
      _encodeElapsedMs = 0;
      _playerLock = null;
      _botLocks = {};
      _botPlanned.clear();
    });
    final clock = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_active || _phase != _Phase.encode) {
        timer.cancel();
        return;
      }
      setState(() => _encodeElapsedMs += 100);
      if (_encodeElapsedMs >= _encodeMs) {
        timer.cancel();
        _startRecall(index);
      }
    });
    _timers.add(clock);
  }

  /// Recall phase: stimulus hidden, question plus the paradigm's own answer
  /// format. Both sides share the same clock; bot answers are sampled from
  /// the seeded human-memory policy at recall start.
  void _startRecall(int index) {
    if (!_active) return;
    _cancelTimers();
    final task = _tasks[index];
    final kind = _responseKindFor(task);
    final recallMs = battleRecallMs(kind);
    setState(() {
      _phase = _Phase.recall;
      _questionIndex = index;
      _recallMs = recallMs;
      _elapsedMs = 0;
      _playerLock = null;
      _botLocks = {};
      _botPlanned.clear();
    });
    final roundKind = _roundKinds[index];
    final stats = botArena.stats;
    for (var b = 0; b < _bots.length; b++) {
      final bot = _bots[b].bot;
      final pExact = botRecallExactProb(
        bot: bot,
        kind: roundKind,
        paradigm: task.paradigm,
      );
      var accuracyDelta = 0.0;
      var latencyFactor = 1.0;
      if (!widget.spectate) {
        // Nominal 10000 ms probe: applyRubberBand only scales the latency by
        // 0.9/1.1/1.0, so the factor extracts exactly and every cap and rule
        // stays in one place.
        final probe = applyRubberBand(
          baseAccuracy: pExact,
          baseLatencyMs: 10000,
          playerTotal: _playerTotal,
          foeTotal: _foeTotal,
          questionIndex: index,
          questionCount: _questionCount,
          playerRating: _playerRating,
          matchesPlayed: stats.matches,
        );
        accuracyDelta = probe.accuracy - pExact;
        latencyFactor = probe.latencyMs / 10000;
      }
      final out = botRecallOutcome(
        bot: bot,
        kind: roundKind,
        paradigm: task.paradigm,
        rng: Random(_matchSeed + index * 733 + b * 97),
        clockMs: recallMs,
        accuracyDelta: accuracyDelta,
        latencyFactor: latencyFactor,
      );
      _botPlanned[bot.id] = out;
      final captured = bot;
      _later(
        Duration(milliseconds: out.latencyMs),
        () => _lockBot(captured),
      );
    }
    if (widget.spectate) {
      final home = _bots.firstWhere((b) => !b.isFoe).bot;
      final out = botRecallOutcome(
        bot: home,
        kind: roundKind,
        paradigm: task.paradigm,
        rng: Random(_matchSeed + index * 733 + 4242),
        clockMs: recallMs,
      );
      _later(Duration(milliseconds: out.latencyMs), () {
        if (!_active || _phase != _Phase.recall) return;
        setState(() => _playerLock = _botLockFor(home, task, kind, out));
        _maybeFinishQuestion();
      });
    }
    final clock = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_active || _phase != _Phase.recall) {
        timer.cancel();
        return;
      }
      setState(() => _elapsedMs += 100);
      if (_elapsedMs >= _recallMs) {
        timer.cancel();
        _finishQuestion();
      }
    });
    _timers.add(clock);
  }

  int _wrongAnswer(int correct, Random rng) {
    final wrong = [0, 1, 2, 3]..remove(correct);
    return wrong[rng.nextInt(wrong.length)];
  }

  _Lock _botLockFor(
    BotPersona bot,
    MetaTask task,
    BattleResponseKind kind,
    ({int base, bool exact, double proportion, int latencyMs}) out,
  ) {
    if (kind == BattleResponseKind.choice4) {
      // Judgments are binary: exact means the bot picked right.
      final answer = out.exact
          ? task.correct
          : _wrongAnswer(
              task.correct,
              Random(botSeedHash('${bot.id}:${task.question}')),
            );
      return _Lock(
        answer: answer,
        ms: out.latencyMs,
        correct: out.exact,
        proportion: out.exact ? 1 : 0,
        exact: out.exact,
        response: task.options[answer],
      );
    }
    return _Lock(
      answer: -1,
      ms: out.latencyMs,
      correct: out.base > 0,
      proportion: out.proportion,
      exact: out.exact,
    );
  }

  void _lockBot(BotPersona bot) {
    if (!_active || _phase != _Phase.recall) return;
    if (_botLocks.containsKey(bot.id)) return;
    final out = _botPlanned[bot.id];
    if (out == null) return;
    final task = _tasks[_questionIndex];
    setState(
      () => _botLocks[bot.id] = _botLockFor(bot, task, _responseKindFor(task), out),
    );
    _maybeFinishQuestion();
  }

  void _lockPlayerChoice(int answer) {
    if (!_active || _phase != _Phase.recall) return;
    if (_playerLock != null || widget.spectate) return;
    final task = _tasks[_questionIndex];
    AppFeedback.select();
    final correct = answer == task.correct;
    setState(() {
      _playerLock = _Lock(
        answer: answer,
        ms: _elapsedMs,
        correct: correct,
        proportion: correct ? 1 : 0,
        exact: correct,
        response: task.options[answer],
      );
      _answered++;
    });
    _maybeFinishQuestion();
  }

  void _lockPlayerRecall(String text) {
    if (!_active || _phase != _Phase.recall) return;
    if (_playerLock != null || widget.spectate) return;
    final task = _tasks[_questionIndex];
    final score = battleScoreResponse(task, text: text);
    final present = battleResponsePresent(
      _responseKindFor(task),
      text: text,
    );
    AppFeedback.select();
    setState(() {
      _playerLock = _Lock(
        answer: -1,
        ms: _elapsedMs,
        correct: score.proportion >= 0.5 || score.exact,
        proportion: score.proportion,
        exact: score.exact,
        response: text.trim(),
        detail: score.detail,
      );
      if (present) _answered++;
    });
    _maybeFinishQuestion();
  }

  void _lockPlayerCells(List<int> taps) {
    if (!_active || _phase != _Phase.recall) return;
    if (_playerLock != null || widget.spectate) return;
    final task = _tasks[_questionIndex];
    final score = battleScoreResponse(task, taps: taps);
    final present = battleResponsePresent(
      _responseKindFor(task),
      taps: taps,
    );
    AppFeedback.select();
    setState(() {
      _playerLock = _Lock(
        answer: -1,
        ms: _elapsedMs,
        correct: score.proportion >= 0.5 || score.exact,
        proportion: score.proportion,
        exact: score.exact,
        response: taps.join(', '),
        detail: score.detail,
      );
      if (present) _answered++;
    });
    _maybeFinishQuestion();
  }

  void _maybeFinishQuestion() {
    if (_phase != _Phase.recall) return;
    if (_playerLock == null) return;
    if (_botLocks.length < _bots.length) return;
    _finishQuestion();
  }

  void _finishQuestion() {
    if (_phase != _Phase.recall) return;
    _cancelTimers();
    final task = _tasks[_questionIndex];
    final binary = _responseKindFor(task) == BattleResponseKind.choice4;
    final player =
        _playerLock ??
        _Lock(answer: -1, ms: _recallMs, correct: false);
    var playerPts = BattleScore.questionPoints(
      correct: player.correct,
      latencyMs: player.ms,
      clockMs: _recallMs,
      proportion: binary ? null : player.proportion,
      exact: player.exact,
    );
    var foePts = 0;
    var foeMs = 0;
    var foeExact = false;
    for (final entry in _bots) {
      final lock =
          _botLocks[entry.bot.id] ??
          _Lock(answer: -1, ms: _recallMs, correct: false);
      final pts = BattleScore.questionPoints(
        correct: lock.correct,
        latencyMs: lock.ms,
        clockMs: _recallMs,
        proportion: binary ? null : lock.proportion,
        exact: lock.exact,
      );
      if (entry.isFoe) {
        foePts += pts;
        foeMs += lock.ms;
        foeExact = foeExact || lock.exact;
      } else {
        playerPts += pts;
      }
      _botLocks[entry.bot.id] = lock;
    }
    if (!widget.spectate &&
        player.exact &&
        _bots.where((b) => b.isFoe).isNotEmpty) {
      final fastestFoe = _bots
          .where((b) => b.isFoe)
          .map((b) => _botLocks[b.bot.id]!.ms)
          .reduce(min);
      if (player.ms < fastestFoe) _fastestBonuses++;
    }
    final playerMs = player.ms + _allyMs();
    setState(() {
      _playerLock = player;
      _playerTotal += playerPts;
      _foeTotal += foePts;
      _playerMsTotal += playerMs;
      _foeMsTotal += foeMs;
      _rounds.add(
        BattleRoundRecord(
          question: task.question,
          playerCorrect: player.correct,
          foeCorrect: foePts > 0,
          playerMs: playerMs,
          foeMs: foeMs,
          playerPts: playerPts,
          foePts: foePts,
          playerExact: player.exact,
          foeExact: foeExact,
        ),
      );
      _phase = _Phase.reveal;
    });
    _later(const Duration(milliseconds: 3000), () {
      if (!_active || _phase != _Phase.reveal) return;
      if (_questionIndex + 1 < _questionCount) {
        _startEncode(_questionIndex + 1);
      } else {
        _finishMatch();
      }
    });
  }

  int _allyMs() {
    var ms = 0;
    for (final entry in _bots) {
      if (!entry.isFoe && !widget.spectate) {
        ms += _botLocks[entry.bot.id]?.ms ?? _recallMs;
      }
    }
    return ms;
  }

  Future<void> _finishMatch() async {
    if (!_active) return;
    _cancelTimers();
    final outcome = outcomeFor(
      _playerTotal,
      _foeTotal,
      playerMs: _playerMsTotal,
      foeMs: _foeMsTotal,
    );
    if (widget.spectate) {
      setState(() {
        _outcome = outcome;
        _phase = _Phase.result;
      });
      return;
    }
    final foeRating = widget.team
        ? widget.squad!.foeAverage
        : widget.opponent!.rating;
    final next = switch (outcome) {
      BattleOutcome.win => BattleRating.win(
        player: _playerRating,
        opponent: foeRating,
      ),
      BattleOutcome.loss => BattleRating.loss(
        player: _playerRating,
        opponent: foeRating,
      ),
      BattleOutcome.draw => BattleRating.draw(
        player: _playerRating,
        opponent: foeRating,
      ),
    };
    final delta = next - _playerRating;
    final margin = (_playerTotal - _foeTotal).abs();
    final xp = BattleRewards.capIdleXp(
      BattleXp.forOutcome(
        outcome: outcome,
        margin: margin,
        fastestBonuses: _fastestBonuses,
      ),
      answered: _answered,
    );
    setState(() {
      _outcome = outcome;
      _delta = delta;
      _xp = xp;
      _phase = _Phase.result;
    });
    if (_recorded) return;
    _recorded = true;
    if (outcome == BattleOutcome.win) {
      AppFeedback.heavy();
    } else {
      AppFeedback.medium();
    }
    await MemoryStore.saveBattleRating(next);
    final lines = <String>[];
    for (var i = 0; i < _rounds.length; i++) {
      final r = _rounds[i];
      final paradigm = i < _tasks.length ? _tasks[i].paradigm : 'round';
      lines.add(
        tr('btd_round_line', {
          'p': paradigm,
          'a': r.playerPts,
          'b': r.foePts,
        }),
      );
    }
    final record = BattleRecord(
      id: 'battle:$_matchId',
      at: DateTime.now(),
      opponent: _foeLabel,
      opponentRating: foeRating,
      duel: !widget.team,
      kind: widget.kind,
      playerScore: _playerTotal,
      foeScore: _foeTotal,
      rounds: List<BattleRoundRecord>.of(_rounds),
      roundLines: lines,
      delta: delta,
      xp: xp,
      decidedOutcome: outcome,
    );
    await botArena.recordBattle(
      record: record,
      outcome: outcome,
      botIds: [for (final b in _bots) if (b.isFoe) b.bot.id],
    );
    if (_answered > 0 && _rounds.isNotEmpty) {
      final exact = _rounds.where((r) => r.playerExact).length;
      final base = battleGrowthBase(
        outcome: outcome,
        exact: exact,
        rounds: _rounds.length,
      );
      if (base > 0) await applyGrowth(kind: widget.kind, base: base);
    }
    if (outcome == BattleOutcome.win) {
      final dailyBonus = await botArena.claimDailyWinBonus(xp);
      final streakBonus = BattleRewards.streakBonusFor(
        botArena.stats.currentStreak,
      );
      if (_active && mounted && (dailyBonus > 0 || streakBonus > 0)) {
        setState(() {
          _dailyBonus = dailyBonus;
          _streakBonus = streakBonus;
        });
      }
    }
    if (widget.team) {
      final ally = widget.squad!.ally;
      await botArena.driftTeammate(
        ally.id,
        playerWon: outcome == BattleOutcome.win,
      );
    }
  }

  Future<void> _forfeit() async {
    if (_recorded || widget.spectate) return;
    _recorded = true;
    _cancelTimers();
    final foeRating = widget.team
        ? widget.squad!.foeAverage
        : widget.opponent!.rating;
    final next = BattleRating.loss(player: _playerRating, opponent: foeRating);
    await MemoryStore.saveBattleRating(next);
    final record = BattleRecord(
      id: 'battle:$_matchId:forfeit',
      at: DateTime.now(),
      opponent: _foeLabel,
      opponentRating: foeRating,
      duel: !widget.team,
      kind: widget.kind,
      playerScore: _playerTotal,
      foeScore: _foeTotal,
      rounds: List<BattleRoundRecord>.of(_rounds),
      roundLines: [tr('btd_forfeited')],
      delta: next - _playerRating,
      xp: BattleXp.participationFloor,
      forfeit: true,
      decidedOutcome: BattleOutcome.loss,
    );
    await botArena.recordBattle(
      record: record,
      outcome: BattleOutcome.loss,
      botIds: [for (final b in _bots) if (b.isFoe) b.bot.id],
    );
  }

  void _handleBack() {
    if (_phase == _Phase.result || _phase == _Phase.matchmaking) {
      Navigator.of(context).pop();
      return;
    }
    if (widget.spectate) {
      Navigator.of(context).pop();
      return;
    }
    AppFeedback.light();
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          tr('btd_forfeit_title'),
          style: TextStyle(
            color: dialogContext.inkText,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        content: Text(
          tr('btd_forfeit_body'),
          style: TextStyle(color: dialogContext.mutedText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('btd_keep_playing')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _forfeitAndExit(navigator);
            },
            child: Text(tr('btd_forfeit_btn')),
          ),
        ],
      ),
    );
  }

  Future<void> _forfeitAndExit(NavigatorState navigator) async {
    await _forfeit();
    if (!mounted) return;
    navigator.pop();
  }

  void _rematch() {
    _cancelTimers();
    setState(() {
      _playerTotal = 0;
      _foeTotal = 0;
      _playerMsTotal = 0;
      _foeMsTotal = 0;
      _fastestBonuses = 0;
      _answered = 0;
      _rounds.clear();
      _outcome = null;
      _delta = 0;
      _xp = 0;
      _dailyBonus = 0;
      _streakBonus = 0;
      _tasks = const [];
      _recorded = false;
      _setupMatch(rematch: true);
    });
    _taskFuture = _generateTasks();
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: EngramBackButton(onPressed: _handleBack),
          title: Text(
            widget.spectate
                ? tr('btd_title_show')
                : widget.team
                ? tr('btd_title_team')
                : tr('btd_title_duel'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: switch (_phase) {
            _Phase.matchmaking => _matchmakingView(),
            _Phase.countdown => _countdownView(),
            _Phase.encode => _encodeView(),
            _Phase.recall => _recallView(false),
            _Phase.reveal => _recallView(true),
            _Phase.result => _resultView(),
          },
        ),
      ),
    );
  }

  Widget _matchmakingView() {
    final opp = widget.team ? widget.squad!.foe1 : widget.opponent!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.hairline, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: violet.withValues(alpha: 0.14),
                  ),
                  child: Text(
                    _foeLabel.characters.first,
                    style: const TextStyle(
                      color: violetDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _foeLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: violet.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        opp.tierLabel,
                        style: const TextStyle(
                          color: violetDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.softBg,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: context.hairline,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        tr('btd_rating_pts', {'n': opp.rating}),
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tr('btd_you_pts', {'n': _playerRating}),
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
                const SizedBox(height: 14),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('btd_finding'),
                  style: TextStyle(
                    color: context.mutedText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('btd_cancel')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('btd_versus', {'a': _sideLabel, 'b': _foeLabel}),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _countdown > 0 ? '$_countdown' : tr('btd_go'),
            key: const ValueKey('duel-countdown'),
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w900,
              fontSize: 96,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('btd_same_task'),
            style: TextStyle(color: context.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _DuelHype(
              foeName: _foeLabel,
              kindLabel: _kindLabel,
            ),
          ),
        ],
      ),
    );
  }

  String get _kindLabel =>
      tr(memoryKinds[widget.kind.clamp(0, memoryKinds.length - 1)].nameKey);

  /// AI illustration for imagery rounds. Empty URL (offline or no key) renders
  /// nothing, so local duels look exactly as before.
  Widget _duelImage(String imageUrl, {double height = 150}) {
    if (imageUrl.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: height,
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox.shrink(),
        ),
      ),
    );
  }

  /// Encode view: stimulus only, auto-hiding. The question, the options and
  /// the paradigm name stay hidden — showing them would turn recall into
  /// open-book matching.
  Widget _encodeView() {
    if (_tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final task = _tasks[_questionIndex];
    final progress = (_encodeElapsedMs / _encodeMs).clamp(0.0, 1.0);
    return ListView(
      key: ValueKey('duel-encode-$_questionIndex'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _ticker(),
        const SizedBox(height: 10),
        Text(
          tr('btd_q_memorize', {
            'q': _questionIndex + 1,
            'n': _questionCount,
          }),
          style: TextStyle(
            color: context.mutedText,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: 1 - progress,
            minHeight: 8,
            backgroundColor: context.hairline,
            color: violet,
          ),
        ),
        const SizedBox(height: 10),
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
                battleEncodePromptIn(AppLocalizations.localeCode, task),
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              // The AI picture is part of the stimulus: memorize it now,
              // it hides together with the chips when recall starts.
              _duelImage(task.imageUrl),
              if (task.paradigm == 'pattern-span')
                _BattleGridStimulus(cells: battleExpectedCells(task))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in task.items)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: violet.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: violetDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                tr('btd_memorize_next'),
                style: TextStyle(
                  color: context.mutedText,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _botStatus(reveal: false, blindLabel: tr('btd_blind_mem')),
      ],
    );
  }

  /// Recall view: stimulus hidden, question plus the paradigm's own answer
  /// format. At reveal the same screen locks and gains corrective feedback.
  Widget _recallView(bool reveal) {
    if (_tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final task = _tasks[_questionIndex];
    final kind = _responseKindFor(task);
    final progress = (_elapsedMs / _recallMs).clamp(0.0, 1.0);
    final secondsLeft = ((_recallMs - _elapsedMs) / 1000).ceil().clamp(0, 60);
    return ListView(
      key: ValueKey('duel-question-$_questionIndex'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _ticker(),
        const SizedBox(height: 10),
        Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1 - progress,
                    strokeWidth: 5,
                    backgroundColor: context.hairline,
                    color: secondsLeft <= 5
                        ? const Color(0xFFDC2626)
                        : violet,
                  ),
                  Text(
                    '$secondsLeft',
                    style: TextStyle(
                      color: context.inkText,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('btd_q_recall', {
                  'q': _questionIndex + 1,
                  'n': _questionCount,
                }),
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
              if (kind == BattleResponseKind.choice4 &&
                  task.items.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in task.items)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: violet.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: violetDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Text(
                task.question,
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              // Reveal only: showing the picture during recall would turn
              // picture rounds into open-book matching.
              if (reveal && task.imageUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                _duelImage(task.imageUrl, height: 120),
              ],
              if (reveal) _samLabels(task),
            ],
          ),
        ),
        const SizedBox(height: 10),
        switch (kind) {
          BattleResponseKind.choice4 => Column(
            children: [
              for (var i = 0; i < task.options.length; i++) ...[
                _optionButton(task, i, reveal),
                if (i < task.options.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
          BattleResponseKind.cellSet => _BattleCellPicker(
            key: ValueKey('duel-cells-$_questionIndex'),
            submitted: _playerLock != null || reveal,
            onDone: _lockPlayerCells,
          ),
          BattleResponseKind.typedDigits ||
          BattleResponseKind.typedToken => RecallTextField(
            key: ValueKey('duel-recall-$_questionIndex'),
            hint: battleRecallHintIn(AppLocalizations.localeCode, task),
            keyboard: battleWantsNumericKeyboard(task)
                ? TextInputType.number
                : TextInputType.text,
            submitted: _playerLock != null || reveal,
            detail: _playerLock?.detail ?? '',
            exact: _playerLock?.exact ?? false,
            answerKey: reveal ? battleAnswerKey(task) : '',
            onSubmit: _lockPlayerRecall,
          ),
        },
        if (reveal) ...[const SizedBox(height: 12), _feedbackCard(task)],
        const SizedBox(height: 12),
        _botStatus(reveal: reveal, blindLabel: tr('btd_blind_ans')),
      ],
    );
  }

  /// SAM detail labels for the AI illustration, shown at reveal so the
  /// player can check the recalled detail against what the model segmented.
  /// Gated on a real image: labels without a picture would be misleading.
  Widget _samLabels(MetaTask task) {
    if (task.imageUrl.isEmpty || task.stations.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          tr('duel_sam_title'),
          style: TextStyle(
            color: context.mutedText,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final label in task.stations.take(6))
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: teal,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _ticker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF45A3FF), Color(0xFF1F6FC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _sideLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '$_playerTotal : $_foeTotal',
            key: const ValueKey('duel-ticker'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          Expanded(
            child: Text(
              _foeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Corrective feedback: your answer, the key, the partial-credit detail and
  /// the technique line with its citation. Feedback roughly doubles the
  /// testing effect (Rowland 2014).
  Widget _feedbackCard(MetaTask task) {
    final lock = _playerLock;
    final yours = (lock == null || lock.response.isEmpty) ? '—' : lock.response;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (lock?.exact ?? false)
            ? const Color(0xFF16A34A).withValues(alpha: 0.08)
            : context.softBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('btd_yours', {'a': yours}),
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (lock?.detail.isNotEmpty ?? false)
                ? tr('btd_correct_detail', {
                    'a': battleAnswerKey(task),
                    'd': lock!.detail,
                  })
                : tr('btd_correct', {'a': battleAnswerKey(task)}),
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (task.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.explanation,
              style: TextStyle(
                color: context.mutedText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          if (task.source.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.source,
              style: TextStyle(
                color: context.mutedText,
                fontStyle: FontStyle.italic,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _RoundComment(
            key: ValueKey('duel-comment-$_questionIndex'),
            paradigm: task.paradigm,
            correct: widget.spectate
                ? (_botLocks[widget.home!.id]?.correct ?? false)
                : (_playerLock?.correct ?? false),
          ),
        ],
      ),
    );
  }

  Widget _optionButton(MetaTask task, int index, bool reveal) {
    final locked = _playerLock != null;
    final picked = _playerLock?.answer == index;
    final isCorrect = task.correct == index;
    Color border = context.hairline;
    Color bg = context.cardBg;
    if (reveal) {
      if (isCorrect) {
        border = const Color(0xFF16A34A);
        bg = const Color(0xFF16A34A).withValues(alpha: 0.1);
      } else if (picked) {
        border = const Color(0xFFDC2626);
        bg = const Color(0xFFDC2626).withValues(alpha: 0.08);
      }
    } else if (picked) {
      border = violet;
      bg = violet.withValues(alpha: 0.1);
    }
    return GestureDetector(
      onTap: locked || reveal ? null : () => _lockPlayerChoice(index),
      child: Container(
        key: ValueKey('duel-option-$index'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                task.options[index],
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            if (reveal && isCorrect)
              const HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Color(0xFF16A34A),
                size: 20,
                strokeWidth: 2.2,
              ),
            if (reveal && picked && !isCorrect)
              const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                color: Color(0xFFDC2626),
                size: 20,
                strokeWidth: 2.2,
              ),
          ],
        ),
      ),
    );
  }

  /// Bot panel. Blind until reveal: showing who already locked would let the
  /// player stall out the remaining clock after the foe commits.
  Widget _botStatus({required bool reveal, required String blindLabel}) {
    final task = _tasks.isEmpty ? null : _tasks[_questionIndex];
    final binary =
        task != null && _responseKindFor(task) == BattleResponseKind.choice4;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.softBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        children: [
          for (final entry in _bots)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (entry.isFoe ? amber : teal).withValues(alpha: 0.16),
                    ),
                    child: Text(
                      entry.bot.name.characters.first,
                      style: TextStyle(
                        color: entry.isFoe ? amber : teal,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.isFoe
                          ? entry.bot.name
                          : widget.spectate
                          ? entry.bot.name
                          : tr('btd_ally', {'name': entry.bot.name}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.inkText,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    reveal ? _botRevealLabel(entry.bot.id, binary) : blindLabel,
                    style: TextStyle(color: context.mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _botRevealLabel(String botId, bool binary) {
    final lock = _botLocks[botId];
    if (lock == null) return tr('btd_no_answer');
    final pts = BattleScore.questionPoints(
      correct: lock.correct,
      latencyMs: lock.ms,
      clockMs: _recallMs,
      proportion: binary ? null : lock.proportion,
      exact: lock.exact,
    );
    return tr('btd_bot_done', {'n': pts});
  }

  Widget _rewardLine({
    required List<List<dynamic>> icon,
    required String label,
    required int xp,
    bool total = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          HugeIcon(
            icon: icon,
            color: total ? violetDark : amber,
            size: 16,
            strokeWidth: 2.2,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.inkText,
                fontWeight: total ? FontWeight.w900 : FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '+$xp XP',
            style: TextStyle(
              color: total ? violetDark : const Color(0xFF16A34A),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultView() {
    final outcome = _outcome ?? BattleOutcome.draw;
    final wins = _rounds.where((r) => r.playerCorrect).length;
    final title = widget.spectate
        ? tr('btd_over')
        : switch (outcome) {
            BattleOutcome.win => tr('btd_victory'),
            BattleOutcome.loss => tr('btd_defeat'),
            BattleOutcome.draw => tr('btd_draw'),
          };
    final color = switch (outcome) {
      BattleOutcome.win => const Color(0xFF16A34A),
      BattleOutcome.loss => const Color(0xFFDC2626),
      BattleOutcome.draw => violet,
    };
    return ListView(
      key: const ValueKey('duel-result'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_playerTotal : $_foeTotal',
                style: TextStyle(
                  color: context.inkText,
                  fontWeight: FontWeight.w900,
                  fontSize: 44,
                ),
              ),
              Text(
                tr('btd_versus', {'a': _sideLabel, 'b': _foeLabel}),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedText, fontSize: 12),
              ),
              if (!widget.spectate) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: context.hairline, width: 2),
                      ),
                      child: Text(
                        tr('btd_delta', {
                          's': _delta >= 0 ? '+' : '',
                          'd': _delta,
                        }),
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: violet.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '+$_xp XP',
                        style: const TextStyle(
                          color: violetDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_dailyBonus > 0 || _streakBonus > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: context.hairline,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_dailyBonus > 0)
                          _rewardLine(
                            icon: HugeIcons.strokeRoundedGift,
                            label: tr('btd_reward_first'),
                            xp: _dailyBonus,
                          ),
                        if (_streakBonus > 0)
                          _rewardLine(
                            icon: HugeIcons.strokeRoundedFire02,
                            label: tr('btd_reward_streak'),
                            xp: _streakBonus,
                          ),
                        _rewardLine(
                          icon: HugeIcons.strokeRoundedStar,
                          label: tr('btd_reward_total'),
                          xp: _xp + _dailyBonus + _streakBonus,
                          total: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  tr('btd_show_no_score'),
                  style: TextStyle(color: context.mutedText, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DuelRecap(wins: wins, rounds: _questionCount),
        const SizedBox(height: 12),
        EngramButton(
          key: const ValueKey('duel-rematch'),
          label: tr('btd_rematch'),
          icon: HugeIcons.strokeRoundedRefresh,
          onPressed: _rematch,
        ),
        const SizedBox(height: 8),
        if (!widget.spectate)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop('new'),
              child: Text(tr('btd_new_opp')),
            ),
          ),
        if (!widget.spectate) const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('btd_exit')),
          ),
        ),
      ],
    );
  }
}

class _DuelHype extends StatefulWidget {
  final String foeName;
  final String kindLabel;
  const _DuelHype({required this.foeName, required this.kindLabel});

  @override
  State<_DuelHype> createState() => _DuelHypeState();
}

class _DuelHypeState extends State<_DuelHype> {
  late final Future<CoachAnswer> _future = MetaAIService.duelHype(
    foeName: widget.foeName,
    kindLabel: widget.kindLabel,
    locale: AppLocalizations.localeCode,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CoachAnswer>(
      future: _future,
      builder: (context, snap) {
        final text = snap.data?.text ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.hairline, width: 2),
          ),
          child: Column(
            children: [
              Text(
                tr('duel_hype_title'),
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.inkText,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundComment extends StatefulWidget {
  final String paradigm;
  final bool correct;
  const _RoundComment({super.key, required this.paradigm, required this.correct});

  @override
  State<_RoundComment> createState() => _RoundCommentState();
}

class _RoundCommentState extends State<_RoundComment> {
  late final Future<CoachAnswer> _future = MetaAIService.duelRoundComment(
    paradigm: widget.paradigm,
    correct: widget.correct,
    locale: AppLocalizations.localeCode,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CoachAnswer>(
      future: _future,
      builder: (context, snap) {
        final text = snap.data?.text ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('duel_round_title'),
              style: TextStyle(
                color: context.mutedText,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: TextStyle(
                color: context.inkText,
                fontStyle: FontStyle.italic,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DuelRecap extends StatefulWidget {
  final int wins;
  final int rounds;
  const _DuelRecap({required this.wins, required this.rounds});

  @override
  State<_DuelRecap> createState() => _DuelRecapState();
}

class _DuelRecapState extends State<_DuelRecap> {
  late final Future<CoachAnswer> _future = MetaAIService.sessionRecap(
    correct: widget.wins,
    total: widget.rounds,
    trackLabel: 'duel',
    locale: AppLocalizations.localeCode,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CoachAnswer>(
      future: _future,
      builder: (context, snap) {
        final text = snap.data?.text ?? '';
        if (text.isEmpty) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.hairline, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('duel_ai_title'),
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: context.inkText,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Static 3x3 encode stimulus: the lit cells to memorize. Shown briefly,
/// then replaced by the blank picker at recall.
class _BattleGridStimulus extends StatelessWidget {
  final List<int> cells;
  const _BattleGridStimulus({required this.cells});

  @override
  Widget build(BuildContext context) {
    final lit = cells.toSet();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: violet.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < 3; row++)
            Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var col = 0; col < 3; col++)
                    Container(
                      key: ValueKey('duel-stimulus-cell-${row * 3 + col}'),
                      width: 48,
                      height: 48,
                      margin: EdgeInsets.only(left: col == 0 ? 0 : 8),
                      decoration: BoxDecoration(
                        color: lit.contains(row * 3 + col)
                            ? teal
                            : context.hairline,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Blank 3x3 recall picker: tap every lit cell, then DONE. Order-free —
/// the paradigm scores the set with false-alarm penalty.
class _BattleCellPicker extends StatefulWidget {
  final bool submitted;
  final ValueChanged<List<int>> onDone;
  const _BattleCellPicker({
    super.key,
    required this.onDone,
    this.submitted = false,
  });

  @override
  State<_BattleCellPicker> createState() => _BattleCellPickerState();
}

class _BattleCellPickerState extends State<_BattleCellPicker> {
  final _selected = <int>{};

  void _toggle(int cell) {
    if (widget.submitted) return;
    setState(() {
      if (_selected.contains(cell)) {
        _selected.remove(cell);
      } else {
        _selected.add(cell);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.hairline, width: 2),
          ),
          child: Column(
            children: [
              for (var row = 0; row < 3; row++)
                Padding(
                  padding: EdgeInsets.only(top: row == 0 ? 0 : 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var col = 0; col < 3; col++)
                        Builder(
                          builder: (_) {
                            final cell = row * 3 + col;
                            final on = _selected.contains(cell);
                            return GestureDetector(
                              key: ValueKey('duel-cell-$cell'),
                              onTap: () => _toggle(cell),
                              child: Container(
                                width: 52,
                                height: 52,
                                margin: EdgeInsets.only(
                                  left: col == 0 ? 0 : 8,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: on ? teal : context.softBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: on ? teal : context.hairline,
                                    width: 2,
                                  ),
                                ),
                                child: on
                                    ? const HugeIcon(
                                        icon: HugeIcons
                                            .strokeRoundedCheckmarkCircle02,
                                        color: Colors.white,
                                        size: 22,
                                        strokeWidth: 2.2,
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selected.isEmpty
              ? tr('btd_cells_hint')
              : tr('btd_cells_n', {'n': _selected.length}),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedText, fontSize: 12),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          key: const ValueKey('duel-cells-done'),
          onTap: widget.submitted ? null : () => widget.onDone(_selected.toList()),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.submitted ? context.hairline : teal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              tr('btd_done'),
              style: TextStyle(
                color: widget.submitted ? context.mutedText : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
