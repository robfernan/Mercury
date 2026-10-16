import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../data/models.dart';
import '../crypto/crypto_engine.dart';
import 'gateway_client.dart';

/// In-process fake of the gateway that simulates a lively workspace:
/// incoming messages (encrypted through the [CryptoEngine] just like real
/// peers would send them), typing indicators, presence changes and
/// server echoes for messages you send.
class MockGatewayClient implements GatewayClient {
  MockGatewayClient({
    required this.crypto,
    required this.currentUserId,
    required List<ChatServer> servers,
    required List<ChatChannel> channels,
    required List<String> cannedLines,
    Map<String, int> initialSeqs = const {},
    this.roundTripLatency = const Duration(milliseconds: 90),
    this.activityEnabled = true,
    int? randomSeed,
  }) : _servers = {for (final s in servers) s.id: s},
       _channels = {for (final c in channels) c.id: c},
       _cannedLines = List.unmodifiable(cannedLines),
       _seqs = Map.of(initialSeqs),
       _random = Random(randomSeed);

  final CryptoEngine crypto;
  final String currentUserId;

  /// Simulated client → API → Redis → gateway → client round trip.
  final Duration roundTripLatency;

  /// Turn off for widget tests that need a quiet, deterministic stream.
  final bool activityEnabled;

  final Map<String, ChatServer> _servers;
  final Map<String, ChatChannel> _channels;
  final List<String> _cannedLines;
  final Map<String, int> _seqs;
  final Random _random;

  final _controller = StreamController<GatewayEvent>.broadcast();
  final _timers = <Timer>{};
  var _state = GatewayConnectionState.disconnected;
  String? _focusedServerId;
  String? _focusedChannelId;
  var _messageCounter = 0;

  @override
  Stream<GatewayEvent> get events => _controller.stream;

  @override
  GatewayConnectionState get connectionState => _state;

  @override
  Future<void> connect() async {
    if (_state == GatewayConnectionState.connected) return;
    _setState(GatewayConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (_controller.isClosed) return;
    _setState(GatewayConnectionState.connected);
    if (activityEnabled) {
      _scheduleIncoming();
      _schedulePresence();
    }
  }

  @override
  Future<void> disconnect() async {
    _cancelTimers();
    _setState(GatewayConnectionState.disconnected);
  }

  @override
  void focusChannel({required String serverId, required String channelId}) {
    _focusedServerId = serverId;
    _focusedChannelId = channelId;
  }

  @override
  Future<void> sendMessage({
    required String channelId,
    required String clientNonce,
    required Uint8List envelope,
    Attachment? attachment,
    String? replyToId,
  }) async {
    if (_state != GatewayConnectionState.connected) {
      throw StateError('Gateway is not connected');
    }
    _after(roundTripLatency, () {
      _emit(
        MessageReceived(
          channelId: channelId,
          messageId: _nextMessageId(),
          seq: _nextSeq(channelId),
          authorId: currentUserId,
          envelope: envelope,
          sentAt: DateTime.now(),
          clientNonce: clientNonce,
          attachment: attachment,
          replyToId: replyToId,
        ),
      );
      // Sometimes a teammate responds to what you said.
      if (activityEnabled && _random.nextDouble() < 0.35) {
        _simulateTeammateMessage(channelId, delayBeforeTyping: 900);
      }
    });
  }

  @override
  void sendTyping(String channelId) {
    // Nothing to fan out in the mock; real impl sends a datagram.
  }

  @override
  Future<void> dispose() async {
    _cancelTimers();
    await _controller.close();
  }

  // --- simulation ------------------------------------------------------------

  void _scheduleIncoming() {
    final delay = Duration(milliseconds: 6000 + _random.nextInt(6000));
    _after(delay, () {
      final channelId = _pickChannelForActivity();
      if (channelId != null) _simulateTeammateMessage(channelId);
      _scheduleIncoming();
    });
  }

  void _schedulePresence() {
    final delay = Duration(milliseconds: 15000 + _random.nextInt(15000));
    _after(delay, () {
      final server = _servers[_focusedServerId];
      if (server != null) {
        final others =
            server.memberIds.where((id) => id != currentUserId).toList();
        if (others.isNotEmpty) {
          _emit(
            PresenceChanged(
              userId: others[_random.nextInt(others.length)],
              presence: Presence.values[_random.nextInt(Presence.values.length)],
            ),
          );
        }
      }
      _schedulePresence();
    });
  }

  /// Mostly the focused channel; occasionally a sibling channel so unread
  /// badges light up in the sidebar.
  String? _pickChannelForActivity() {
    final focused = _focusedChannelId;
    if (focused == null) return null;
    if (_random.nextDouble() < 0.7) return focused;
    final siblings = _channels.values
        .where(
          (c) =>
              c.serverId == _focusedServerId &&
              c.kind == ChannelKind.text &&
              c.id != focused,
        )
        .toList();
    return siblings.isEmpty
        ? focused
        : siblings[_random.nextInt(siblings.length)].id;
  }

  void _simulateTeammateMessage(String channelId, {int delayBeforeTyping = 0}) {
    final channel = _channels[channelId];
    final server = channel == null ? null : _servers[channel.serverId];
    if (channel == null || server == null) return;

    final candidates =
        server.memberIds.where((id) => id != currentUserId).toList();
    if (candidates.isEmpty) return;
    final authorId = candidates[_random.nextInt(candidates.length)];
    final line = _cannedLines[_random.nextInt(_cannedLines.length)];

    _after(Duration(milliseconds: delayBeforeTyping), () {
      _emit(TypingStarted(channelId: channelId, userId: authorId));
      final typingFor = Duration(milliseconds: 1500 + _random.nextInt(1800));
      _after(typingFor, () async {
        final envelope = await crypto.encrypt(
          conversationId: channelId,
          scheme: channel.scheme,
          plaintext: line,
        );
        _emit(
          MessageReceived(
            channelId: channelId,
            messageId: _nextMessageId(),
            seq: _nextSeq(channelId),
            authorId: authorId,
            envelope: envelope,
            sentAt: DateTime.now(),
          ),
        );
      });
    });
  }

  // --- plumbing --------------------------------------------------------------

  int _nextSeq(String channelId) =>
      _seqs[channelId] = (_seqs[channelId] ?? 0) + 1;

  String _nextMessageId() => 'srv_${++_messageCounter}';

  void _setState(GatewayConnectionState state) {
    _state = state;
    _emit(ConnectionStateChanged(state));
  }

  void _emit(GatewayEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  void _after(Duration delay, FutureOr<void> Function() action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (!_controller.isClosed) action();
    });
    _timers.add(timer);
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}
