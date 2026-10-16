import 'package:flutter/widgets.dart';

import '../core/crypto/crypto_engine.dart';

enum Presence { online, idle, doNotDisturb, offline }

class ChatUser {
  const ChatUser({
    required this.id,
    required this.displayName,
    required this.handle,
    required this.avatarColor,
    this.presence = Presence.online,
    this.statusText,
    this.role,
  });

  final String id;
  final String displayName;
  final String handle;
  final Color avatarColor;
  final Presence presence;
  final String? statusText;

  /// Optional role label shown in the member list (e.g. "Maintainer").
  final String? role;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  ChatUser copyWith({Presence? presence, String? statusText}) => ChatUser(
    id: id,
    displayName: displayName,
    handle: handle,
    avatarColor: avatarColor,
    presence: presence ?? this.presence,
    statusText: statusText ?? this.statusText,
    role: role,
  );
}

class ChatServer {
  const ChatServer({
    required this.id,
    required this.name,
    required this.accent,
    required this.memberIds,
  });

  final String id;
  final String name;
  final Color accent;
  final List<String> memberIds;

  String get monogram {
    final words = name.split(RegExp(r'\s+'));
    return words.take(2).map((w) => w.characters.first).join().toUpperCase();
  }
}

enum ChannelKind { text, voice }

class ChatChannel {
  const ChatChannel({
    required this.id,
    required this.serverId,
    required this.name,
    required this.category,
    this.kind = ChannelKind.text,
    this.topic,
    this.scheme = EncryptionScheme.hybridPqMls,
  });

  final String id;
  final String serverId;
  final String name;
  final String category;
  final ChannelKind kind;
  final String? topic;
  final EncryptionScheme scheme;
}

enum AttachmentKind { file, image, audio }

class Attachment {
  const Attachment({
    required this.name,
    required this.sizeBytes,
    required this.kind,
  });

  final String name;
  final int sizeBytes;
  final AttachmentKind kind;

  String get humanSize {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = sizeBytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}

enum DeliveryState {
  /// Encrypted locally, awaiting gateway ack (no seq yet).
  pending,

  /// Acked by the server and assigned a channel sequence number.
  sent,

  failed,
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.body,
    required this.sentAt,
    this.seq,
    this.delivery = DeliveryState.sent,
    this.verified = true,
    this.replyToId,
    this.attachment,
    this.reactions = const {},
  });

  /// Server id once acked; a client nonce while [DeliveryState.pending].
  final String id;
  final String channelId;
  final String authorId;
  final String body;
  final DateTime sentAt;

  /// Strictly increasing per-channel sequence number assigned by the API.
  final int? seq;
  final DeliveryState delivery;

  /// Ed25519 signature verified locally.
  final bool verified;
  final String? replyToId;
  final Attachment? attachment;

  /// emoji → set of user ids who reacted.
  final Map<String, Set<String>> reactions;

  ChatMessage copyWith({
    String? id,
    int? seq,
    DeliveryState? delivery,
    Map<String, Set<String>>? reactions,
  }) => ChatMessage(
    id: id ?? this.id,
    channelId: channelId,
    authorId: authorId,
    body: body,
    sentAt: sentAt,
    seq: seq ?? this.seq,
    delivery: delivery ?? this.delivery,
    verified: verified,
    replyToId: replyToId,
    attachment: attachment,
    reactions: reactions ?? this.reactions,
  );
}
