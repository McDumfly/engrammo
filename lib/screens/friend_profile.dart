import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_kit.dart';
import '../services/app_feedback.dart';
import '../models/battle_invites.dart';
import '../services/bot_arena_store.dart';
import '../services/memory_store.dart';
import 'battle_duel_page.dart';
import '../theme/app_colors.dart' show blue, blueDark, orange, success, teal;

class FriendProfilePage extends StatelessWidget {
  final BattleFriend friend;
  final String? botId;
  const FriendProfilePage({super.key, required this.friend, this.botId});

  void _toggleInvite() {
    if (battleInvites.isInvited(friend.name)) {
      AppFeedback.light();
      battleInvites.withdraw(friend.name);
    } else {
      AppFeedback.medium();
      battleInvites.invite(friend.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppTopBar(
        title: friend.name,
        leading: const EngramBackButton(),
        actions: const [
          AiHelpButton(topic: AiHelpTopics.battle),
          SizedBox(width: 12),
        ],
      ),
      body: ListenableBuilder(
        listenable: battleInvites,
        builder: (context, _) {
          return ListenableBuilder(
            listenable: botArena,
            builder: (context, _) {
              final live = botId == null ? null : botArena.botById(botId!);
              final shown = live == null ? friend : botArena.botToFriend(live);
              final invited = battleInvites.isInvited(shown.name);
              final added = live != null && botArena.isFriend(live.id);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _HeroCard(friend: shown),
                  if (live != null) ...[
                    const SizedBox(height: 8),
                    _BotTierLine(tier: live.tierLabel, rating: live.rating),
                  ],
                  const SizedBox(height: 12),
                  _StatsRow(friend: shown),
                  const SizedBox(height: 16),
                  EngramButton(
                    label: invited
                        ? tr('friend_withdraw')
                        : tr('friend_challenge'),
                    icon: invited
                        ? HugeIcons.strokeRoundedCheckmarkCircle02
                        : HugeIcons.strokeRoundedSwords,
                    haptic: false,
                    onPressed: _toggleInvite,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    invited
                        ? tr('friend_got', {'name': shown.name})
                        : tr('friend_send', {'name': shown.name}),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.mutedText,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  if (live != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: EngramButton(
                        height: 52,
                        onPressed: () async {
                          AppFeedback.medium();
                          final kind = await MemoryStore.resolveBattleKind(6);
                          if (!context.mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BattleDuelPage.duel(
                                opponent: live,
                                kind: kind,
                              ),
                            ),
                          );
                        },
                        label: tr('friend_now'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: EngramButton(
                        variant: EngramButtonVariant.secondary,
                        height: 52,
                        onPressed: () {
                          if (added) {
                            AppFeedback.light();
                            botArena.removeFriend(live.id);
                          } else {
                            AppFeedback.medium();
                            botArena.addFriend(live.id);
                          }
                        },
                        label: added ? tr('friend_remove') : tr('friend_add'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CompareCard(botId: live.id),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final BattleFriend friend;
  const _HeroCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blue.withValues(alpha: 0.14),
                  border: Border.all(
                    color: blue.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Text(
                  friend.name.characters.first,
                  style: TextStyle(
                    color: context.accentText(blueDark),
                    fontWeight: FontWeight.w900,
                    fontSize: 40,
                  ),
                ),
              ),
              if (friend.online)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: success,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.cardBg, width: 3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            friend.name,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: friend.online
                  ? success.withValues(alpha: 0.12)
                  : context.inkText.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              friend.online ? tr('friend_online') : tr('friend_offline'),
              style: TextStyle(
                color: friend.online ? success : context.mutedText,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final BattleFriend friend;
  const _StatsRow({required this.friend});

  @override
  Widget build(BuildContext context) {
    final h2h = botArena.headToHead(friend.name);
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: HugeIcons.strokeRoundedStar,
            color: blue,
            value: tr('friend_xp', {'n': friend.xp}),
            label: tr('friend_total_xp'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: HugeIcons.strokeRoundedFire,
            color: orange,
            value: tr('friend_streak_value', {'n': friend.streak}),
            label: tr('friend_streak'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: HugeIcons.strokeRoundedSwords,
            color: teal,
            value: '${h2h.wins}W–${h2h.losses}L',
            label: tr('friend_h2h'),
          ),
        ),
      ],
    );
  }
}

class _BotTierLine extends StatelessWidget {
  final String tier;
  final int rating;
  const _BotTierLine({required this.tier, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            tr('friend_tier', {'tier': tier, 'rating': rating}),
            style: TextStyle(
              color: context.accentText(blueDark),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareCard extends StatelessWidget {
  final String botId;
  const _CompareCard({required this.botId});

  @override
  Widget build(BuildContext context) {
    final bot = botArena.botById(botId);
    if (bot == null) return const SizedBox.shrink();
    final me = botArena.headToHead(bot.name);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('friend_you_vs', {'name': bot.name}),
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          _CompareRow(
            label: tr('friend_score'),
            me: '${botArena.playerRating}',
            foe: '${bot.rating}',
          ),
          _CompareRow(
            label: tr('friend_total_xp'),
            me: '${botArena.totalXp}',
            foe: '${bot.xp}',
          ),
          _CompareRow(
            label: tr('friend_streak'),
            me: tr('friend_streak_value', {'n': botArena.playerStreak}),
            foe: tr('friend_streak_value', {'n': bot.streak}),
          ),
          _CompareRow(
            label: tr('friend_h2h'),
            me: tr('friend_record', {'w': me.wins, 'd': me.draws}),
            foe: tr('friend_foe_wins', {'l': me.losses}),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final String me;
  final String foe;
  const _CompareRow({required this.label, required this.me, required this.foe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: context.mutedText, fontSize: 12),
            ),
          ),
          Text(
            me,
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              ':',
              style: TextStyle(color: context.mutedText, fontSize: 13),
            ),
          ),
          Text(
            foe,
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final String value;
  final String label;
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.hairline, width: 2),
      ),
      child: Column(
        children: [
          HugeIcon(icon: icon, color: color, size: 20, strokeWidth: 2.2),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: context.inkText,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          Text(label, style: TextStyle(color: context.mutedText, fontSize: 12)),
        ],
      ),
    );
  }
}
