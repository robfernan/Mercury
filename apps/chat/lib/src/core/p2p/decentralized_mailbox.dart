import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Mailbox envelope for store-and-forward messaging when a recipient peer is offline.
///
/// In a zero-VPS architecture, peers distribute encrypted envelopes into a
/// decentralized gossip network (Waku v2 / Iroh gossip). Relay nodes or reachable
/// fleet peers cache the message in an encrypted ephemeral store (up to 30 days)
/// until the recipient connects and pulls unacknowledged messages.
class OfflineMailboxEnvelope {
  const OfflineMailboxEnvelope({
    required this.envelopeId,
    required this.conversationId,
    required this.senderPeerId,
    required this.recipientPeerId,
    required this.cipherPayload,
    required this.createdAt,
    required this.expiresAt,
    this.deliveryProof,
    this.acked = false,
  });

  final String envelopeId;
  final String conversationId;
  final String senderPeerId;
  final String recipientPeerId;
  final Uint8List cipherPayload;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? deliveryProof;
  final bool acked;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  OfflineMailboxEnvelope copyWith({
    String? envelopeId,
    String? conversationId,
    String? senderPeerId,
    String? recipientPeerId,
    Uint8List? cipherPayload,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? deliveryProof,
    bool? acked,
  }) {
    return OfflineMailboxEnvelope(
      envelopeId: envelopeId ?? this.envelopeId,
      conversationId: conversationId ?? this.conversationId,
      senderPeerId: senderPeerId ?? this.senderPeerId,
      recipientPeerId: recipientPeerId ?? this.recipientPeerId,
      cipherPayload: cipherPayload ?? this.cipherPayload,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      deliveryProof: deliveryProof ?? this.deliveryProof,
      acked: acked ?? this.acked,
    );
  }

  Map<String, dynamic> toJson() => {
        'envelopeId': envelopeId,
        'conversationId': conversationId,
        'senderPeerId': senderPeerId,
        'recipientPeerId': recipientPeerId,
        'cipherPayload': base64Encode(cipherPayload),
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'deliveryProof': deliveryProof,
        'acked': acked,
      };

  factory OfflineMailboxEnvelope.fromJson(Map<String, dynamic> json) {
    return OfflineMailboxEnvelope(
      envelopeId: json['envelopeId'] as String,
      conversationId: json['conversationId'] as String,
      senderPeerId: json['senderPeerId'] as String,
      recipientPeerId: json['recipientPeerId'] as String,
      cipherPayload: base64Decode(json['cipherPayload'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      deliveryProof: json['deliveryProof'] as String?,
      acked: json['acked'] as bool? ?? false,
    );
  }
}

/// Decentralized store-and-forward relay node simulator & client
class DecentralizedMailboxService {
  final Map<String, OfflineMailboxEnvelope> _mailboxes = {};
  final _pendingEnvelopesController =
      StreamController<List<OfflineMailboxEnvelope>>.broadcast();

  Stream<List<OfflineMailboxEnvelope>> get pendingEnvelopesStream =>
      _pendingEnvelopesController.stream;

  List<OfflineMailboxEnvelope> get allEnvelopes =>
      List.unmodifiable(_mailboxes.values);

  /// Deposit an encrypted message envelope into the decentralized relay network.
  /// Holds for up to [ttl] duration (default 30 days) until the recipient polls.
  Future<void> depositEnvelope({
    required String envelopeId,
    required String conversationId,
    required String senderPeerId,
    required String recipientPeerId,
    required Uint8List cipherPayload,
    Duration ttl = const Duration(days: 30),
  }) async {
    final now = DateTime.now();
    final envelope = OfflineMailboxEnvelope(
      envelopeId: envelopeId,
      conversationId: conversationId,
      senderPeerId: senderPeerId,
      recipientPeerId: recipientPeerId,
      cipherPayload: cipherPayload,
      createdAt: now,
      expiresAt: now.add(ttl),
    );

    _mailboxes[envelopeId] = envelope;
    _pendingEnvelopesController.add(allEnvelopes);
  }

  /// Query all undelivered envelopes waiting for [recipientPeerId].
  Future<List<OfflineMailboxEnvelope>> fetchPendingForPeer(
    String recipientPeerId,
  ) async {
    final now = DateTime.now();
    return _mailboxes.values.where((e) {
      return e.recipientPeerId == recipientPeerId &&
          !e.acked &&
          now.isBefore(e.expiresAt);
    }).toList();
  }

  /// Mark an envelope as acknowledged and received by the target peer.
  Future<void> acknowledgeEnvelope(String envelopeId, {String? proof}) async {
    final existing = _mailboxes[envelopeId];
    if (existing != null) {
      _mailboxes[envelopeId] = existing.copyWith(
        acked: true,
        deliveryProof: proof ?? 'DERP-P2P-ACK',
      );
      _pendingEnvelopesController.add(allEnvelopes);
    }
  }

  /// Prune expired messages from the relay.
  void pruneExpired() {
    final now = DateTime.now();
    _mailboxes.removeWhere((_, e) => now.isAfter(e.expiresAt));
    _pendingEnvelopesController.add(allEnvelopes);
  }

  void dispose() {
    _pendingEnvelopesController.close();
  }
}
