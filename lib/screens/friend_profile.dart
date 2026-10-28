import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../services/app_feedback.dart';
import '../models/battle_invites.dart';
import 'memory_profile.dart' show violet, violetDark, teal;

/// A friend's public profile.
///
/// Opened from the leaderboard "Friends" tab. Besides the usual stats it
/// offers the "Invite to battle" action, which shares its state with the
/// Battle Zone friend search through [battleInvites].
class FriendProfilePage extends StatelessWidget {
  final BattleFriend friend;
  const FriendProfilePage({super.key, required this.friend});

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
      ),
      body: ListenableBuilder(
        listenable: battleInvites,
        builder: (context, _) {
          final invited = battleInvites.isInvited(friend.name);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _HeroCard(friend: friend),
              const SizedBox(height: 12),
              _StatsRow(friend: friend),
              const SizedBox(height: 16),
              EngramButton(
                label: invited ? 'INVITED — TAP TO CANCEL' : 'INVITE TO BATTLE',
                icon: invited
                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                    : HugeIcons.strokeRoundedSwords,
                // A kezelő adja a jelzést (light/medium), a gomb nem rezeg rá.
                haptic: false,
                onPressed: _toggleInvite,
              ),
              const SizedBox(height: 10),
              Text(
                invited
                    ? '${friend.name} has your invite. They can accept it from their battles inbox.'
                    : 'Send ${friend.name} a 1v1 invite with your current game mode.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.mutedText,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
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
              friend.online ? 'Online now' : 'Offline',
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
            value: '${friend.xp} XP',
            label: 'Total XP',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: HugeIcons.strokeRoundedFire,
            color: const Color(0xFFF97316),
            value: '${friend.streak}-day',
            label: 'Streak',
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _StatTile(
            icon: HugeIcons.strokeRoundedSwords,
            color: teal,
            value: '1v1',
            label: 'Battle',
          ),
        ),
      ],
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
