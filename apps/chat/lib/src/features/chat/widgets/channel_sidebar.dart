import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models.dart';
import '../../../data/seed_data.dart';
import '../../../routing/routes.dart';
import '../../../theme/mercury_theme.dart';
import '../state/chat_providers.dart';
import 'user_avatar.dart';
import 'user_status_footer.dart';
import 'web4_network_modal.dart';
import 'fleet_sync_modal.dart';
import 'wacom_canvas_modal.dart';

/// Second column: server header, categorised channels, and the user footer.
class ChannelSidebar extends ConsumerWidget {
  const ChannelSidebar({
    super.key,
    required this.serverId,
    required this.activeChannelId,
  });

  final String serverId;
  final String activeChannelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(serverByIdProvider(serverId));
    final channels = ref.watch(channelsForServerProvider(serverId));

    // Preserve declaration order of categories.
    final categories = <String, List<ChatChannel>>{};
    for (final c in channels) {
      categories.putIfAbsent(c.category, () => []).add(c);
    }

    return Container(
      width: 248,
      color: MercuryColors.sidebar,
      child: SafeArea(
        left: false,
        right: false,
        child: Column(
          children: [
            _ServerHeader(name: server?.name ?? 'Unknown server'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                children: [
                  for (final entry in categories.entries)
                    _Category(
                      title: entry.key,
                      children: [
                        for (final c in entry.value)
                          c.kind == ChannelKind.voice
                              ? _VoiceChannelTile(channel: c)
                              : _TextChannelTile(
                                  channel: c,
                                  active: c.id == activeChannelId,
                                ),
                      ],
                    ),
                ],
              ),
            ),
            const UserStatusFooter(),
          ],
        ),
      ),
    );
  }
}

class _ServerHeader extends StatelessWidget {
  const _ServerHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MercuryColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Web4 P2P & LAN Mesh Network',
            icon: const Icon(
              Icons.hub_rounded,
              size: 19,
              color: MercuryColors.accent,
            ),
            splashRadius: 18,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const Web4NetworkModal(),
            ),
          ),
          IconButton(
            tooltip: 'Multi-Device Fleet & AirDrop',
            icon: const Icon(
              Icons.devices_rounded,
              size: 19,
              color: Color(0xFF3FA7D6),
            ),
            splashRadius: 18,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const FleetSyncModal(),
            ),
          ),
          IconButton(
            tooltip: 'Wacom Live Canvas (Stylus EMR)',
            icon: const Icon(
              Icons.draw_rounded,
              size: 19,
              color: Color(0xFFE8A33D),
            ),
            splashRadius: 18,
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const WacomCanvasModal(),
            ),
          ),
          const SizedBox(width: 4),
          const Tooltip(
            message: 'End-to-end encrypted (hybrid PQ-MLS)',
            child: Icon(
              Icons.verified_user_rounded,
              size: 18,
              color: MercuryColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _Category extends StatefulWidget {
  const _Category({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  State<_Category> createState() => _CategoryState();
}

class _CategoryState extends State<_Category> {
  var _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 16, 8, 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(
                    Icons.expand_more_rounded,
                    size: 14,
                    color: MercuryColors.textMuted,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  widget.title.toUpperCase(),
                  style: const TextStyle(
                    color: MercuryColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _TextChannelTile extends ConsumerWidget {
  const _TextChannelTile({required this.channel, required this.active});

  final ChatChannel channel;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadProvider.select((u) => u[channel.id] ?? 0));
    final hasUnread = unread > 0 && !active;
    final color = active || hasUnread
        ? MercuryColors.textPrimary
        : MercuryColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active ? MercuryColors.surfaceHover : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          hoverColor: MercuryColors.surface,
          onTap: () {
            Scaffold.maybeOf(context)?.closeDrawer();
            context.go(Routes.channel(channel.serverId, channel.id));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
                children: [
                  Icon(Icons.tag_rounded, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      channel.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 14.5,
                        fontWeight: hasUnread || active
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: MercuryColors.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

class _VoiceChannelTile extends ConsumerWidget {
  const _VoiceChannelTile({required this.channel});

  final ChatChannel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceProvider);
    final users = ref.watch(usersProvider);
    final joined = voice.connectedChannelId == channel.id;

    final occupants = [
      for (final id in SeedData.voiceOccupants[channel.id] ?? const <String>[])
        ?users[id],
      if (joined) ref.watch(currentUserProvider),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Material(
            color: joined ? MercuryColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              hoverColor: MercuryColors.surface,
              onTap: () {
                final notifier = ref.read(voiceProvider.notifier);
                joined ? notifier.leave() : notifier.join(channel.id);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      size: 18,
                      color: joined
                          ? MercuryColors.success
                          : MercuryColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        channel.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: joined
                              ? MercuryColors.textPrimary
                              : MercuryColors.textSecondary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: joined ? 'Leave voice' : 'Join voice',
                      child: Icon(
                        joined ? Icons.call_end_rounded : Icons.call_rounded,
                        size: 15,
                        color: joined
                            ? MercuryColors.danger
                            : MercuryColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        for (final user in occupants)
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2),
            child: Row(
              children: [
                UserAvatar(user: user, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: MercuryColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
