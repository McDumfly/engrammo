import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../services/app_feedback.dart';
import '../services/meta_ai_service.dart';
import '../theme/app_theme.dart';
import 'app_buttons.dart';

class AiHelpTopics {
  static const String general = 'general';
  static const String lesson = 'lesson';
  static const String path = 'path';
  static const String assessment = 'assessment';
  static const String battle = 'battle';
  static const String benchmark = 'benchmark';
  static const String league = 'league';
  static const String settings = 'settings';
  static const String goals = 'goals';
}

List<String> quickPromptsFor(String topic) {
  switch (topic) {
    case AiHelpTopics.lesson:
      return [
        tr('help_q_station_doit'),
        tr('help_q_explain'),
        tr('help_q_example'),
        tr('help_q_late'),
        tr('help_q_level'),
      ];
    case AiHelpTopics.path:
      return [
        tr('help_q_unlock'),
        tr('help_q_stars'),
        tr('help_q_streak'),
        tr('help_q_engrams'),
        tr('help_q_level'),
      ];
    case AiHelpTopics.assessment:
      return [
        tr('help_q_test'),
        tr('help_q_level_calc'),
        tr('help_q_howlong'),
        tr('help_q_after'),
      ];
    case AiHelpTopics.battle:
      return [
        tr('help_q_duel'),
        tr('help_q_rating'),
        tr('help_q_level_calc'),
        tr('help_q_practice'),
      ];
    case AiHelpTopics.benchmark:
      return [
        tr('help_q_games_for'),
        tr('help_q_which_game'),
        tr('help_q_game_stars'),
      ];
    case AiHelpTopics.league:
      return [
        tr('help_q_ranking'),
        tr('help_q_climb'),
      ];
    case AiHelpTopics.settings:
      return [
        tr('help_q_key'),
        tr('help_q_theme'),
        tr('help_q_signout'),
      ];
    case AiHelpTopics.goals:
      return [
        tr('help_q_goals_for'),
        tr('help_q_material'),
        tr('help_q_goal_example'),
      ];
    default:
      return [
        tr('help_q_doit'),
        tr('help_q_simple'),
        tr('help_q_example'),
      ];
  }
}

class AiHelpButton extends StatelessWidget {
  final String topic;

  final String helpContext;
  const AiHelpButton({
    super.key,
    this.topic = AiHelpTopics.general,
    this.helpContext = '',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('ai-help-open'),
      onTap: () {
        AppFeedback.light();
        openAiHelpSheet(context, topic: topic, helpContext: helpContext);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: context.washBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedBubbleChatQuestion,
          color: Color(0xFF45A3FF),
          size: 24,
          strokeWidth: 2.2,
        ),
      ),
    );
  }
}

Future<void> openAiHelpSheet(
  BuildContext context, {
  String topic = AiHelpTopics.general,
  String helpContext = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AiHelpSheet(topic: topic, helpContext: helpContext),
  );
}

class _ChatMsg {
  final bool mine;
  final String text;
  final bool offline;
  const _ChatMsg({required this.mine, required this.text, this.offline = false});
}

class _AiHelpSheet extends StatefulWidget {
  final String topic;
  final String helpContext;
  const _AiHelpSheet({required this.topic, required this.helpContext});

  @override
  State<_AiHelpSheet> createState() => _AiHelpSheetState();
}

