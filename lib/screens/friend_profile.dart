import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_help_button.dart';
import '../widgets/app_buttons.dart';
import '../services/app_feedback.dart';
import '../models/battle_invites.dart';
import '../services/bot_arena_store.dart';
import '../services/memory_store.dart';
import 'battle_duel_page.dart';
import 'memory_profile.dart' show violet, violetDark, teal;

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
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const EngramBackButton(),
        title: Text(
          friend.name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
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
              final live = botId == null
                  ? null
                  : botArena.botById(botId!);
              final shown = live == null
                  ? friend
                  : botArena.botToFriend(live);
              final invited = battleInvites.isInvited(shown.name);
              final added = live != null && botArena.isFriend(live.id);
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _HeroCard(friend: shown),
                  if (live != null) ...[
                    const SizedBox(height: 8),
                    _BotTierLine(
                      tier: live.tierLabel,
                      rating: live.rating,
                    ),
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
                      child: ElevatedButton(
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
                        child: Text(tr('friend_now')),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          if (added) {
                            AppFeedback.light();
                            botArena.removeFriend(live.id);
                          } else {
                            AppFeedback.medium();
                            botArena.addFriend(live.id);
                          }
                        },
                        child: Text(
                          added ? tr('friend_remove') : tr('friend_add'),
                        ),
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
                  color: violet.withValues(alpha: 0.14),
                  border: Border.all(
                    color: violet.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Text(
                  friend.name.characters.first,
                  style: const TextStyle(
                    color: violetDark,
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
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
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
                  ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                  : context.inkText.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              friend.online ? tr('friend_online') : tr('friend_offline'),
              style: TextStyle(
                color: friend.online
                    ? const Color(0xFF15803D)
                    : context.mutedText,
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
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: HugeIcons.strokeRoundedStar,
            color: violet,
            value: tr('friend_xp', {'n': friend.xp}),
            label: tr('friend_total_xp'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: HugeIcons.strokeRoundedFire,
            color: const Color(0xFFF97316),
            value: tr('friend_streak_value', {'n': friend.streak}),
            label: tr('friend_streak'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: HugeIcons.strokeRoundedSwords,
            color: teal,
            value: '1v1',
            label: tr('friend_battle'),
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
            color: violet.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            tr('friend_tier', {'tier': tier, 'rating': rating}),
            style: const TextStyle(
              color: violetDark,
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
  const _CompareRow({
    required this.label,
    required this.me,
    required this.foe,
  });

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
          Text(label, style: TextStyle(color: context.mutedText, fontSize: 11)),
        ],
      ),
    );
  }
}
