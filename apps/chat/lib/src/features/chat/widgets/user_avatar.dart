import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../theme/mercury_theme.dart';

Color presenceColor(Presence p) => switch (p) {
  Presence.online => MercuryColors.success,
  Presence.idle => MercuryColors.warning,
  Presence.doNotDisturb => MercuryColors.danger,
  Presence.offline => MercuryColors.textMuted,
};

String presenceLabel(Presence p) => switch (p) {
  Presence.online => 'Online',
  Presence.idle => 'Idle',
  Presence.doNotDisturb => 'Do Not Disturb',
  Presence.offline => 'Offline',
};

/// Initials avatar with an optional presence badge. Real avatars will come
/// from encrypted blobs in object storage; initials keep the shell offline.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.showPresence = false,
    this.badgeBorderColor = MercuryColors.surface,
  });

  final ChatUser user;
  final double size;
  final bool showPresence;
  final Color badgeBorderColor;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            user.avatarColor,
            Color.lerp(user.avatarColor, Colors.black, 0.35)!,
          ],
        ),
      ),
      child: Text(
        user.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );

    final semanticLabel = showPresence
        ? '${user.displayName}, ${presenceLabel(user.presence)}'
        : user.displayName;

    if (!showPresence) return Semantics(label: semanticLabel, child: avatar);

    final dot = size * 0.32;
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar,
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: presenceColor(user.presence),
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeBorderColor, width: dot * 0.22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
