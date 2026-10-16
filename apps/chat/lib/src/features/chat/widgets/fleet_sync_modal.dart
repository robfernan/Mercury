import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/mercury_theme.dart';

/// Modal dialog for Phase 3: Multi-Device Fleet Synchronization
/// - One-Scan QR Noise-IK device pairing
/// - Cross-device universal clipboard & fast AirDrop file drop
/// - Unified notification & read-state acknowledgment
class FleetSyncModal extends ConsumerStatefulWidget {
  const FleetSyncModal({super.key});

  @override
  ConsumerState<FleetSyncModal> createState() => _FleetSyncModalState();
}

class _FleetSyncModalState extends ConsumerState<FleetSyncModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _clipInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clipInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = ref.watch(fleetSyncServiceProvider);
    final devicesAsync = ref.watch(fleetDevicesStreamProvider);
    final devices = devicesAsync.value ?? fleet.devices;
    final clipAsync = ref.watch(fleetClipboardStreamProvider);
    final clipHistory = clipAsync.value ?? fleet.clipboardHistory;

    return Dialog(
      backgroundColor: MercuryColors.surfaceRaised,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MercuryColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780, maxHeight: 660),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: MercuryColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.devices_rounded, color: MercuryColors.accent, size: 22),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Multi-Device Fleet Synchronization',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Noise-IK QR enrollment · Universal clipboard · AirDrop drop · Unified read alerts',
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
            // Navigation Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: MercuryColors.accent,
              labelColor: MercuryColors.accent,
              unselectedLabelColor: MercuryColors.textMuted,
              tabs: const [
                Tab(icon: Icon(Icons.phonelink_setup_rounded), text: 'Trusted Devices & QR Pairing'),
                Tab(icon: Icon(Icons.content_paste_rounded), text: 'Universal Clipboard & File Drop'),
              ],
            ),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Trusted Devices & QR Enrollment
                  _buildDevicesTab(context, fleet, devices),
                  // Tab 2: Universal Clipboard & File Drop
                  _buildClipboardTab(context, fleet, clipHistory),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevicesTab(
    BuildContext context,
    FleetSyncService fleet,
    List<FleetDevice> devices,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // QR Enrollment Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MercuryColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MercuryColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stylized QR Box representation
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 70, color: Colors.black),
                    Text(
                      'NOISE-IK',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text(
                          'One-Scan Fleet Enrollment',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: MercuryColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.verified_rounded, size: 16, color: MercuryColors.success),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Open Mercury on your Wacom Studio, Debian Laptop, or Moondrop MIAD01 phone, tap "Scan Pair QR", and point the camera here to cross-sign with an ephemeral Noise-IK cryptographic handshake.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: MercuryColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MercuryColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          label: const Text('Refresh Session EPK'),
                          onPressed: () {
                            fleet.generateEnrollmentQr();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('New Noise-IK ephemeral key generated (expires in 5 min)'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: MercuryColors.textPrimary,
                            side: const BorderSide(color: MercuryColors.border),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          label: const Text('Copy Invite URI'),
                          onPressed: () {
                            final payload = fleet.generateEnrollmentQr();
                            Clipboard.setData(ClipboardData(text: payload.toQrString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enrollment URI copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        // Enrolled Devices List
        Row(
          children: [
            const Text(
              'CURRENT TRUSTED FLEET',
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
                color: MercuryColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${devices.length} devices enrolled',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MercuryColors.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: MercuryColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MercuryColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < devices.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: MercuryColors.border),
                _FleetDeviceTile(
                  device: devices[i],
                  onRevoke: devices[i].isCurrentDevice
                      ? null
                      : () => setState(() => fleet.revokeDevice(devices[i].id)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClipboardTab(
    BuildContext context,
    FleetSyncService fleet,
    List<FleetSharedItem> clipHistory,
  ) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Universal Input Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MercuryColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MercuryColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.sync_alt_rounded, size: 18, color: MercuryColors.accent),
                  SizedBox(width: 8),
                  Text(
                    'Push to Fleet Clipboard & AirDrop',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: MercuryColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _clipInputController,
                      decoration: InputDecoration(
                        hintText: 'Type text, code snippet, or link to broadcast to all devices...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: MercuryColors.textMuted),
                        filled: true,
                        fillColor: MercuryColors.surfaceRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: MercuryColors.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MercuryColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Broadcast', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      final text = _clipInputController.text.trim();
                      if (text.isNotEmpty) {
                        fleet.shareClipboardText(text);
                        _clipInputController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pushed to fleet clipboard!')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Drop File to Devices (AirDrop Equivalent)',
                    icon: const Icon(Icons.file_upload_outlined, color: MercuryColors.accent),
                    style: IconButton.styleFrom(
                      backgroundColor: MercuryColors.surfaceRaised,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      fleet.dropFile(fileName: 'concept_artwork_4k.png', sizeBytes: 8421000);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Simulated file drop to fleet devices')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        // Live Clipboard Stream
        const Text(
          'FLEET CLIPBOARD HISTORY',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: MercuryColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: MercuryColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MercuryColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < clipHistory.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: MercuryColors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MercuryColors.surfaceRaised,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          clipHistory[i].isFileName == true
                              ? Icons.image_rounded
                              : Icons.copy_all_rounded,
                          size: 18,
                          color: MercuryColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clipHistory[i].content,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: MercuryColors.textPrimary,
                              ),
                            ),
                            Text(
                              'From ${clipHistory[i].originDeviceName} · ${_formatTimeAgo(clipHistory[i].timestamp)}',
                              style: const TextStyle(fontSize: 11, color: MercuryColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy to Local Clipboard',
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: clipHistory[i].content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied to system clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _FleetDeviceTile extends StatelessWidget {
  const _FleetDeviceTile({
    required this.device,
    this.onRevoke,
  });

  final FleetDevice device;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    if (device.deviceType.contains('Desktop')) {
      icon = Icons.computer_rounded;
    } else if (device.deviceType.contains('Stylus') || device.deviceType.contains('Drawing')) {
      icon = Icons.draw_rounded;
    } else if (device.deviceType.contains('Phone') || device.deviceType.contains('Android')) {
      icon = Icons.phone_android_rounded;
    } else {
      icon = Icons.laptop_chromebook_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: MercuryColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: MercuryColors.textPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: MercuryColors.textPrimary,
                      ),
                    ),
                    if (device.isCurrentDevice) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MercuryColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'THIS DEVICE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: MercuryColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.deviceType} · ${device.ipAddress ?? "LAN"} · Key: ${device.ed25519PublicKey}',
                  style: const TextStyle(fontSize: 11.5, color: MercuryColors.textMuted),
                ),
              ],
            ),
          ),
          if (onRevoke != null)
            IconButton(
              tooltip: 'Revoke Device Access',
              icon: const Icon(Icons.delete_outline_rounded, color: MercuryColors.danger, size: 18),
              onPressed: onRevoke,
            )
          else
            const Icon(Icons.check_circle_rounded, color: MercuryColors.success, size: 18),
        ],
      ),
    );
  }
}
