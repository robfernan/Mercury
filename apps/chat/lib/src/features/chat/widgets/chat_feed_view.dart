import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models.dart';
import '../../../theme/mercury_theme.dart';
import '../../../theme/theme_state.dart';
import '../state/chat_providers.dart';
import 'message_input_bar.dart';
import 'message_search_modal.dart';
import 'message_tile.dart';

class ChatFeedView extends ConsumerStatefulWidget {
  const ChatFeedView({
    super.key,
    required this.server,
    required this.channel,
    required this.onOpenDrawer,
  });

  final ChatServer server;
  final ChatChannel channel;
  final VoidCallback onOpenDrawer;

  @override
  ConsumerState<ChatFeedView> createState() => _ChatFeedViewState();
}

class _ChatFeedViewState extends ConsumerState<ChatFeedView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.channel.id));
    final memberListVisible = ref.watch(memberListVisibleProvider);

    // Auto-scroll on new message if near bottom
    ref.listen(messagesProvider(widget.channel.id), (previous, next) {
      if (previous != null && next.length > previous.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    final theme = ref.watch(themeStateProvider);
    final wallpaper = theme.wallpaper;

    return Stack(
      children: [
        // Background Wallpaper Layer
        if (wallpaper.imagePath != null && File(wallpaper.imagePath!).existsSync())
          Positioned.fill(
            child: Opacity(
              opacity: wallpaper.opacity,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: wallpaper.blur,
                  sigmaY: wallpaper.blur,
                ),
                child: Image.file(
                  File(wallpaper.imagePath!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(color: theme.surfaceColor),
          ),

        // Semi-transparent backdrop tint if wallpaper is active
        if (wallpaper.imagePath != null)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),

        // Foreground Chat UI
        Column(
          children: [
            // Channel Top Bar
            _ChannelTopBar(
              server: widget.server,
              channel: widget.channel,
              onOpenDrawer: widget.onOpenDrawer,
              memberListVisible: memberListVisible,
              onToggleMemberList: () =>
                  ref.read(memberListVisibleProvider.notifier).toggle(),
            ),
          // Messages ListView
          Expanded(
            child: messages.isEmpty
                ? _EmptyChannelPlaceholder(channel: widget.channel)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final message = messages[i];
                      final prev = i > 0 ? messages[i - 1] : null;

                      // Group messages if same author within 5 minutes
                      final grouped = prev != null &&
                          prev.authorId == message.authorId &&
                          message.sentAt.difference(prev.sentAt).inMinutes < 5 &&
                          message.replyToId == null;

                      return MessageTile(
                        key: ValueKey(message.id),
                        message: message,
                        grouped: grouped,
                      );
                    },
                  ),
          ),
          // Composer Bar
          MessageInputBar(
            channelId: widget.channel.id,
            channelName: widget.channel.name,
          ),
        ],
      ),
    ],
  );
}
}

class _ChannelTopBar extends StatelessWidget {
  const _ChannelTopBar({
    required this.server,
    required this.channel,
    required this.onOpenDrawer,
    required this.memberListVisible,
    required this.onToggleMemberList,
  });

  final ChatServer server;
  final ChatChannel channel;
  final VoidCallback onOpenDrawer;
  final bool memberListVisible;
  final VoidCallback onToggleMemberList;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 800;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: MercuryColors.surface,
        border: Border(bottom: BorderSide(color: MercuryColors.border)),
      ),
      child: Row(
        children: [
          if (isCompact) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: onOpenDrawer,
              tooltip: 'Channels',
            ),
            const SizedBox(width: 4),
          ],
          Icon(
            channel.kind == ChannelKind.voice
                ? Icons.volume_up_rounded
                : Icons.tag_rounded,
            size: 20,
            color: MercuryColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            channel.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: MercuryColors.textPrimary,
            ),
          ),
          if (channel.topic != null) ...[
            const SizedBox(width: 12),
            Container(
              height: 16,
              width: 1,
              color: MercuryColors.border,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                channel.topic!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MercuryColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ),
          ] else
            const Spacer(),
          // Top bar actions
          Tooltip(
            message: 'E2EE (Hybrid PQ-MLS · ML-KEM + X25519)',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: MercuryColors.surfaceRaised,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: MercuryColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_rounded, size: 14, color: MercuryColors.success),
                  SizedBox(width: 6),
                  Text(
                    'PQ-MLS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: MercuryColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: MercuryColors.textSecondary),
            tooltip: 'Search Messages (SQLite FTS5)',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => MessageSearchModal(
                channelId: channel.id,
                channelName: channel.name,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              memberListVisible
                  ? Icons.people_rounded
                  : Icons.people_outline_rounded,
              color: memberListVisible
                  ? MercuryColors.textPrimary
                  : MercuryColors.textSecondary,
            ),
            tooltip: 'Toggle Member List',
            onPressed: onToggleMemberList,
          ),
        ],
      ),
    );
  }
}

class _EmptyChannelPlaceholder extends StatelessWidget {
  const _EmptyChannelPlaceholder({required this.channel});

  final ChatChannel channel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MercuryColors.surfaceRaised,
              border: Border.all(color: MercuryColors.border),
            ),
            child: const Icon(
              Icons.tag_rounded,
              size: 32,
              color: MercuryColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to #${channel.name}!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: MercuryColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            channel.topic ?? 'This is the start of the #${channel.name} channel.',
            style: const TextStyle(
              color: MercuryColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
