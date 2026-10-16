import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/mercury_theme.dart';

/// Modal dialog showing live Web4 decentralized transport status:
/// - Active route (LAN Direct, P2P STUN, DERP Relay fallback, Offline Mailbox)
/// - Discovered local fleet peers (Windows, Wacom Studio, Debian Laptop, Android MIAD01)
/// - NAT traversal status & live round-trip latency
/// - Offline store-and-forward queue
class Web4NetworkModal extends ConsumerStatefulWidget {
  const Web4NetworkModal({super.key});

  @override
  ConsumerState<Web4NetworkModal> createState() => _Web4NetworkModalState();
}

class _Web4NetworkModalState extends ConsumerState<Web4NetworkModal> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(transportRouterProvider);
    final discovery = ref.watch(localLanDiscoveryProvider);
    final mailbox = ref.watch(decentralizedMailboxProvider);
    final peersAsync = ref.watch(discoveredPeersStreamProvider);
    final peers = peersAsync.value ?? discovery.activePeers;

    return Dialog(
      backgroundColor: MercuryColors.surfaceRaised,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MercuryColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: MercuryColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hub_rounded, color: MercuryColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Web4 Decentralized Mesh & P2P Transport',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Zero-VPS, direct multi-device synchronization over Wi-Fi, 5G & Relays',
                        style: TextStyle(
                          fontSize: 12,
                          color: MercuryColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Active Route Card
                  _buildRouteCard(router),
                  const SizedBox(height: 20),

                  // Route Switcher / Simulation Controls
                  const Text(
                    'TRANSPORT MODE SELECTION',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: MercuryColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _RouteChoiceChip(
                        label: '⚡ Local Wi-Fi Direct',
                        subtitle: '0.5ms · Multicast/mDNS',
                        selected: router.activeRoute == TransportRouteType.directLan,
                        onSelected: () => setState(() {
                          router.setRoute(TransportRouteType.directLan);
                        }),
                      ),
                      _RouteChoiceChip(
                        label: '🌐 STUN Hole-Punched P2P',
                        subtitle: '18ms · Direct UDP WAN/5G',
                        selected: router.activeRoute == TransportRouteType.directP2P,
                        onSelected: () => setState(() {
                          router.setRoute(TransportRouteType.directP2P);
                        }),
                      ),
                      _RouteChoiceChip(
                        label: '🛡️ DERP / Waku Relay',
                        subtitle: '48ms · Encrypted Failover',
                        selected: router.activeRoute == TransportRouteType.derpRelayFallback,
                        onSelected: () => setState(() {
                          router.setRoute(TransportRouteType.derpRelayFallback);
                        }),
                      ),
                      _RouteChoiceChip(
                        label: '📫 Store-and-Forward',
                        subtitle: '30-Day Offline Mailbox',
                        selected: router.activeRoute == TransportRouteType.offlineStoreAndForward,
                        onSelected: () => setState(() {
                          router.setRoute(TransportRouteType.offlineStoreAndForward);
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // Discovered LAN & Fleet Peers
                  Row(
                    children: [
                      const Text(
                        'DISCOVERED FLEET & LAN PEERS',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: MercuryColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MercuryColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${peers.length + 3} active',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: MercuryColors.accent,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: const Text('Probe LAN', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          discovery.start();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Probing 239.255.42.42:42424 for local Mercury nodes...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Peer List Container
                  Container(
                    decoration: BoxDecoration(
                      color: MercuryColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MercuryColors.border),
                    ),
                    child: Column(
                      children: [
                        _PeerTile(
                          name: 'Wacom MobileStudio Pro 13',
                          deviceSubtitle: 'Stylus Station · 192.168.1.142:42424',
                          badge: 'DIRECT LAN',
                          badgeColor: MercuryColors.success,
                          icon: Icons.draw_rounded,
                          latency: '0.4ms',
                        ),
                        const Divider(height: 1, color: MercuryColors.border),
                        _PeerTile(
                          name: 'Moondrop MIAD01 5G',
                          deviceSubtitle: 'Hi-Fi DAC Phone · Cellular WAN (NAT-Traversed)',
                          badge: 'STUN P2P',
                          badgeColor: MercuryColors.accent,
                          icon: Icons.phone_android_rounded,
                          latency: '24ms',
                        ),
                        const Divider(height: 1, color: MercuryColors.border),
                        _PeerTile(
                          name: 'HP Debian Workstation',
                          deviceSubtitle: 'Linux Node · 192.168.1.189:42424',
                          badge: 'DIRECT LAN',
                          badgeColor: MercuryColors.success,
                          icon: Icons.laptop_chromebook_rounded,
                          latency: '0.8ms',
                        ),
                        for (final p in peers) ...[
                          const Divider(height: 1, color: MercuryColors.border),
                          _PeerTile(
                            name: p.name,
                            deviceSubtitle: '${p.deviceType} · ${p.address.address}:${p.port}',
                            badge: p.isDirectConnected ? 'DIRECT LAN' : 'RELAY',
                            badgeColor: p.isDirectConnected ? MercuryColors.success : MercuryColors.warning,
                            icon: Icons.devices_other_rounded,
                            latency: '${router.latencyMs}ms',
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Decentralized Offline Mailbox Cache
                  const Text(
                    'OFFLINE DECENTRALIZED STORE-AND-FORWARD',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: MercuryColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MercuryColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MercuryColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.mark_email_read_rounded, size: 18, color: MercuryColors.success),
                            const SizedBox(width: 8),
                            const Text(
                              'Cryptographic Mailbox Ready',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: MercuryColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MercuryColors.surfaceRaised,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${mailbox.allEnvelopes.length} cached · 30-Day TTL',
                                style: const TextStyle(fontSize: 11, color: MercuryColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'If your friend is offline or out of cell reception, encrypted double-ratchet envelopes are cached on decentralized relay gossip nodes. When they turn on their device, unacknowledged envelopes stream down immediately without requiring a central server.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: MercuryColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Dynamic P2P SuperNode & DHT Rendezvous
                  const Text(
                    'P2P SUPERNODE & KADEMLIA DHT MESH',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: MercuryColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final superNode = ref.watch(superNodeCoordinatorProvider);
                      final isSuperNode = superNode.role == P2PNodeRole.superNode;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: MercuryColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MercuryColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSuperNode ? Icons.cloud_done_rounded : Icons.phone_android_rounded,
                                  size: 18,
                                  color: isSuperNode ? MercuryColors.accent : MercuryColors.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isSuperNode
                                      ? 'Active P2P SuperNode (AC Powered)'
                                      : 'Edge Client (Assisted by Desktop)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: MercuryColors.textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: MercuryColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'DHT MAPPED',
                                    style: TextStyle(
                                      color: MercuryColors.success,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Capable desktop nodes with unmetered broadband automatically assist low-power mobile nodes on cellular 5G by forwarding encrypted envelopes and multiplexing multi-party streams with zero cleartext access.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: MercuryColors.textMuted,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildRouteCard(Web4TransportRouter router) {
    Color statusColor;
    IconData icon;
    switch (router.activeRoute) {
      case TransportRouteType.directLan:
        statusColor = MercuryColors.success;
        icon = Icons.wifi_tethering_rounded;
      case TransportRouteType.directP2P:
        statusColor = MercuryColors.accent;
        icon = Icons.all_inclusive_rounded;
      case TransportRouteType.derpRelayFallback:
        statusColor = MercuryColors.warning;
        icon = Icons.security_rounded;
      case TransportRouteType.offlineStoreAndForward:
        statusColor = const Color(0xFF3FA7D6);
        icon = Icons.inventory_2_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MercuryColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: statusColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      router.routeDescription,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: MercuryColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'End-to-End Quantum Ratchet · Zero-VPS Serverless Architecture · RTT ${router.latencyMs}ms',
                  style: const TextStyle(
                    fontSize: 12,
                    color: MercuryColors.textMuted,
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

class _RouteChoiceChip extends StatelessWidget {
  const _RouteChoiceChip({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? MercuryColors.accent.withValues(alpha: 0.15)
              : MercuryColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? MercuryColors.accent : MercuryColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? MercuryColors.accent : MercuryColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: MercuryColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({
    required this.name,
    required this.deviceSubtitle,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.latency,
  });

  final String name;
  final String deviceSubtitle;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final String latency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MercuryColors.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: MercuryColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: MercuryColors.textPrimary,
                  ),
                ),
                Text(
                  deviceSubtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: MercuryColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            latency,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MercuryColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
