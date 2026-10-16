import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/crypto_engine.dart';
import '../../../core/gateway/gateway_client.dart';
import '../../../core/providers.dart';
import '../../../theme/mercury_theme.dart';
import '../state/chat_providers.dart';
import 'user_avatar.dart';

/// Bottom of the channel sidebar: voice connection banner + local user
/// identity with mic / deafen / settings controls.
class UserStatusFooter extends ConsumerWidget {
  const UserStatusFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final voice = ref.watch(voiceProvider);
    final voiceNotifier = ref.read(voiceProvider.notifier);
    final voiceChannel = voice.connectedChannelId == null
        ? null
        : ref.watch(channelByIdProvider(voice.connectedChannelId!));

    return Container(
      decoration: const BoxDecoration(
        color: MercuryColors.rail,
        border: Border(top: BorderSide(color: MercuryColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: voiceChannel == null
                ? const SizedBox(width: double.infinity)
                : _VoiceBanner(
                    channelName: voiceChannel.name,
                    onDisconnect: voiceNotifier.leave,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
            child: Row(
              children: [
                UserAvatar(
                  user: me,
                  size: 34,
                  showPresence: true,
                  badgeBorderColor: MercuryColors.rail,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        me.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        me.statusText ?? '@${me.handle}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: MercuryColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _FooterButton(
                  tooltip: voice.muted ? 'Unmute' : 'Mute',
                  icon: voice.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  danger: voice.muted,
                  onPressed: voiceNotifier.toggleMute,
                ),
                _FooterButton(
                  tooltip: voice.deafened ? 'Undeafen' : 'Deafen',
                  icon: voice.deafened
                      ? Icons.headset_off_rounded
                      : Icons.headset_rounded,
                  danger: voice.deafened,
                  onPressed: voiceNotifier.toggleDeafen,
                ),
                _FooterButton(
                  tooltip: 'Security & diagnostics',
                  icon: Icons.settings_rounded,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const _DiagnosticsDialog(),
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

class _VoiceBanner extends StatelessWidget {
  const _VoiceBanner({required this.channelName, required this.onDisconnect});

  final String channelName;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: MercuryColors.border)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.signal_cellular_alt_rounded,
            size: 18,
            color: MercuryColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice Connected',
                  style: TextStyle(
                    color: MercuryColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$channelName · E2EE (PQ-MLS)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: MercuryColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          _FooterButton(
            tooltip: 'Disconnect',
            icon: Icons.call_end_rounded,
            onPressed: onDisconnect,
          ),
        ],
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 19,
      visualDensity: VisualDensity.compact,
      color: danger ? MercuryColors.danger : MercuryColors.textSecondary,
      icon: Icon(icon),
    );
  }
}

/// Shows which engines are active so nobody mistakes a mock build for a
/// secure one.
class _DiagnosticsDialog extends ConsumerWidget {
  const _DiagnosticsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crypto = ref.watch(cryptoEngineProvider);
    final gateway = ref.watch(gatewayClientProvider);
    final connection = ref.watch(connectionStateProvider);

    return AlertDialog(
      backgroundColor: MercuryColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      title: const Text('Security & diagnostics'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!crypto.isSecure)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MercuryColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MercuryColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: MercuryColors.warning, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Development build: messages use a mock cipher and are '
                        'NOT end-to-end encrypted.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            _Row('Crypto engine', crypto.displayName),
            FutureBuilder<IdentityPublicKey>(
              future: crypto.loadIdentity(),
              builder: (context, snap) =>
                  _Row('Identity fingerprint', snap.data?.fingerprint ?? '…'),
            ),
            _Row('Gateway', gateway.runtimeType.toString()),
            _Row('Connection', switch (connection) {
              GatewayConnectionState.connected => 'Connected',
              GatewayConnectionState.connecting => 'Connecting…',
              GatewayConnectionState.reconnecting => 'Reconnecting…',
              GatewayConnectionState.disconnected => 'Disconnected',
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: MercuryColors.textMuted),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
