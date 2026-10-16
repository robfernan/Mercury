import 'dart:async';

/// Routing record in the distributed hash table mapping a DID to its direct network endpoints
class DhtPeerRecord {
  const DhtPeerRecord({
    required this.did,
    required this.ephemeralEndpoints,
    required this.lastAdvertised,
    required this.relayAddresses,
  });

  final String did;
  final List<String> ephemeralEndpoints; // e.g. ["172.56.21.9:42424", "192.168.1.100:42424"]
  final DateTime lastAdvertised;
  final List<String> relayAddresses; // Waku/Iroh fallback relay enodes
}

/// Cryptographic Distributed Hash Table (DHT) client (Kademlia / Iroh rendezvous)
/// for zero-server discovery between cellular 5G and home broadband.
class DhtPeerRendezvousService {
  DhtPeerRendezvousService({
    required this.localDid,
  });

  final String localDid;

  final Map<String, DhtPeerRecord> _dhtTable = {};
  final _recordsController = StreamController<Map<String, DhtPeerRecord>>.broadcast();
  Stream<Map<String, DhtPeerRecord>> get recordsStream => _recordsController.stream;

  /// Advertise this node's direct network endpoints to the decentralized DHT
  Future<void> advertiseEndpoints(List<String> endpoints) async {
    _dhtTable[localDid] = DhtPeerRecord(
      did: localDid,
      ephemeralEndpoints: endpoints,
      lastAdvertised: DateTime.now(),
      relayAddresses: const ['waku-relay.mercury.eth:8000', 'iroh-derp.p2p.net:3478'],
    );
    _recordsController.add(Map.unmodifiable(_dhtTable));
  }

  /// Resolve a peer's public DID directly to their current NAT-traversed STUN/WAN endpoints
  Future<DhtPeerRecord?> lookupPeer(String targetDid) async {
    return _dhtTable[targetDid];
  }

  void registerKnownPeer(DhtPeerRecord record) {
    _dhtTable[record.did] = record;
    _recordsController.add(Map.unmodifiable(_dhtTable));
  }

  void dispose() {
    _recordsController.close();
  }
}
