import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/seed_data.dart';
import 'crypto/crypto_engine.dart';
import 'crypto/mock_crypto_engine.dart';
import 'gateway/gateway_client.dart';
import 'gateway/mock_gateway_client.dart';

import 'crypto/native_crypto_engine.dart';

import '../data/local/mercury_database.dart';
import '../data/local/local_storage_repository.dart';
import 'p2p/local_lan_discovery.dart';
import 'p2p/decentralized_mailbox.dart';
import 'p2p/transport_router.dart';

export 'p2p/local_lan_discovery.dart';
export 'p2p/decentralized_mailbox.dart';
export 'p2p/transport_router.dart';

/// The crypto boundary. Uses real native Rust engine if compiled dylib exists,
/// falling back seamlessly to MockCryptoEngine in dev/headless modes.
final cryptoEngineProvider = Provider<CryptoEngine>(
  (ref) => NativeRustCryptoEngine.tryLoad() ?? MockCryptoEngine(),
);

/// Local Drift SQLite database with FTS5 virtual table
final mercuryDatabaseProvider = Provider<MercuryDatabase>((ref) {
  final db = MercuryDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Repository for persistent message store, search, and settings
final localStorageRepositoryProvider = Provider<LocalStorageRepository>((ref) {
  return LocalStorageRepository(ref.watch(mercuryDatabaseProvider));
});

/// Decrypted local history. Stand-in for the Drift/SQLite store.
final seedHistoryProvider = Provider<Map<String, List<ChatMessage>>>(
  (ref) => SeedData.messages(DateTime.now()),
);

/// The real-time gateway. Connects eagerly when first read.
final gatewayClientProvider = Provider<GatewayClient>((ref) {
  final history = ref.watch(seedHistoryProvider);
  final gateway = MockGatewayClient(
    crypto: ref.watch(cryptoEngineProvider),
    currentUserId: SeedData.currentUserId,
    servers: SeedData.servers,
    channels: SeedData.channels,
    cannedLines: SeedData.cannedLines,
    activityEnabled: false,
    initialSeqs: {
      for (final entry in history.entries)
        entry.key: entry.value.fold(0, (max, m) => (m.seq ?? 0) > max ? m.seq! : max),
    },
  );
  ref.onDispose(gateway.dispose);
  gateway.connect();
  return gateway;
});

/// Provider for local LAN peer discovery over Wi-Fi
final localLanDiscoveryProvider = Provider<LocalLanDiscoveryService>((ref) {
  final service = LocalLanDiscoveryService(
    localPeerId: SeedData.currentUserId,
    localDisplayName: 'Mercury Node',
    deviceType: 'Windows 11 Workstation',
  );
  ref.onDispose(service.dispose);
  service.start();
  return service;
});

/// Stream of LAN-discovered peers
final discoveredPeersStreamProvider = StreamProvider<List<DiscoveredPeer>>((ref) {
  final discovery = ref.watch(localLanDiscoveryProvider);
  return discovery.peersStream;
});

/// Decentralized store-and-forward offline mailbox service
final decentralizedMailboxProvider = Provider<DecentralizedMailboxService>((ref) {
  final mailbox = DecentralizedMailboxService();
  ref.onDispose(mailbox.dispose);
  return mailbox;
});

/// Web4 zero-trust dynamic transport router
final transportRouterProvider = Provider<Web4TransportRouter>((ref) {
  final router = Web4TransportRouter(localPeerId: SeedData.currentUserId);
  ref.onDispose(router.dispose);
  return router;
});
