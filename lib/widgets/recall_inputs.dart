library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart' show blueDark, tealDark;
import '../theme/app_theme.dart';

class RecallTextField extends StatefulWidget {
  final String hint;
  final TextInputType keyboard;
  final bool submitted;
  final String detail;
  final bool exact;
  final String answerKey;
  final ValueChanged<String> onSubmit;
  const RecallTextField({
    super.key,
    required this.hint,
    required this.onSubmit,
    this.keyboard = TextInputType.text,
    this.submitted = false,
    this.detail = '',
    this.exact = false,
    this.answerKey = '',
  });

  @override
  State<RecallTextField> createState() => _RecallTextFieldState();
}

class _RecallTextFieldState extends State<RecallTextField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.submitted) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('recall-input'),
          controller: _controller,
          enabled: !widget.submitted,
          keyboardType: widget.keyboard,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          maxLines: widget.keyboard == TextInputType.multiline ? 4 : 1,
          minLines: 1,
          style: TextStyle(
            color: context.inkText,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: context.mutedText, fontSize: 14),
            filled: true,
            fillColor: context.cardBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.hairline, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: context.hairline, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: blueDark,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (!widget.submitted)
          Semantics(
            button: true,
            label: tr('recall_check_answer'),
            child: GestureDetector(
              key: const ValueKey('recall-check'),
              onTap: _submit,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: const BoxDecoration(
                  color: blueDark,
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF134E8A),
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: ExcludeSemantics(
                  child: Text(
                    tr('recall_check'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.exact
                  ? const Color(0xFF14B8A6).withValues(alpha: 0.12)
                  : context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.exact
                    ? const Color(0xFF14B8A6)
                    : context.hairline,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.detail.isEmpty ? tr('recall_checked') : widget.detail,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (widget.answerKey.isNotEmpty && !widget.exact) ...[
                  const SizedBox(height: 4),
                  Text(
                    tr('recall_answer', {'key': widget.answerKey}),
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class CorsiSequenceStimulus extends StatefulWidget {
  final List<int> sequence;
  final Duration startDelay;
  final Duration onTime;
  final Duration gap;
  const CorsiSequenceStimulus({
    super.key,
    required this.sequence,
    this.startDelay = const Duration(milliseconds: 500),
    this.onTime = const Duration(milliseconds: 650),
    this.gap = const Duration(milliseconds: 350),
  });

  @override
  State<CorsiSequenceStimulus> createState() => _CorsiSequenceStimulusState();
}

class _CorsiSequenceStimulusState extends State<CorsiSequenceStimulus> {
  int? _lit;
  bool _playing = false;
  int _playId = 0;

  bool _replayUsed = false;

  bool _paused = false;
  static const _speeds = [0.5, 1.0, 2.0];
  static const _speedNames = ['0.5×', '1×', '2×'];
  int _speedIndex = 1;

  double get _speed => _speeds[_speedIndex];

  @override
  void initState() {
    super.initState();
    _play();
  }

  @override
  void didUpdateWidget(covariant CorsiSequenceStimulus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sequence != widget.sequence) {
      _replayUsed = false;
      _play();
    }
  }

  @override
  void dispose() {
    _playId++;
    super.dispose();
  }

  void _replay() {
    if (_replayUsed) return;
    setState(() => _replayUsed = true);
    unawaited(_play());
  }

  void _togglePause() {
    if (!_playing) return;
    setState(() => _paused = !_paused);
  }

  void _cycleSpeed() {
    setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length);
  }

  Future<bool> _wait(Duration base, int id) async {
    var remainingUs = base.inMicroseconds.toDouble();
    const sliceUs = 50000.0;
    while (remainingUs > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted || id != _playId) return false;
      if (!_paused) remainingUs -= sliceUs * _speed;
    }
    return mounted && id == _playId;
  }

  Future<void> _play() async {
    final id = ++_playId;
    setState(() {
      _lit = null;
      _playing = true;
      _paused = false;
    });
    if (!await _wait(widget.startDelay, id)) return;
    for (final cell in widget.sequence) {
      if (!mounted || id != _playId) return;
      setState(() => _lit = cell);
      if (!await _wait(widget.onTime, id)) return;
      setState(() => _lit = null);
      if (!await _wait(widget.gap, id)) return;
    }
    if (!mounted || id != _playId) return;
    setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: context.cardBg,
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
                        Builder(
                          builder: (_) {
                            final cell = row * 3 + col;
                            final lit = _lit == cell;
                            return Semantics(
                              label: tr('recall_seq_cell', {
                                'cell': cell + 1,
                                'state': lit
                                    ? tr('recall_lit')
                                    : tr('recall_unlit'),
                              }),
                              child: Container(
                                key: ValueKey('corsi-stimulus-cell-$cell'),
                                width: 52,
                                height: 52,
                                margin: EdgeInsets.only(
                                  left: col == 0 ? 0 : 8,
                                ),
                                decoration: BoxDecoration(
                                  color: lit ? tealDark : context.hairline,
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
          _playing
              ? (_paused ? tr('recall_paused') : tr('recall_watch'))
              : _replayUsed
              ? tr('recall_replay_used')
              : tr('recall_replay_hint'),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.mutedText, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                enabled: _playing,
                label: _paused ? tr('recall_resume') : tr('recall_pause'),
                child: GestureDetector(
                  key: const ValueKey('corsi-pause'),
                  onTap: _playing ? _togglePause : null,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: BoxDecoration(
                      color: _playing ? context.cardBg : context.hairline,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.hairline, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Text(
                        _paused ? tr('recall_resume_btn') : tr('recall_pause_btn'),
                        style: TextStyle(
                          color: _playing
                              ? context.inkText
                              : context.mutedText,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                button: true,
                label: tr('recall_speed'),
                value: _speedNames[_speedIndex],
                child: GestureDetector(
                  key: const ValueKey('corsi-speed'),
                  onTap: _cycleSpeed,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.hairline, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Text(
                        tr('recall_speed_btn', {
                          'v': _speedNames[_speedIndex],
                        }),
                        style: TextStyle(
                          color: context.inkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                button: true,
                enabled: !_replayUsed,
                label: tr('recall_replay'),
                child: GestureDetector(
                  key: const ValueKey('corsi-replay'),
                  onTap: _replayUsed ? null : _replay,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: BoxDecoration(
                      color: _replayUsed
                          ? context.hairline
                          : context.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.hairline, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Text(
                        tr('recall_replay_btn'),
                        style: TextStyle(
                          color: _replayUsed
                              ? context.mutedText
                              : context.inkText,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CorsiTapGrid extends StatefulWidget {
  final bool submitted;
  final ValueChanged<List<int>> onDone;
  const CorsiTapGrid({
    super.key,
    required this.onDone,
    this.submitted = false,
  });

  @override
  State<CorsiTapGrid> createState() => _CorsiTapGridState();
}

class _CorsiTapGridState extends State<CorsiTapGrid> {
  final _taps = <int>[];

  void _tap(int cell) {
    if (widget.submitted || _taps.contains(cell)) return;
    setState(() => _taps.add(cell));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.hairline, width: 2),
          ),
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
                        Builder(
                          builder: (_) {
                            final cell = row * 3 + col;
                            final order = _taps.indexOf(cell);
                            return Semantics(
                              button: true,
                              label: tr('recall_cell', {
                                'cell': cell + 1,
                                'state': order >= 0
                                    ? tr('recall_selected', {
                                        'pos': order + 1,
                                      })
                                    : tr('recall_unselected'),
                              }),
                              child: GestureDetector(
                                key: ValueKey('corsi-cell-$cell'),
                                onTap: () => _tap(cell),
                                child: Container(
                                  width: 52,
                                  height: 52,
                                  margin: EdgeInsets.only(
                                    left: col == 0 ? 0 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: order >= 0
                                        ? tealDark
                                        : context.hairline,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: order >= 0
                                      ? ExcludeSemantics(
                                          child: Text(
                                            '${order + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
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
        if (!widget.submitted)
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  enabled: _taps.isNotEmpty,
                  label: tr('recall_undo'),
                  child: GestureDetector(
                    key: const ValueKey('corsi-undo'),
                    onTap: _taps.isEmpty
                        ? null
                        : () => setState(() => _taps.removeLast()),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.hairline, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: ExcludeSemantics(
                        child: Text(
                          tr('recall_undo_btn'),
                          style: TextStyle(
                            color: context.mutedText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Semantics(
                  button: true,
                  enabled: _taps.isNotEmpty,
                  label: tr('recall_submit'),
                  child: GestureDetector(
                    key: const ValueKey('corsi-done'),
                    onTap: _taps.isEmpty
                        ? null
                        : () => widget.onDone(List.of(_taps)),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _taps.isEmpty
                            ? context.hairline
                            : blueDark,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _taps.isEmpty
                            ? null
                            : const [
                                BoxShadow(
                                  color: Color(0xFF134E8A),
                                  offset: Offset(0, 4),
                                ),
                              ],
                      ),
                      alignment: Alignment.center,
                      child: ExcludeSemantics(
                        child: Text(
                          tr('recall_done'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
