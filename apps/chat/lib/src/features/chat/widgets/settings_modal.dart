import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/crypto/crypto_engine.dart';
import '../../../core/providers.dart';
import '../../../theme/mercury_theme.dart';
import '../../../theme/theme_state.dart';
import '../state/chat_providers.dart';
import 'user_avatar.dart';

class SettingsModal extends ConsumerStatefulWidget {
  const SettingsModal({super.key});

  @override
  ConsumerState<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends ConsumerState<SettingsModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _nameController;
  late final TextEditingController _statusController;

  static const _presetAccents = [
    Color(0xFF7C6CF2), // Mercury Violet
    Color(0xFF3DD68C), // Emerald Green
    Color(0xFF3FA7D6), // Cyber Blue
    Color(0xFFE5537A), // Hot Pink
    Color(0xFFE8A33D), // Amber Orange
    Color(0xFFB36AE2), // Neon Purple
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final me = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: me.displayName);
    _statusController = TextEditingController(text: me.statusText ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _pickWallpaper() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (files.isNotEmpty && files.first.path != null) {
      ref.read(themeStateProvider.notifier).updateWallpaper(
            (w) => w.copyWith(imagePath: files.first.path),
          );
    }
  }

  void _saveProfile() {
    final me = ref.read(currentUserProvider);
    final newName = _nameController.text.trim();
    final newStatus = _statusController.text.trim();
    if (newName.isNotEmpty) {
      ref.read(usersProvider.notifier).setProfile(
            userId: me.id,
            displayName: newName,
            statusText: newStatus.isEmpty ? null : newStatus,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeStateProvider);
    final themeNotifier = ref.read(themeStateProvider.notifier);
    final me = ref.watch(currentUserProvider);
    final crypto = ref.watch(cryptoEngineProvider);
    final gateway = ref.watch(gatewayClientProvider);

    return Dialog(
      backgroundColor: MercuryColors.surfaceRaised,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MercuryColors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
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
                  const Icon(Icons.tune_rounded, color: MercuryColors.accent),
                  const SizedBox(width: 10),
                  const Text(
                    'Settings & Preferences',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: MercuryColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Tab Navigation
            TabBar(
              controller: _tabController,
              indicatorColor: theme.accentColor,
              labelColor: theme.accentColor,
              unselectedLabelColor: MercuryColors.textMuted,
              tabs: const [
                Tab(icon: Icon(Icons.palette_outlined), text: 'Appearance & Customization'),
                Tab(icon: Icon(Icons.lock_outline_rounded), text: 'Security & E2EE Keys'),
                Tab(icon: Icon(Icons.mic_none_rounded), text: 'Audio & Device'),
              ],
            ),
            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Appearance & Wallpaper
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Profile Customization
                      const Text(
                        'MY PROFILE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          UserAvatar(user: me, size: 54, showPresence: true),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Display Name',
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _statusController,
                                  decoration: const InputDecoration(
                                    labelText: 'Status / Custom Bio',
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.accentColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 20),

                      // Accent Colors
                      const Text(
                        'ACCENT COLOR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        children: [
                          for (final color in _presetAccents)
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => themeNotifier.setAccentColor(color),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.accentColor == color
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 20),

                      // Wallpaper Controls
                      const Text(
                        'CHAT WALLPAPER & FILTERS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickWallpaper,
                            icon: const Icon(Icons.image_search_rounded),
                            label: const Text('Choose Wallpaper Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MercuryColors.surfaceHover,
                              foregroundColor: MercuryColors.textPrimary,
                            ),
                          ),
                          if (theme.wallpaper.imagePath != null) ...[
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () => themeNotifier.updateWallpaper(
                                    (w) => w.copyWith(clearImage: true),
                                  ),
                              child: const Text('Remove'),
                            ),
                          ],
                        ],
                      ),
                      if (theme.wallpaper.imagePath != null) ...[
                        const SizedBox(height: 16),
                        Text('Blur (${theme.wallpaper.blur.toStringAsFixed(1)}px)'),
                        Slider(
                          value: theme.wallpaper.blur,
                          min: 0,
                          max: 30,
                          activeColor: theme.accentColor,
                          onChanged: (v) => themeNotifier.updateWallpaper(
                                (w) => w.copyWith(blur: v),
                              ),
                        ),
                        Text('Opacity (${(theme.wallpaper.opacity * 100).toInt()}%)'),
                        Slider(
                          value: theme.wallpaper.opacity,
                          min: 0.1,
                          max: 1.0,
                          activeColor: theme.accentColor,
                          onChanged: (v) => themeNotifier.updateWallpaper(
                                (w) => w.copyWith(opacity: v),
                              ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Glassmorphism Blur Slider
                      Text('Glassmorphism Window Blur (${theme.glassmorphismBlur.toStringAsFixed(0)}px)'),
                      Slider(
                        value: theme.glassmorphismBlur,
                        min: 0,
                        max: 32,
                        activeColor: theme.accentColor,
                        onChanged: themeNotifier.setGlassmorphismBlur,
                      ),
                    ],
                  ),

                  // Tab 2: Security & E2EE Keys
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
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
                                const Icon(Icons.verified_rounded, color: MercuryColors.success),
                                const SizedBox(width: 8),
                                Text(
                                  crypto.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Hardware-bound Ed25519 Identity Key and ML-KEM-768 / X25519 hybrid post-quantum key encapsulation actively guarding direct messages and channels.',
                              style: TextStyle(
                                color: MercuryColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FutureBuilder<IdentityPublicKey>(
                              future: crypto.loadIdentity(),
                              builder: (context, snap) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ACTIVE FINGERPRINT (SAFETY NUMBER)',
                                    style: TextStyle(
                                      color: MercuryColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    snap.data?.fingerprint ?? 'Calculating…',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700,
                                      color: MercuryColors.accent,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'HARDWARE ENCLAVE PROTECTION',
                                    style: TextStyle(
                                      color: MercuryColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.lock_person_rounded, size: 16, color: MercuryColors.success),
                                      const SizedBox(width: 6),
                                      Text(
                                        Theme.of(context).platform == TargetPlatform.windows
                                            ? 'Windows DPAPI / TPM 2.0 Credential Isolation'
                                            : Theme.of(context).platform == TargetPlatform.android
                                            ? 'Android Keystore (Hardware StrongBox / TEE)'
                                            : 'Linux Secret Service (libsecret / Keyring)',
                                        style: const TextStyle(
                                          color: MercuryColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
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
                      const SizedBox(height: 20),
                      const Text(
                        'PROTOCOL DETAILS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const ListTile(
                        leading: Icon(Icons.shield_rounded, color: MercuryColors.accent),
                        title: Text('Hybrid Post-Quantum MLS (Groups)'),
                        subtitle: Text('ML-KEM-768 + X25519 combiner against harvest-now-decrypt-later attacks'),
                      ),
                      const ListTile(
                        leading: Icon(Icons.swap_horiz_rounded, color: MercuryColors.accent),
                        title: Text('Double Ratchet (1:1 DMs)'),
                        subtitle: Text('Forward secrecy with per-message ephemeral DH keys'),
                      ),
                      const ListTile(
                        leading: Icon(Icons.storage_rounded, color: MercuryColors.accent),
                        title: Text('Zero-Knowledge Drift Storage'),
                        subtitle: Text('Local SQLite with FTS5 encrypted index; queries never leave device'),
                      ),
                    ],
                  ),

                  // Tab 3: Audio & Device
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text(
                        'VOICE & AUDIO HARDWARE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const ListTile(
                        leading: Icon(Icons.mic_rounded, color: MercuryColors.accent),
                        title: Text('Input Device (Microphone)'),
                        subtitle: Text('Default System Microphone (Noise Suppression Active)'),
                      ),
                      const ListTile(
                        leading: Icon(Icons.headphones_rounded, color: MercuryColors.accent),
                        title: Text('Output Device (Playback)'),
                        subtitle: Text('Default System Audio Device (Stereo 48kHz)'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AUDIOPHILE VOICE ENGINE (MOONDROP MIAD01 & HI-FI DACS)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, _) {
                          final audio = ref.watch(audiophileAudioEngineProvider);
                          return Column(
                            children: [
                              for (final preset in AudioQualityPreset.values)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: audio.currentPreset == preset
                                        ? MercuryColors.accent.withValues(alpha: 0.12)
                                        : MercuryColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: audio.currentPreset == preset
                                          ? MercuryColors.accent
                                          : MercuryColors.border,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      preset == AudioQualityPreset.audiophileBitPerfect
                                          ? Icons.graphic_eq_rounded
                                          : Icons.music_note_rounded,
                                      color: audio.currentPreset == preset
                                          ? MercuryColors.accent
                                          : MercuryColors.textMuted,
                                    ),
                                    title: Text(
                                      preset.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: audio.currentPreset == preset
                                            ? MercuryColors.accent
                                            : MercuryColors.textPrimary,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${preset.description} · ${preset.bitrateKbps}kbps / ${preset.channels == 2 ? "Stereo" : "Mono"} · RTT ${preset.latencyMs}ms',
                                      style: const TextStyle(fontSize: 11.5, color: MercuryColors.textMuted),
                                    ),
                                    trailing: audio.currentPreset == preset
                                        ? const Icon(Icons.check_circle_rounded, color: MercuryColors.accent)
                                        : null,
                                    onTap: () => setState(() => audio.setPreset(preset)),
                                  ),
                                ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                activeThumbColor: MercuryColors.accent,
                                title: const Text('Direct DAC Hardware Bypass (Android & ALSA)'),
                                subtitle: const Text(
                                  'Bypasses system resampling mixer directly to dual Cirrus Logic CS43131 DACs via 4.4mm balanced output',
                                  style: TextStyle(fontSize: 11.5, color: MercuryColors.textMuted),
                                ),
                                value: audio.directDacBypassEnabled,
                                onChanged: (val) => setState(() => audio.toggleDirectDacBypass(val)),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'GATEWAY STREAM',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MercuryColors.textMuted,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.stream_rounded, color: MercuryColors.success),
                        title: Text(gateway.runtimeType.toString()),
                        subtitle: const Text('WebTransport QUIC datagrams with per-channel sequence numbers'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
