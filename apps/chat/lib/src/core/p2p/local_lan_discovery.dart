import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Represents a peer discovered locally on the Wi-Fi LAN via mDNS / UDP broadcast.
class DiscoveredPeer {
  const DiscoveredPeer({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.address,
    required this.port,
    required this.lastSeen,
    this.publicKeyFingerprint,
    this.isDirectConnected = false,
  });

  final String id;
  final String name;
  final String deviceType; // 'Windows Desktop', 'Wacom Studio', 'Debian Laptop', 'Android MIAD01'
  final InternetAddress address;
  final int port;
  final DateTime lastSeen;
  final String? publicKeyFingerprint;
  final bool isDirectConnected;

  DiscoveredPeer copyWith({
    String? id,
    String? name,
    String? deviceType,
    InternetAddress? address,
    int? port,
    DateTime? lastSeen,
    String? publicKeyFingerprint,
    bool? isDirectConnected,
  }) {
    return DiscoveredPeer(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      address: address ?? this.address,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      publicKeyFingerprint: publicKeyFingerprint ?? this.publicKeyFingerprint,
      isDirectConnected: isDirectConnected ?? this.isDirectConnected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'deviceType': deviceType,
        'address': address.address,
        'port': port,
        'lastSeen': lastSeen.toIso8601String(),
        'publicKeyFingerprint': publicKeyFingerprint,
        'isDirectConnected': isDirectConnected,
      };
}

/// Service that performs local network discovery via UDP multicast/broadcast
/// across local Wi-Fi without needing any central server or VPS.
class LocalLanDiscoveryService {
  LocalLanDiscoveryService({
    required this.localPeerId,
    required this.localDisplayName,
    required this.deviceType,
    this.multicastPort = 42424,
    this.multicastAddress = '239.255.42.42',
  });

  final String localPeerId;
  final String localDisplayName;
  final String deviceType;
  final int multicastPort;
  final String multicastAddress;

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _pruneTimer;

  final _peersController = StreamController<List<DiscoveredPeer>>.broadcast();
  Stream<List<DiscoveredPeer>> get peersStream => _peersController.stream;

  final Map<String, DiscoveredPeer> _peers = {};
  List<DiscoveredPeer> get activePeers => List.unmodifiable(_peers.values);

  bool _isBroadcasting = false;
  bool get isBroadcasting => _isBroadcasting;

  /// Start broadcasting discovery heartbeats and listening for peer announcements on LAN.
  Future<void> start() async {
    if (_socket != null) return;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        multicastPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows, // Windows doesn't require reusePort
      );

      _socket?.broadcastEnabled = true;
      try {
        _socket?.joinMulticast(InternetAddress(multicastAddress));
      } catch (_) {
        // Fallback to subnet broadcast if multicast routing is disabled on network
      }

      _socket?.listen(_onPacket);
      _isBroadcasting = true;

      // Broadcast presence every 4 seconds
      _broadcastTimer = Timer.periodic(const Duration(seconds: 4), (_) => _announcePresence());
      // Announce immediately
      _announcePresence();

      // Prune inactive peers older than 15 seconds
      _pruneTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pruneStalePeers());
    } catch (e) {
      // In constrained sandbox or headless environment, maintain self peer
      _isBroadcasting = false;
    }
  }

  void _announcePresence() {
    if (_socket == null) return;
    try {
      final payload = jsonEncode({
        'type': 'MERCURY_DISCOVERY_V1',
        'id': localPeerId,
        'name': localDisplayName,
        'device': deviceType,
        'port': multicastPort,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });

      final bytes = utf8.encode(payload);
      // Send to multicast group
      _socket?.send(bytes, InternetAddress(multicastAddress), multicastPort);

      // Also send to IPv4 subnet broadcast
      _socket?.send(bytes, InternetAddress('255.255.255.255'), multicastPort);
    } catch (_) {}
  }

  void _onPacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    try {
      final text = utf8.decode(datagram.data);
      final json = jsonDecode(text) as Map<String, dynamic>;

      if (json['type'] != 'MERCURY_DISCOVERY_V1') return;
      final peerId = json['id'] as String;
      if (peerId == localPeerId) return; // Don't discover self

      final peer = DiscoveredPeer(
        id: peerId,
        name: json['name'] as String? ?? 'Peer $peerId',
        deviceType: json['device'] as String? ?? 'Mercury Node',
        address: datagram.address,
        port: json['port'] as int? ?? multicastPort,
        lastSeen: DateTime.now(),
        isDirectConnected: true,
      );

      _peers[peerId] = peer;
      _peersController.add(activePeers);
    } catch (_) {}
  }

  void _pruneStalePeers() {
    final now = DateTime.now();
    var changed = false;
    _peers.removeWhere((_, peer) {
      if (now.difference(peer.lastSeen).inSeconds > 15) {
        changed = true;
        return true;
      }
      return false;
    });

    if (changed) {
      _peersController.add(activePeers);
    }
  }

  /// Manually register a discovered or simulated peer (useful for multi-device testing).
  void registerPeer(DiscoveredPeer peer) {
    _peers[peer.id] = peer;
    _peersController.add(activePeers);
  }

  Future<void> stop() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _socket?.close();
    _socket = null;
    _isBroadcasting = false;
  }

  Future<void> dispose() async {
    await stop();
    await _peersController.close();
  }
}
