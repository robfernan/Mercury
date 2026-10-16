import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/seed_data.dart';
import '../features/chat/chat_shell_screen.dart';
import 'routes.dart';

export 'routes.dart';

final appRouter = GoRouter(
  initialLocation: Routes.channel('s_mercury', 'c_general'),
  routes: [
    GoRoute(
      path: Routes.root,
      redirect: (context, state) {
        return Routes.channel(
          SeedData.servers.first.id,
          'c_general',
        );
      },
    ),
    GoRoute(
      path: Routes.channelPattern,
      builder: (context, state) {
        final serverId = state.pathParameters['serverId'] ?? SeedData.servers.first.id;
        final channelId = state.pathParameters['channelId'] ?? 'c_general';

        return ChatShellScreen(
          serverId: serverId,
          channelId: channelId,
        );
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Route not found: ${state.uri}',
        style: const TextStyle(color: Colors.white),
      ),
    ),
  ),
);
