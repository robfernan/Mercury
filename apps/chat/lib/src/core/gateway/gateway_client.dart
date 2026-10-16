import 'dart:typed_data';

import '../../data/models.dart';
import 'gateway_events.dart';

export 'gateway_events.dart';

/// Client side of the Mercury real-time gateway.
///
/// The production implementation will speak WebTransport over QUIC (with an
/// HTTP fallback), send the last-acked `seq` per channel on reconnect, and
/// apply gap-fill before resuming the live stream. The UI only depends on
/// this interface.
abstract interface class GatewayClient {
  /// Broadcast stream of every frame from the gateway.
  Stream<GatewayEvent> get events;

  GatewayConnectionState get connectionState;

  Future<void> connect();

  Future<void> disconnect();

  /// Tells the gateway which channel is in focus (drives typing fan-out and
  /// read receipts). Messages for every joined channel still arrive.
  void focusChannel({required String serverId, required String channelId});

  /// Publishes an already-encrypted envelope. The result arrives later as a
  /// [MessageReceived] echo carrying the same [clientNonce].
  Future<void> sendMessage({
    required String channelId,
    required String clientNonce,
    required Uint8List envelope,
    Attachment? attachment,
    String? replyToId,
  });

  /// Sends a "typing" signal for [channelId]. Callers should throttle.
  void sendTyping(String channelId);

  Future<void> dispose();
}
