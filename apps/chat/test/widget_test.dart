import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mercury_chat/main.dart';
import 'package:mercury_chat/src/core/crypto/mock_crypto_engine.dart';
import 'package:mercury_chat/src/core/gateway/gateway_client.dart';
import 'package:mercury_chat/src/core/gateway/mock_gateway_client.dart';
import 'package:mercury_chat/src/core/providers.dart';
import 'package:mercury_chat/src/data/seed_data.dart';

void main() {
  testWidgets('Mercury chat shell renders initial channel and server rail', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testGateway = MockGatewayClient(
      crypto: MockCryptoEngine(),
      currentUserId: SeedData.currentUserId,
      servers: SeedData.servers,
      channels: SeedData.channels,
      cannedLines: SeedData.cannedLines,
      activityEnabled: false, // Disables background timers for deterministic test runs
    );
    addTearDown(testGateway.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gatewayClientProvider.overrideWithValue(testGateway),
        ],
        child: const MercuryApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify channel and server elements render
    expect(find.text('Mercury Core'), findsOneWidget);
    expect(find.text('general'), findsWidgets);
    expect(find.text('E2EE Verified'), findsOneWidget);
  });
}
