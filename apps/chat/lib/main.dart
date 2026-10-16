import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/features/chat/state/chat_providers.dart';
import 'src/routing/app_router.dart';
import 'src/theme/mercury_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: MercuryApp(),
    ),
  );
}

class MercuryApp extends ConsumerWidget {
  const MercuryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly activate real-time gateway sync listener across the entire app
    ref.watch(gatewaySyncProvider);

    return MaterialApp.router(
      title: 'Mercury',
      debugShowCheckedModeBanner: false,
      theme: MercuryTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
