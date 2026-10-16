import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/mercury_theme.dart';
import 'state/chat_providers.dart';
import 'widgets/channel_sidebar.dart';
import 'widgets/chat_feed_view.dart';
import 'widgets/member_sidebar.dart';
import 'widgets/server_rail.dart';

class ChatShellScreen extends ConsumerStatefulWidget {
  const ChatShellScreen({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  final String serverId;
  final String channelId;

  @override
  ConsumerState<ChatShellScreen> createState() => _ChatShellScreenState();
}

class _ChatShellScreenState extends ConsumerState<ChatShellScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _syncActiveLocation();
  }

  @override
  void didUpdateWidget(covariant ChatShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverId != widget.serverId ||
        oldWidget.channelId != widget.channelId) {
      _syncActiveLocation();
    }
  }

  void _syncActiveLocation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activeLocationProvider.notifier).focus(
              (serverId: widget.serverId, channelId: widget.channelId),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(serverByIdProvider(widget.serverId));
    final channel = ref.watch(channelByIdProvider(widget.channelId));
    final memberListVisible = ref.watch(memberListVisibleProvider);

    if (server == null || channel == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: MercuryColors.accent),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1050;
        final isTablet = constraints.maxWidth >= 720 && constraints.maxWidth < 1050;

        return Scaffold(
          key: _scaffoldKey,
          drawer: isTablet || !isDesktop
              ? Drawer(
                  child: Row(
                    children: [
                      ServerRail(activeServerId: widget.serverId),
                      Expanded(
                        child: ChannelSidebar(
                          serverId: widget.serverId,
                          activeChannelId: widget.channelId,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          body: Row(
            children: [
              // 1. Server Rail (Desktop only)
              if (isDesktop) ServerRail(activeServerId: widget.serverId),

              // 2. Channel Sidebar (Desktop only)
              if (isDesktop)
                ChannelSidebar(
                  serverId: widget.serverId,
                  activeChannelId: widget.channelId,
                ),

              // 3. Main Chat Feed Area
              Expanded(
                child: ChatFeedView(
                  server: server,
                  channel: channel,
                  onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ),

              // 4. Member List Sidebar (Desktop only, if toggled on)
              if (isDesktop && memberListVisible)
                MemberSidebar(serverId: widget.serverId),
            ],
          ),
        );
      },
    );
  }
}