class _AiHelpSheetState extends State<_AiHelpSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_ChatMsg>[];
  bool _busy = false;
  String? _blockReason;

  static const int historyCap = 40;

  static String _historyKey(String topic) => 'ai_help_history_v1_$topic';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey(widget.topic));
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! List) return;
      final loaded = <_ChatMsg>[];
      for (final e in data) {
        if (e is Map<String, dynamic> &&
            (e['text'] as String? ?? '').isNotEmpty) {
          loaded.add(
            _ChatMsg(
              mine: (e['mine'] as bool?) ?? false,
              text: e['text'] as String,
              offline: (e['offline'] as bool?) ?? false,
            ),
          );
        }
      }
      if (!mounted || loaded.isEmpty) return;
      setState(() {
        _msgs.addAll(loaded.take(historyCap));
      });
      _jumpToEnd();
    } catch (_) {
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tail = _msgs.length > historyCap
          ? _msgs.sublist(_msgs.length - historyCap)
          : _msgs;
      await prefs.setString(
        _historyKey(widget.topic),
        jsonEncode([
          for (final m in tail)
            {'mine': m.mine, 'text': m.text, 'offline': m.offline},
        ]),
      );
    } catch (_) {
    }
  }

  Future<void> _clearHistory() async {
    setState(() => _msgs.clear());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey(widget.topic));
    } catch (_) {
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _msgs.add(_ChatMsg(mine: true, text: text));
      _busy = true;
    });
    _saveHistory();
    _jumpToEnd();
    _input.clear();
    CoachAnswer answer;
    try {
      answer = await MetaAIService.askCoach(
        text,
        topic: widget.topic,
        context: widget.helpContext,
      );
    } catch (_) {
      answer = CoachAnswer(
        text: MetaAIService.localCoachAnswer(text, topic: widget.topic),
      );
    }
    String? blockReason;
    if (answer.fallback) {
      try {
        if (!await MetaAIService.hasAnyKey()) {
          blockReason = 'nokey';
        } else if (!await MetaAIService.cloudConsent()) {
          blockReason = 'noconsent';
        }
      } catch (_) {
        blockReason = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _msgs.add(
        _ChatMsg(mine: false, text: answer.text, offline: answer.fallback),
      );
      _busy = false;
      _blockReason = blockReason;
    });
    _saveHistory();
    _jumpToEnd();
  }

  Future<void> _allowCloud() async {
    await MetaAIService.setCloudConsent(true);
    if (!mounted) return;
    setState(() {
      _blockReason = null;
      _msgs.add(
        _ChatMsg(
          mine: false,
          text: tr('help_cloud_on'),
        ),
      );
    });
    _saveHistory();
    _jumpToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final prompts = quickPromptsFor(widget.topic);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.washBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedBubbleChatQuestion,
                      color: Color(0xFF45A3FF),
                      size: 26,
                      strokeWidth: 2.2,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('help_title'),
                            style: TextStyle(
                              color: context.inkText,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr('help_subtitle'),
                            style: TextStyle(
                              color: context.mutedText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_msgs.isNotEmpty)
                      IconButton(
                        key: const ValueKey('ai-help-clear'),
                        tooltip: tr('help_clear'),
                        onPressed: _clearHistory,
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete02,
                          color: context.mutedText,
                          size: 24,
                          strokeWidth: 2,
                        ),
                      ),
                    IconButton(
                      key: const ValueKey('ai-help-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedMultiplicationSign,
                        color: context.mutedText,
                        size: 24,
                        strokeWidth: 2.2,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: context.washBorder,
              ),
              if (_blockReason != null) _offlineBanner(),
              Flexible(
                child: ListView(
                  controller: _scroll,
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    if (_msgs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          tr('help_empty'),
                          style: TextStyle(
                            color: context.mutedText,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ),
                    for (final m in _msgs) _bubble(m),
                    if (_busy)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.mutedText,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              tr('help_thinking'),
                              style: TextStyle(
                                color: context.mutedText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SingleChildScrollView(
                key: const ValueKey('ai-help-quick-row'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    for (var i = 0; i < prompts.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      ActionChip(
                        key: ValueKey('ai-help-quick-$i'),
                        label: Text(prompts[i]),
                        onPressed: _busy ? null : () => _send(prompts[i]),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: TextField(
                          key: const ValueKey('ai-help-input'),
                          controller: _input,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          textAlignVertical: TextAlignVertical.center,
                          onSubmitted: _send,
                          decoration: InputDecoration(
                            hintText: tr('help_hint'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 96,
                      child: EngramButton(
                        key: const ValueKey('ai-help-send'),
                        label: tr('help_send'),
                        height: 56,
                        isLoading: _busy,
                        onPressed: () => _send(_input.text),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offlineBanner() {
    final noKey = _blockReason == 'nokey';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        key: const ValueKey('ai-help-offline-banner'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.washBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.washBorder, width: 1.5),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: noKey
                  ? HugeIcons.strokeRoundedKey01
                  : HugeIcons.strokeRoundedShield01,
              color: const Color(0xFF45A3FF),
              size: 22,
              strokeWidth: 2,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                noKey ? tr('help_nokey') : tr('help_noconsent'),
                style: TextStyle(
                  color: context.inkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
            if (!noKey) ...[
              const SizedBox(width: 10),
              FilledButton(
                key: const ValueKey('ai-help-allow'),
                onPressed: _allowCloud,
                child: Text(tr('help_allow')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _messageText(_ChatMsg m) {
    final base = TextStyle(
      color: m.mine ? Colors.white : context.inkText,
      fontSize: 14,
      height: 1.45,
    );
    if (!_hasMarkdown(m.text)) return Text(m.text, style: base);
    return _CoachText(text: m.text, base: base, mine: m.mine);
  }

  Widget _bubble(_ChatMsg m) {
    return Align(
      alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: m.mine ? const Color(0xFF45A3FF) : context.washBg,
          borderRadius: BorderRadius.circular(14),
          border: m.mine
              ? null
              : Border.all(color: context.washBorder, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _messageText(m),
            if (!m.mine && m.offline)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tr('help_offline_tag'),
                  style: TextStyle(
                    color: context.mutedText,
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final _wordChar = RegExp(r'\w', unicode: true);

bool _isWordChar(String ch) => _wordChar.hasMatch(ch);

bool _hasMarkdown(String s) {
  if (s.contains('**') ||
      s.contains('__') ||
      s.contains('`') ||
      s.contains('~~')) {
    return true;
  }
  for (final line in s.split('\n')) {
    final t = line.trimLeft();
    if (t.startsWith('* ') ||
        t.startsWith('- ') ||
        t.startsWith('• ') ||
        t.startsWith('```') ||
        RegExp(r'^#{1,6}\s').hasMatch(t) ||
        RegExp(r'^\d{1,3}\.\s').hasMatch(t)) {
      return true;
    }
  }
  if (RegExp(r'\*[^*\s][^*]*\*').hasMatch(s)) return true;
  if (RegExp(r'(^|[^\w])_[^_\s][^_]*_([^\w]|$)').hasMatch(s)) return true;
  return false;
}

sealed class _Block {
  const _Block();
}

class _Para extends _Block {
  final String src;
  final bool header;
  const _Para(this.src, {this.header = false});
}

class _ListBlock extends _Block {
  final List<({String marker, String src})> items;
  const _ListBlock(this.items);
}

class _CodeBlock extends _Block {
  final String src;
  const _CodeBlock(this.src);
}

List<_Block> _parseBlocks(String text) {
  final blocks = <_Block>[];
  final para = <String>[];
  List<({String marker, String src})>? list;
  final code = <String>[];
  var inCode = false;

  void flushPara() {
    if (para.isEmpty) return;
    blocks.add(_Para(para.join('\n')));
    para.clear();
  }

  void flushList() {
    if (list == null || list!.isEmpty) return;
    blocks.add(_ListBlock(list!));
    list = null;
  }

  for (final raw in text.split('\n')) {
    final t = raw.trimRight().trimLeft();
    if (t.startsWith('```')) {
      if (inCode) {
        blocks.add(_CodeBlock(code.join('\n')));
        code.clear();
        inCode = false;
      } else {
        flushPara();
        flushList();
        inCode = true;
      }
      continue;
    }
    if (inCode) {
      code.add(raw);
      continue;
    }
    if (t.isEmpty) {
      flushPara();
      flushList();
      continue;
    }
    final header = RegExp(r'^#{1,6}\s').firstMatch(t);
    if (header != null) {
      flushPara();
      flushList();
      blocks.add(_Para(t.substring(header.end).trim(), header: true));
      continue;
    }
    final bullet = RegExp(r'^[*\-•]\s+').firstMatch(t);
    final numbered = RegExp(r'^(\d{1,3})\.\s+').firstMatch(t);
    if (bullet != null || numbered != null) {
      flushPara();
      list ??= [];
      list!.add((
        marker: numbered != null ? '${numbered.group(1)}.' : '•',
        src: t.substring((bullet ?? numbered)!.end).trim(),
      ));
      continue;
    }
    flushList();
    para.add(t);
  }
  flushPara();
  flushList();
  if (inCode || code.isNotEmpty) blocks.add(_CodeBlock(code.join('\n')));
  if (blocks.isEmpty) blocks.add(const _Para(''));
  return blocks;
}

bool _hasClosingUnderscore(String src, int from) {
  for (var j = from; j < src.length; j++) {
    if (src[j] != '_') continue;
    if (src.startsWith('__', j)) {
      j++;
      continue;
    }
    final next = j + 1 < src.length ? src[j + 1] : '';
    if (next.isEmpty || !_isWordChar(next)) return true;
  }
  return false;
}

List<TextSpan> _parseInline(String src, TextStyle base, TextStyle code) {
  final spans = <TextSpan>[];
  final buf = StringBuffer();
  var bold = false;
  var starItalic = false;
  var underItalic = false;
  var strike = false;

  void flush() {
    if (buf.isEmpty) return;
    var style = base;
    if (bold) style = style.copyWith(fontWeight: FontWeight.w800);
    if (starItalic || underItalic) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (strike) {
      style = style.copyWith(decoration: TextDecoration.lineThrough);
    }
    spans.add(TextSpan(text: buf.toString(), style: style));
    buf.clear();
  }

  bool openOk(int after) =>
      after < src.length &&
      src[after] != ' ' &&
      src[after] != '\n' &&
      src[after] != '\t';

  var i = 0;
  while (i < src.length) {
    if (src[i] == '`') {
      final end = src.indexOf('`', i + 1);
      if (end > i + 1) {
        flush();
        spans.add(TextSpan(text: src.substring(i + 1, end), style: code));
        i = end + 1;
        continue;
      }
      buf.write('`');
      i++;
      continue;
    }
    if (src.startsWith('**', i) || src.startsWith('__', i)) {
      final mark = src.substring(i, i + 2);
      if (bold || (openOk(i + 2) && src.indexOf(mark, i + 2) >= 0)) {
        flush();
        bold = !bold;
        i += 2;
        continue;
      }
      buf.write(mark);
      i += 2;
      continue;
    }
    if (src.startsWith('~~', i)) {
      if (strike || (openOk(i + 2) && src.indexOf('~~', i + 2) >= 0)) {
        flush();
        strike = !strike;
        i += 2;
        continue;
      }
      buf.write('~~');
      i += 2;
      continue;
    }
    if (src[i] == '*') {
      if (starItalic || (openOk(i + 1) && src.indexOf('*', i + 1) >= 0)) {
        flush();
        starItalic = !starItalic;
        i++;
        continue;
      }
      buf.write('*');
      i++;
      continue;
    }
    if (src[i] == '_') {
      if (underItalic) {
        final next = i + 1 < src.length ? src[i + 1] : '';
        if (next.isEmpty || !_isWordChar(next)) {
          flush();
          underItalic = false;
          i++;
          continue;
        }
        buf.write('_');
        i++;
        continue;
      }
      final prev = i == 0 ? '' : src[i - 1];
      if ((prev.isEmpty || !_isWordChar(prev)) &&
          openOk(i + 1) &&
          _hasClosingUnderscore(src, i + 1)) {
        flush();
        underItalic = true;
        i++;
        continue;
      }
      buf.write('_');
      i++;
      continue;
    }
    buf.write(src[i]);
    i++;
  }
  flush();
  if (spans.isEmpty) spans.add(TextSpan(text: src, style: base));
  return spans;
}

class _CoachText extends StatelessWidget {
  final String text;
  final TextStyle base;
  final bool mine;
  const _CoachText({required this.text, required this.base, required this.mine});

  @override
  Widget build(BuildContext context) {
    final codeBg = mine
        ? Colors.white.withValues(alpha: 0.22)
        : context.inkText.withValues(alpha: 0.08);
    final codeStyle = base.copyWith(backgroundColor: codeBg);
    final blocks = _parseBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _block(blocks[i], codeStyle, codeBg),
        ],
      ],
    );
  }

  Widget _block(_Block b, TextStyle codeStyle, Color codeBg) {
    switch (b) {
      case _Para(:final src, :final header):
        final style = header
            ? base.copyWith(fontWeight: FontWeight.w800, fontSize: 15)
            : base;
        return RichText(
          text: TextSpan(
            style: style,
            children: _parseInline(src, style, codeStyle),
          ),
        );
      case _ListBlock(:final items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var k = 0; k < items.length; k++) ...[
              if (k > 0) const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(items[k].marker, style: base),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: base,
                        children: _parseInline(items[k].src, base, codeStyle),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      case _CodeBlock(:final src):
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: codeBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(src, style: base),
        );
    }
  }
}
