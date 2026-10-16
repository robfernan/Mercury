import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models.dart';
import '../../../routing/routes.dart';
import '../../../theme/mercury_theme.dart';
import '../state/chat_providers.dart';

/// Leftmost column: Mercury mark + one icon per server.
class ServerRail extends ConsumerWidget {
  const ServerRail({super.key, required this.activeServerId});

  final String activeServerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);

    return Container(
      width: 72,
      color: MercuryColors.rail,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            const _MercuryMark(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Divider(),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: servers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _ServerIcon(
                  server: servers[i],
                  active: servers[i].id == activeServerId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MercuryMark extends StatelessWidget {
  const _MercuryMark();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Mercury',
      preferBelow: false,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9B8CFF), Color(0xFF5B4BD6)],
          ),
          boxShadow: [
            BoxShadow(
              color: MercuryColors.accent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _ServerIcon extends ConsumerStatefulWidget {
  const _ServerIcon({required this.server, required this.active});

  final ChatServer server;
  final bool active;

  @override
  ConsumerState<_ServerIcon> createState() => _ServerIconState();
}

class _ServerIconState extends ConsumerState<_ServerIcon> {
  var _hovered = false;

  void _open() {
    final channel = ref.read(defaultChannelForServerProvider(widget.server.id));
    if (channel == null) return;
    context.go(Routes.channel(widget.server.id, channel.id));
    Scaffold.maybeOf(context)?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.server;
    final unread = ref.watch(serverUnreadProvider(server.id));
    final highlighted = widget.active || _hovered;

    final pillHeight = widget.active
        ? 40.0
        : _hovered
        ? 20.0
        : unread > 0
        ? 8.0
        : 0.0;

    return Semantics(
      button: true,
      selected: widget.active,
      label: unread > 0 ? '${server.name}, $unread unread' : server.name,
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 4,
                height: pillHeight,
                decoration: const BoxDecoration(
                  color: MercuryColors.textPrimary,
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(4),
                  ),
                ),
              ),
            ),
            Tooltip(
              message: server.name,
              preferBelow: false,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: GestureDetector(
                  onTap: _open,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: highlighted
                          ? server.accent
                          : MercuryColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(
                        highlighted ? 16 : 24,
                      ),
                    ),
                    child: Text(
                      server.monogram,
                      style: TextStyle(
                        color: highlighted
                            ? Colors.white
                            : MercuryColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (unread > 0 && !widget.active)
              Positioned(
                right: 10,
                bottom: 0,
                child: _Badge(count: unread),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: MercuryColors.danger,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: MercuryColors.rail, width: 3),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
