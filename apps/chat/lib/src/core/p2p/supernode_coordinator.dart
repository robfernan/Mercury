import 'dart:async';

/// Role of a P2P node in a collaborative channel.
enum P2PNodeRole {
  /// Standard client node (e.g. mobile on 5G or laptop on battery)
  edgeClient,

  /// Plugged-in high-bandwidth workstation acting as encrypted packet distributor for the group
  superNode,
}

/// Dynamic P2P coordinator that elects the most capable peer (e.g. Windows 11 Desktop on AC power)
/// to act as a zero-knowledge SuperNode forwarder for multi-user channels, eliminating video/audio bottlenecks.
class P2PSuperNodeCoordinator {
  P2PSuperNodeCoordinator({
    required this.localPeerId,
    this.isAcPowered = true,
    this.hasHighBandwidthUplink = true,
  }) {
    // Determine initial role based on hardware capabilities
    _role = (isAcPowered && hasHighBandwidthUplink)
        ? P2PNodeRole.superNode
        : P2PNodeRole.edgeClient;
  }

  final String localPeerId;
  final bool isAcPowered;
  final bool hasHighBandwidthUplink;

  late P2PNodeRole _role;
  P2PNodeRole get role => _role;

  String? _activeSuperNodePeerId;
  String? get activeSuperNodePeerId => _activeSuperNodePeerId;

  final _roleController = StreamController<P2PNodeRole>.broadcast();
  Stream<P2PNodeRole> get roleStream => _roleController.stream;

  /// Elect the best SuperNode among available peers in a channel
  void evaluateSuperNodeElection(List<Map<String, dynamic>> peers) {
    // If local machine is AC-powered desktop, take priority
    if (isAcPowered && hasHighBandwidthUplink) {
      _role = P2PNodeRole.superNode;
      _activeSuperNodePeerId = localPeerId;
    } else {
      _role = P2PNodeRole.edgeClient;
      // Pick first desktop candidate from peer list
      for (final p in peers) {
        if (p['isAcPowered'] == true && p['deviceType'].toString().contains('Desktop')) {
          _activeSuperNodePeerId = p['id'] as String;
          break;
        }
      }
    }
    _roleController.add(_role);
  }

  void dispose() {
    _roleController.close();
  }
}
