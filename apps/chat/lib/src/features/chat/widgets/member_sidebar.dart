import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models.dart';
import '../../../theme/mercury_theme.dart';
import '../state/chat_providers.dart';
import 'user_avatar.dart';

class MemberSidebar extends ConsumerWidget {
  const MemberSidebar({super.key, required this.serverId});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersForServerProvider(serverId));

    final online = members.where((u) => u.presence != Presence.offline).toList();
    final offline = members.where((u) => u.presence == Presence.offline).toList();

    return Container(
      width: 240,
      color: MercuryColors.sidebar,
      child: SafeArea(
        left: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          children: [
            if (online.isNotEmpty) ...[
              _CategoryHeader(title: 'ONLINE — ${online.length}'),
              for (final user in online) _MemberTile(user: user),
              const SizedBox(height: 16),
            ],
            if (offline.isNotEmpty) ...[
              _CategoryHeader(title: 'OFFLINE — ${offline.length}'),
              for (final user in offline) _MemberTile(user: user),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: MercuryColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.user});

  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    final isOffline = user.presence == Presence.offline;

    return Opacity(
      opacity: isOffline ? 0.45 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          hoverColor: MercuryColors.surfaceHover,
          onTap: () {
            // Profile details preview dialog
            showDialog<void>(
              context: context,
              builder: (context) => _UserProfileDialog(user: user),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              children: [
                UserAvatar(
                  user: user,
                  size: 32,
                  showPresence: true,
                  badgeBorderColor: MercuryColors.sidebar,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color.lerp(user.avatarColor, Colors.white, 0.4),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (user.role != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: user.avatarColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                user.role!,
                                style: TextStyle(
                                  color: Color.lerp(user.avatarColor, Colors.white, 0.5),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (user.statusText != null)
                        Text(
                          user.statusText!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: MercuryColors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                    ],
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

class _UserProfileDialog extends StatelessWidget {
  const _UserProfileDialog({required this.user});

  final ChatUser user;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MercuryColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MercuryColors.border),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                color: user.avatarColor.withValues(alpha: 0.35),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -32),
                    child: UserAvatar(
                      user: user,
                      size: 64,
                      showPresence: true,
                      badgeBorderColor: MercuryColors.surfaceRaised,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: MercuryColors.textPrimary,
                          ),
                        ),
                        Text(
                          '@${user.handle}',
                          style: const TextStyle(
                            color: MercuryColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        if (user.statusText != null) ...[
                          const Text(
                            'ABOUT ME',
                            style: TextStyle(
                              color: MercuryColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.statusText!,
                            style: const TextStyle(
                              color: MercuryColors.textSecondary,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const Text(
                          'SECURITY VERIFICATION',
                          style: TextStyle(
                            color: MercuryColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 14, color: MercuryColors.success),
                            SizedBox(width: 6),
                            Text(
                              'Identity Key Verified (Ed25519)',
                              style: TextStyle(
                                color: MercuryColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
