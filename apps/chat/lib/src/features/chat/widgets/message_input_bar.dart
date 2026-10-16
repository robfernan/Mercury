import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/models.dart';
import '../../../theme/mercury_theme.dart';
import '../state/chat_providers.dart';

class MessageInputBar extends ConsumerStatefulWidget {
  const MessageInputBar({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  final String channelId;
  final String channelName;

  @override
  ConsumerState<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<MessageInputBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  DateTime? _lastTypingSent;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {});
    final now = DateTime.now();
    if (_lastTypingSent == null || now.difference(_lastTypingSent!).inSeconds > 2) {
      _lastTypingSent = now;
      ref.read(gatewayClientProvider).sendTyping(widget.channelId);
    }
  }

  void _send() {
    final text = _controller.text.trim();
    final composer = ref.read(composerProvider(widget.channelId));
    if (text.isEmpty && composer.attachment == null) return;

    ref.read(messagesProvider(widget.channelId).notifier).send(
      text,
      attachment: composer.attachment,
      replyToId: composer.replyTo?.id,
    );

    _controller.clear();
    ref.read(composerProvider(widget.channelId).notifier).reset();
    setState(() {});
    _focusNode.requestFocus();
  }

  void _stageDummyAttachment() {
    final composer = ref.read(composerProvider(widget.channelId).notifier);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_rounded, color: MercuryColors.accent),
              title: const Text('Attach Image (Encrypted)'),
              subtitle: const Text('benchmark_graph.png · 482 KB'),
              onTap: () {
                composer.attach(
                  const Attachment(
                    name: 'benchmark_graph.png',
                    sizeBytes: 493568,
                    kind: AttachmentKind.image,
                  ),
                );
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_rounded, color: MercuryColors.accent),
              title: const Text('Attach Document (Encrypted)'),
              subtitle: const Text('mercury-mls-spec.pdf · 1.8 MB'),
              onTap: () {
                composer.attach(
                  const Attachment(
                    name: 'mercury-mls-spec.pdf',
                    sizeBytes: 1887436,
                    kind: AttachmentKind.file,
                  ),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final composer = ref.watch(composerProvider(widget.channelId));
    final typingUsers = ref.watch(typingUsersProvider(widget.channelId));
    final hasContent = _controller.text.trim().isNotEmpty || composer.attachment != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: const BoxDecoration(
        color: MercuryColors.surface,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Typing indicator line
          SizedBox(
            height: 22,
            child: typingUsers.isEmpty
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MercuryColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTyping(typingUsers),
                        style: const TextStyle(
                          color: MercuryColors.textMuted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
          ),
          // Composer card
          Container(
            decoration: BoxDecoration(
              color: MercuryColors.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MercuryColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Replying banner
                if (composer.replyTo case final replyTarget?)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: MercuryColors.surfaceHover,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                      border: Border(bottom: BorderSide(color: MercuryColors.border)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.reply_rounded,
                          size: 16,
                          color: MercuryColors.accent,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Replying to ',
                          style: TextStyle(
                            color: MercuryColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            final author = ref.watch(userByIdProvider(replyTarget.authorId));
                            return Text(
                              '@${author?.displayName ?? replyTarget.authorId}',
                              style: const TextStyle(
                                color: MercuryColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => ref
                              .read(composerProvider(widget.channelId).notifier)
                              .replyTo(null),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: MercuryColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Staged attachment pill
                if (composer.attachment case final attachment?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: MercuryColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: MercuryColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.attach_file_rounded,
                                size: 16,
                                color: MercuryColors.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${attachment.name} (${attachment.humanSize})',
                                style: const TextStyle(
                                  color: MercuryColors.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => ref
                                    .read(composerProvider(widget.channelId).notifier)
                                    .attach(null),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: MercuryColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Text field + actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Add attachment',
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        color: MercuryColors.textSecondary,
                        onPressed: _stageDummyAttachment,
                      ),
                      Expanded(
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.enter): _send,
                          },
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: 5,
                            minLines: 1,
                            onChanged: _onChanged,
                            style: const TextStyle(
                              color: MercuryColors.textPrimary,
                              fontSize: 14.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Message #${widget.channelName}',
                              hintStyle: const TextStyle(
                                color: MercuryColors.textMuted,
                                fontSize: 14.5,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Send message',
                        icon: const Icon(Icons.send_rounded),
                        color: hasContent ? MercuryColors.accent : MercuryColors.textMuted,
                        onPressed: hasContent ? _send : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Formatting hints footer
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Row(
              children: [
                _HintChip('**bold**'),
                const SizedBox(width: 8),
                _HintChip('*italic*'),
                const SizedBox(width: 8),
                _HintChip('`code`'),
                const SizedBox(width: 8),
                _HintChip('> quote'),
                const Spacer(),
                const Tooltip(
                  message: 'Local Ed25519 signature + hybrid PQ-MLS envelope',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 12, color: MercuryColors.success),
                      SizedBox(width: 4),
                      Text(
                        'E2EE Verified',
                        style: TextStyle(
                          color: MercuryColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTyping(List<ChatUser> users) {
    if (users.length == 1) return '${users.first.displayName} is typing…';
    if (users.length == 2) {
      return '${users[0].displayName} and ${users[1].displayName} are typing…';
    }
    return '${users[0].displayName} and ${users.length - 1} others are typing…';
  }
}

class _HintChip extends StatelessWidget {
  const _HintChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: MercuryColors.textMuted,
        fontSize: 11,
        fontFamily: 'monospace',
      ),
    );
  }
}
