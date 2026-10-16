import 'dart:typed_data';

import '../../data/models.dart';

enum GatewayConnectionState { disconnected, connecting, connected, reconnecting }

/// Frames pushed from the gateway to the client.
sealed class GatewayEvent {
  const GatewayEvent();
}

class ConnectionStateChanged extends GatewayEvent {
  const ConnectionStateChanged(this.state);
  final GatewayConnectionState state;
}

/// A new message fanned out from `server:{serverId}:channel:{channelId}`.
/// The payload is still an opaque E2EE envelope; the client must verify and
/// decrypt it through the `CryptoEngine`.
class MessageReceived extends GatewayEvent {
  const MessageReceived({
    required this.channelId,
    required this.messageId,
    required this.seq,
    required this.authorId,
    required this.envelope,
    required this.sentAt,
    this.clientNonce,
    this.attachment,
    this.replyToId,
  });

  final String channelId;
  final String messageId;
  final int seq;
  final String authorId;
  final Uint8List envelope;
  final DateTime sentAt;

  /// Echoed back for messages this device sent, so the pending copy can be
  /// reconciled with the server-assigned id and seq.
  final String? clientNonce;
  final Attachment? attachment;
  final String? replyToId;
}

class TypingStarted extends GatewayEvent {
  const TypingStarted({required this.channelId, required this.userId});
  final String channelId;
  final String userId;
}

class PresenceChanged extends GatewayEvent {
  const PresenceChanged({required this.userId, required this.presence});
  final String userId;
  final Presence presence;
}
