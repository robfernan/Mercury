import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models.dart';
import '../../../data/seed_data.dart';
import '../../../theme/mercury_theme.dart';
import '../state/chat_providers.dart';
import 'markdown_text.dart';
import 'user_avatar.dart';

const _quickReactions = ['👍', '❤️', '😂', '🚀'];

enum _MessageAction { reply, copyText, copyId, retry, delete }

/// One message in the feed. [grouped] means it continues a run from the same
/// author, so the avatar and name header are omitted.
class MessageTile extends ConsumerStatefulWidget {
  const MessageTile({super.key, required this.message, required this.grouped});

  final ChatMessage message;
  final bool grouped;

  @override
  ConsumerState<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends ConsumerState<MessageTile> {
  var _hovered = false;
  var _menuOpen = false;

  ChatMessage get _message => widget.message;
  bool get _isOwn => _message.authorId == SeedData.currentUserId;

  MessagesNotifier get _messages =>
      ref.read(messagesProvider(_message.channelId).notifier);

  Future<void> _handle(_MessageAction action) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _MessageAction.reply:
        ref.read(composerProvider(_message.channelId).notifier).replyTo(_message);
      case _MessageAction.copyText:
        await Clipboard.setData(ClipboardData(text: _message.body));
        messenger.showSnackBar(
          const SnackBar(content: Text('Message copied')),
        );
      case _MessageAction.copyId:
        await Clipboard.setData(ClipboardData(text: _message.id));
        messenger.showSnackBar(
          const SnackBar(content: Text('Message ID copied')),
        );
      case _MessageAction.retry:
        await _messages.retry(_message.id);
      case _MessageAction.delete:
        _messages.delete(_message.id);
    }
  }

  List<(_MessageAction, IconData, String)> get _actions => [
    if (_message.delivery == DeliveryState.sent)
      (_MessageAction.reply, Icons.reply_rounded, 'Reply'),
    (_MessageAction.copyText, Icons.copy_rounded, 'Copy text'),
    if (_message.delivery == DeliveryState.sent)
      (_MessageAction.copyId, Icons.tag_rounded, 'Copy message ID'),
    if (_message.delivery == DeliveryState.failed)
      (_MessageAction.retry, Icons.refresh_rounded, 'Retry send'),
    if (_isOwn) (_MessageAction.delete, Icons.delete_outline_rounded, 'Delete'),
  ];

  Future<void> _showActionSheet() async {
    HapticFeedback.selectionClick();
    final action = await showModalBottomSheet<Object>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_message.delivery == DeliveryState.sent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final emoji in _quickReactions)
                      IconButton.filledTonal(
                        tooltip: 'React $emoji',
                        onPressed: () => Navigator.pop(context, emoji),
                        icon: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                  ],
                ),
              ),
            for (final (action, icon, label) in _actions)
              ListTile(
                leading: Icon(
                  icon,
                  color: action == _MessageAction.delete
                      ? MercuryColors.danger
                      : null,
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    color: action == _MessageAction.delete
                        ? MercuryColors.danger
                        : null,
                  ),
                ),
                onTap: () => Navigator.pop(context, action),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action is String) {
      _messages.toggleReaction(_message.id, action);
    } else if (action is _MessageAction) {
      await _handle(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final author = ref.watch(userByIdProvider(_message.authorId));
    if (author == null) return const SizedBox.shrink();

    final showToolbar =
        (_hovered || _menuOpen) && _message.delivery != DeliveryState.pending;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onLongPress: _showActionSheet,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hovered ? MercuryColors.surfaceHover.withValues(alpha: 0.45) : Colors.transparent,
          padding: EdgeInsets.fromLTRB(16, widget.grouped ? 2 : 12, 16, 2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 40,
                    child: widget.grouped
                        ? _HoverTimestamp(
                            visible: _hovered,
                            sentAt: _message.sentAt,
                          )
                        : UserAvatar(user: author),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildContent(author)),
                ],
              ),
              Positioned(
                top: widget.grouped ? -14 : -6,
                right: 0,
                child: AnimatedOpacity(
                  opacity: showToolbar ? 1 : 0,
                  duration: const Duration(milliseconds: 100),
                  child: IgnorePointer(
                    ignoring: !showToolbar,
                    child: _HoverToolbar(
                      canReact: _message.delivery == DeliveryState.sent,
                      onReact: (emoji) =>
                          _messages.toggleReaction(_message.id, emoji),
                      onReply: _message.delivery == DeliveryState.sent
                          ? () => _handle(_MessageAction.reply)
                          : null,
                      actions: _actions,
                      onAction: _handle,
                      onMenuOpenChanged: (open) =>
                          setState(() => _menuOpen = open),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ChatUser author) {
    final replyTarget = _message.replyToId == null
        ? null
        : ref
              .watch(messagesProvider(_message.channelId))
              .where((m) => m.id == _message.replyToId)
              .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (replyTarget != null) _ReplyPreview(message: replyTarget),
        if (!widget.grouped) _Header(author: author, message: _message),
        Opacity(
          opacity: _message.delivery == DeliveryState.pending ? 0.6 : 1,
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isOwn ? MercuryColors.ownBubble : MercuryColors.bubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(widget.grouped ? 12 : 4),
                topRight: const Radius.circular(12),
                bottomLeft: const Radius.circular(12),
                bottomRight: const Radius.circular(12),
              ),
              border: Border.all(
                color: _message.delivery == DeliveryState.failed
                    ? MercuryColors.danger.withValues(alpha: 0.6)
                    : _isOwn
                    ? MercuryColors.accent.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_message.body.isNotEmpty) MarkdownText(_message.body),
                if (_message.attachment case final attachment?)
                  Padding(
                    padding: EdgeInsets.only(
                      top: _message.body.isEmpty ? 0 : 8,
                    ),
                    child: _AttachmentCard(attachment: attachment),
                  ),
              ],
            ),
          ),
        ),
        if (_message.delivery == DeliveryState.failed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: InkWell(
              onTap: () => _handle(_MessageAction.retry),
              child: const Text(
                'Failed to send · Tap to retry',
                style: TextStyle(color: MercuryColors.danger, fontSize: 12),
              ),
            ),
          ),
        if (_message.reactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in _message.reactions.entries)
                  _ReactionChip(
                    emoji: entry.key,
                    count: entry.value.length,
                    mine: entry.value.contains(SeedData.currentUserId),
                    onTap: () =>
                        _messages.toggleReaction(_message.id, entry.key),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

String formatMessageTime(DateTime t, {DateTime? now}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final time = DateFormat.jm().format(t);
  if (day == today) return 'Today at $time';
  if (day == today.subtract(const Duration(days: 1))) {
    return 'Yesterday at $time';
  }
  return '${DateFormat.yMd().format(t)} $time';
}

class _Header extends StatelessWidget {
  const _Header({required this.author, required this.message});

  final ChatUser author;
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            author.displayName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color.lerp(author.avatarColor, Colors.white, 0.35),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        if (author.role != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: author.avatarColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              author.role!,
              style: TextStyle(
                color: Color.lerp(author.avatarColor, Colors.white, 0.4),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Text(
          formatMessageTime(message.sentAt),
          style: const TextStyle(color: MercuryColors.textMuted, fontSize: 12),
        ),
        const SizedBox(width: 6),
        _DeliveryIcon(message: message),
      ],
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  const _DeliveryIcon({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final (icon, color, tip) = switch (message.delivery) {
      DeliveryState.pending => (
        Icons.schedule_rounded,
        MercuryColors.textMuted,
        'Encrypting & sending…',
      ),
      DeliveryState.failed => (
        Icons.error_outline_rounded,
        MercuryColors.danger,
        'Not delivered',
      ),
      DeliveryState.sent when !message.verified => (
        Icons.gpp_bad_rounded,
        MercuryColors.danger,
        'Signature verification FAILED',
      ),
      DeliveryState.sent => (
        Icons.lock_rounded,
        MercuryColors.textMuted,
        'Signature verified · seq ${message.seq ?? '-'}',
      ),
    };
    return Tooltip(
      message: tip,
      child: Icon(icon, size: 13, color: color),
    );
  }
}

class _HoverTimestamp extends StatelessWidget {
  const _HoverTimestamp({required this.visible, required this.sentAt});

  final bool visible;
  final DateTime sentAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 100),
        child: Text(
          DateFormat.Hm().format(sentAt),
          textAlign: TextAlign.center,
          style: const TextStyle(color: MercuryColors.textMuted, fontSize: 10.5),
        ),
      ),
    );
  }
}

