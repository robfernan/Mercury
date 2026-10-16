import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/seed_data.dart';
import 'crypto/crypto_engine.dart';
import 'crypto/mock_crypto_engine.dart';
import 'gateway/gateway_client.dart';
import 'gateway/mock_gateway_client.dart';

/// The crypto boundary. Override with the uniffi-backed engine once the Rust
/// core bindings are generated into `lib/src/generated/`.
final cryptoEngineProvider = Provider<CryptoEngine>(
  (ref) => MockCryptoEngine(),
);

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
    initialSeqs: {
      for (final entry in history.entries)
        entry.key: entry.value.fold(0, (max, m) => (m.seq ?? 0) > max ? m.seq! : max),
    },
  );
  ref.onDispose(gateway.dispose);
  gateway.connect();
  return gateway;
});
