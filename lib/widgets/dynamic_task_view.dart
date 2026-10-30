import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../models/dynamic_task.dart';
import '../theme/app_theme.dart';
import 'app_buttons.dart';

class DynamicTaskView extends StatefulWidget {
  final DynamicTask task;
  final void Function(DynamicTaskResult result)? onDone;

  const DynamicTaskView({super.key, required this.task, this.onDone});

  @override
  State<DynamicTaskView> createState() => _DynamicTaskViewState();
}

class _DynamicTaskViewState extends State<DynamicTaskView> {
  final Set<String> _done = {};
  final Map<String, bool> _correct = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<bool>> _checks = {};
  final Map<String, List<int>> _orderPicks = {};
  final Map<String, List<int>> _orderShown = {};
  final Map<String, int?> _picked = {};
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    for (final b in widget.task.blocks) {
      if (b.type == DynamicBlockType.checklist) {
        _checks[b.id] = List<bool>.filled(b.options.length, false);
      }
      if (b.type == DynamicBlockType.order) {
        _orderShown[b.id] = _shuffledOrder(b);
        _orderPicks[b.id] = [];
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<int> _shuffledOrder(DynamicBlock b) {
    final n = b.options.length;
    final order = List<int>.generate(n, (i) => i);
    var h = Object.hash(widget.task.id, b.id);
    for (var i = n - 1; i > 0; i--) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      final j = h % (i + 1);
      final t = order[i];
      order[i] = order[j];
      order[j] = t;
    }
    var solved = true;
    for (var i = 0; i < n; i++) {
      if (order[i] != i) solved = false;
    }
    if (solved && n > 1) {
      final t = order[0];
      order[0] = order[1];
      order[1] = t;
    }
    return order;
  }

  int get _total => widget.task.blocks.length;
  int get _answered => _done.length;

  DynamicTaskResult get _result {
    var keyed = 0;
    var correct = 0;
    for (final b in widget.task.blocks) {
      if (_isKeyed(b)) {
        keyed++;
        if (_correct[b.id] == true) correct++;
      }
    }
    return DynamicTaskResult(
      answered: _answered,
      total: _total,
      correct: correct,
      keyed: keyed,
    );
  }

  bool _isKeyed(DynamicBlock b) {
    switch (b.type) {
      case DynamicBlockType.choice:
      case DynamicBlockType.order:
        return true;
      case DynamicBlockType.text:
      case DynamicBlockType.date:
      case DynamicBlockType.phone:
        return b.answer.trim().isNotEmpty;
      default:
        return false;
    }
  }

  void _markDone(DynamicBlock b, {bool? correct}) {
    setState(() {
      _done.add(b.id);
      if (correct != null) _correct[b.id] = correct;
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone?.call(_result);
  }

  @override
  Widget build(BuildContext context) {
    final done = _answered >= _total && _total > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('dtask_progress', {
                  'title': widget.task.title,
                  'done': _answered,
                  'total': _total,
                }),
                style: TextStyle(
                  color: context.mutedText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          key: const ValueKey('dynamic-progress'),
          value: _total == 0 ? 0 : _answered / _total,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 12),
        Text(
          widget.task.instructions,
          style: TextStyle(
            color: context.inkText,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        for (final b in widget.task.blocks) _blockCard(b),
        if (widget.task.source.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.task.source,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.mutedText,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (done && !_finished)
          EngramButton(
            key: const ValueKey('dynamic-finish'),
            label: tr('dtask_finish'),
            onPressed: _finish,
          ),
        if (_finished)
          Text(
            _result.keyed == 0
                ? tr('dtask_done_compare')
                : tr('dtask_keyed', {
                    'correct': _result.correct,
                    'keyed': _result.keyed,
                  }),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.mutedText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
      ],
    );
  }

  Widget _blockCard(DynamicBlock b) {
    return Container(
      key: ValueKey('dynamic-block-${b.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.faintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.label,
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              if (_done.contains(b.id))
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  color: Color(0xFF14B8A6),
                  size: 20,
                  strokeWidth: 2.2,
                ),
            ],
          ),
          if (b.hint.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              b.hint,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          switch (b.type) {
            DynamicBlockType.info => _infoBlock(b),
            DynamicBlockType.choice => _choiceBlock(b),
            DynamicBlockType.text ||
            DynamicBlockType.date ||
            DynamicBlockType.phone => _textBlock(b),
            DynamicBlockType.checklist => _checklistBlock(b),
            DynamicBlockType.order => _orderBlock(b),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }

  Widget _infoBlock(DynamicBlock b) {
    if (_done.contains(b.id)) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        key: ValueKey('dynamic-gotit-${b.id}'),
        onPressed: () => _markDone(b),
        child: Text(tr('dtask_got_it')),
      ),
    );
  }

  Widget _choiceBlock(DynamicBlock b) {
    final picked = _picked[b.id];
    final right = int.tryParse(b.answer.trim()) ?? -1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < b.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              key: ValueKey('dynamic-option-${b.id}-$i'),
              onTap: _done.contains(b.id)
                  ? null
                  : () {
                      setState(() => _picked[b.id] = i);
                      _markDone(b, correct: i == right);
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: picked != null && i == right
                      ? const Color(0xFF14B8A6).withValues(alpha: 0.14)
                      : picked != null && i == picked
                      ? const Color(0xFFFF6B6B).withValues(alpha: 0.12)
                      : context.washBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: picked != null && i == right
                        ? const Color(0xFF14B8A6)
                        : picked != null && i == picked
                        ? const Color(0xFFFF6B6B)
                        : context.faintBorder,
                    width: 2,
                  ),
                ),
                child: Text(
                  b.options[i],
                  style: TextStyle(
                    color: context.inkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _textBlock(DynamicBlock b) {
    final controller = _controllers.putIfAbsent(
      b.id,
      () => TextEditingController(),
    );
    final done = _done.contains(b.id);
    final keyed = b.answer.trim().isNotEmpty;
    final ok = _correct[b.id] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: ValueKey('dynamic-input-${b.id}'),
          controller: controller,
          enabled: !done,
          keyboardType: b.type == DynamicBlockType.phone
              ? TextInputType.phone
              : TextInputType.text,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            hintText: b.hint.isEmpty ? tr('dtask_type_hint') : b.hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          style: TextStyle(color: context.inkText, fontSize: 15),
        ),
        const SizedBox(height: 8),
        if (!done)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: ValueKey('dynamic-submit-${b.id}'),
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                if (keyed) {
                  _markDone(
                    b,
                    correct: dynamicTextCorrect(b.answer, text),
                  );
                } else {
                  _markDone(b);
                }
              },
              child: Text(tr('dtask_check')),
            ),
          ),
        if (done)
          Text(
            keyed
                ? (ok
                      ? tr('dtask_correct')
                      : tr('dtask_wrong', {'answer': b.answer}))
                : tr('dtask_done_source'),
            style: TextStyle(
              color: keyed && !ok ? const Color(0xFFFF6B6B) : context.mutedText,
              fontSize: 13,
            ),
          ),
      ],
    );
  }