class _ReplyPreview extends ConsumerWidget {
  const _ReplyPreview({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final author = ref.watch(userByIdProvider(message.authorId));
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          const Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 14,
            color: MercuryColors.textMuted,
          ),
          const SizedBox(width: 4),
          if (author != null) ...[
            UserAvatar(user: author, size: 16),
            const SizedBox(width: 4),
            Text(
              author.displayName,
              style: const TextStyle(
                color: MercuryColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              message.body.replaceAll('\n', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MercuryColors.textMuted,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final icon = switch (attachment.kind) {
      AttachmentKind.image => Icons.image_rounded,
      AttachmentKind.audio => Icons.graphic_eq_rounded,
      AttachmentKind.file => Icons.description_rounded,
    };
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MercuryColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MercuryColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: MercuryColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: MercuryColors.accent, size: 22),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB3A9FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${attachment.humanSize} · encrypted',
                  style: const TextStyle(
                    color: MercuryColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.download_rounded,
            color: MercuryColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: mine,
      label: '$emoji reaction, $count',
      child: Material(
        color: mine ? MercuryColors.accentSoft : MercuryColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: mine ? MercuryColors.accent : MercuryColors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: TextStyle(
                    color: mine
                        ? MercuryColors.textPrimary
                        : MercuryColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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

class _HoverToolbar extends StatelessWidget {
  const _HoverToolbar({
    required this.canReact,
    required this.onReact,
    required this.onReply,
    required this.actions,
    required this.onAction,
    required this.onMenuOpenChanged,
  });

  final bool canReact;
  final ValueChanged<String> onReact;
  final VoidCallback? onReply;
  final List<(_MessageAction, IconData, String)> actions;
  final ValueChanged<_MessageAction> onAction;
  final ValueChanged<bool> onMenuOpenChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MercuryColors.surfaceRaised,
      elevation: 6,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: MercuryColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canReact)
              for (final emoji in _quickReactions)
                _ToolbarButton(
                  tooltip: 'React $emoji',
                  onPressed: () => onReact(emoji),
                  child: Text(emoji, style: const TextStyle(fontSize: 15)),
                ),
            if (onReply != null)
              _ToolbarButton(
                tooltip: 'Reply',
                onPressed: onReply!,
                child: const Icon(Icons.reply_rounded, size: 18),
              ),
            PopupMenuButton<_MessageAction>(
              tooltip: 'More actions',
              iconSize: 18,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: MercuryColors.textSecondary,
              ),
              onOpened: () => onMenuOpenChanged(true),
              onCanceled: () => onMenuOpenChanged(false),
              onSelected: (a) {
                onMenuOpenChanged(false);
                onAction(a);
              },
              itemBuilder: (_) => [
                for (final (action, icon, label) in actions)
                  PopupMenuItem(
                    value: action,
                    height: 40,
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: action == _MessageAction.delete
                              ? MercuryColors.danger
                              : MercuryColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          label,
                          style: TextStyle(
                            color: action == _MessageAction.delete
                                ? MercuryColors.danger
                                : MercuryColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: SizedBox(
          width: 34,
          height: 32,
          child: Center(
            child: IconTheme.merge(
              data: const IconThemeData(color: MercuryColors.textSecondary),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