  Widget _checklistBlock(DynamicBlock b) {
    final checks = _checks[b.id] ?? const <bool>[];
    void toggle(int i, bool? v) {
      if (_done.contains(b.id)) return;
      setState(() {
        _checks[b.id]![i] = v ?? false;
        if (_checks[b.id]!.every((e) => e)) {
          _done.add(b.id);
        }
      });
    }

    return Column(
      children: [
        for (var i = 0; i < b.options.length; i++)
          GestureDetector(
            key: ValueKey('dynamic-checklist-${b.id}-$i'),
            onTap: _done.contains(b.id) ? null : () => toggle(i, true),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: i < checks.length && checks[i],
                    onChanged: _done.contains(b.id)
                        ? null
                        : (v) => toggle(i, v),
                  ),
                  Expanded(
                    child: Text(
                      b.options[i],
                      style: TextStyle(color: context.inkText, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _orderBlock(DynamicBlock b) {
    final shown = _orderShown[b.id] ?? const <int>[];
    final picks = _orderPicks[b.id] ?? const <int>[];
    final done = _done.contains(b.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var s = 0; s < shown.length; s++)
              ActionChip(
                key: ValueKey('dynamic-order-pick-${b.id}-$s'),
                label: Text(b.options[shown[s]]),
                onPressed:
                    done || picks.contains(shown[s])
                    ? null
                    : () => setState(() => _orderPicks[b.id]!.add(shown[s])),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          picks.isEmpty
              ? tr('dtask_tap_order')
              : tr('dtask_your_order', {
                  'order': [for (final p in picks) b.options[p]].join(' → '),
                }),
          style: TextStyle(color: context.mutedText, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (!done)
          Row(
            children: [
              OutlinedButton(
                key: ValueKey('dynamic-order-clear-${b.id}'),
                onPressed: picks.isEmpty
                    ? null
                    : () => setState(() => _orderPicks[b.id]!.clear()),
                child: Text(tr('dtask_clear')),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: ValueKey('dynamic-order-check-${b.id}'),
                onPressed: picks.length == b.options.length
                    ? () {
                        var exact = true;
                        for (var i = 0; i < picks.length; i++) {
                          if (picks[i] != i) exact = false;
                        }
                        _markDone(b, correct: exact);
                      }
                    : null,
                child: Text(tr('dtask_check_order')),
              ),
            ],
          ),
        if (done)
          Text(
            _correct[b.id] == true
                ? tr('dtask_order_ok')
                : tr('dtask_order_wrong', {
                    'order': b.options.join(' → '),
                  }),
            style: TextStyle(
              color: _correct[b.id] == true
                  ? context.mutedText
                  : const Color(0xFFFF6B6B),
              fontSize: 13,
            ),
          ),
      ],
    );
  }
}
