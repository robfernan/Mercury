import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/gateway/gateway_client.dart';
import '../../../core/providers.dart';
import '../../../data/models.dart';
import '../../../data/seed_data.dart';

// --- Directory data ----------------------------------------------------------

final serversProvider = Provider<List<ChatServer>>((ref) => SeedData.servers);

final channelsProvider = Provider<List<ChatChannel>>((ref) => SeedData.channels);

final channelsForServerProvider = Provider.family<List<ChatChannel>, String>(
  (ref, serverId) => ref
      .watch(channelsProvider)
      .where((c) => c.serverId == serverId)
      .toList(growable: false),
);

final channelByIdProvider = Provider.family<ChatChannel?, String>((ref, id) {
  for (final c in ref.watch(channelsProvider)) {
    if (c.id == id) return c;
  }
  return null;
});

final serverByIdProvider = Provider.family<ChatServer?, String>((ref, id) {
  for (final s in ref.watch(serversProvider)) {
    if (s.id == id) return s;
  }
  return null;
});

/// First text channel of a server; used for redirects when switching servers.
final defaultChannelForServerProvider = Provider.family<ChatChannel?, String>(
  (ref, serverId) {
    for (final c in ref.watch(channelsForServerProvider(serverId))) {
      if (c.kind == ChannelKind.text) return c;
    }
    return null;
  },
);

// --- Users & presence ----------------------------------------------------------

class UsersNotifier extends Notifier<Map<String, ChatUser>> {
  @override
  Map<String, ChatUser> build() {
    _loadFromStorage();
    return {for (final u in SeedData.users) u.id: u};
  }

  Future<void> _loadFromStorage() async {
    final repo = ref.read(localStorageRepositoryProvider);
    final profiles = await repo.loadProfiles();
    if (profiles.isNotEmpty) {
      state = {...state, ...profiles};
    }
  }

  void setPresence(String userId, Presence presence) {
    final user = state[userId];
    if (user == null || user.presence == presence) return;
    state = {...state, userId: user.copyWith(presence: presence)};
  }

  void setProfile({
    required String userId,
    required String displayName,
    String? statusText,
  }) {
    final user = state[userId];
    if (user == null) return;
    final updated = ChatUser(
      id: user.id,
      displayName: displayName,
      handle: user.handle,
      avatarColor: user.avatarColor,
      presence: user.presence,
      statusText: statusText,
      role: user.role,
    );
    state = {...state, userId: updated};
    ref.read(localStorageRepositoryProvider).saveProfile(updated);
  }
}

final usersProvider = NotifierProvider<UsersNotifier, Map<String, ChatUser>>(
  UsersNotifier.new,
);

final currentUserProvider = Provider<ChatUser>(
  (ref) => ref.watch(usersProvider)[SeedData.currentUserId]!,
);

final userByIdProvider = Provider.family<ChatUser?, String>(
  (ref, id) => ref.watch(usersProvider)[id],
);

final membersForServerProvider = Provider.family<List<ChatUser>, String>((
  ref,
  serverId,
) {
  final server = ref.watch(serverByIdProvider(serverId));
  final users = ref.watch(usersProvider);
  if (server == null) return const [];
  return [
    for (final id in server.memberIds) ?users[id],
  ];
});

// --- Navigation focus -----------------------------------------------------------

typedef ChannelLocation = ({String serverId, String channelId});

/// Mirrors the router's current location so non-widget code (gateway sync,
/// unread counters) knows which channel is on screen.
class ActiveLocationNotifier extends Notifier<ChannelLocation?> {
  @override
  ChannelLocation? build() => null;

  void focus(ChannelLocation location) {
    if (state == location) return;
    state = location;
    ref
        .read(gatewayClientProvider)
        .focusChannel(
          serverId: location.serverId,
          channelId: location.channelId,
        );
    ref.read(unreadProvider.notifier).clear(location.channelId);
  }
}

final activeLocationProvider =
    NotifierProvider<ActiveLocationNotifier, ChannelLocation?>(
      ActiveLocationNotifier.new,
    );

// --- Unread counters -------------------------------------------------------------

class UnreadNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {
    'c_gateway': 3,
    'c_roadmap': 1,
    'c_rust_help': 1,
    'c_critique': 2,
  };

  void increment(String channelId) =>
      state = {...state, channelId: (state[channelId] ?? 0) + 1};

  void clear(String channelId) {
    if (!state.containsKey(channelId)) return;
    state = {...state}..remove(channelId);
  }
}

final unreadProvider = NotifierProvider<UnreadNotifier, Map<String, int>>(
  UnreadNotifier.new,
);

final serverUnreadProvider = Provider.family<int, String>((ref, serverId) {
  final unread = ref.watch(unreadProvider);
  return ref
      .watch(channelsForServerProvider(serverId))
      .fold(0, (sum, c) => sum + (unread[c.id] ?? 0));
});

// --- Messages --------------------------------------------------------------------

const _uuid = Uuid();

/// Message list for one channel, in ascending `seq` order (pending messages,
/// which have no seq yet, sit at the end).
class MessagesNotifier extends Notifier<List<ChatMessage>> {
  MessagesNotifier(this.channelId);

  final String channelId;

  @override
  List<ChatMessage> build() {
    _loadFromDatabase();
    return List.unmodifiable(ref.read(seedHistoryProvider)[channelId] ?? const []);
  }

  Future<void> _loadFromDatabase() async {
    final repo = ref.read(localStorageRepositoryProvider);
    await repo.seedIfEmpty();
    final stored = await repo.loadMessagesForChannel(channelId);
    if (stored.isNotEmpty) {
      state = List.unmodifiable(stored);
    }
  }

  /// Encrypts locally, appends an optimistic pending copy, then publishes.
  Future<void> send(
    String text, {
    Attachment? attachment,
    String? replyToId,
  }) async {
    final body = text.trim();
    if (body.isEmpty && attachment == null) return;

    final nonce = 'local_${_uuid.v4()}';
    final pending = ChatMessage(
      id: nonce,
      channelId: channelId,
      authorId: SeedData.currentUserId,
      body: body,
      sentAt: DateTime.now(),
      delivery: DeliveryState.pending,
      attachment: attachment,
      replyToId: replyToId,
    );
    state = List.unmodifiable([...state, pending]);
    await ref.read(localStorageRepositoryProvider).saveMessage(pending);

    try {
      final channel = ref.read(channelByIdProvider(channelId));
      final envelope = await ref
          .read(cryptoEngineProvider)
          .encrypt(
            conversationId: channelId,
            scheme: channel!.scheme,
            plaintext: body,
          );
      await ref
          .read(gatewayClientProvider)
          .sendMessage(
            channelId: channelId,
            clientNonce: nonce,
            envelope: envelope,
            attachment: attachment,
            replyToId: replyToId,
          );
    } catch (_) {
      if (!ref.mounted) return;
      _replace(nonce, (m) {
        final failed = m.copyWith(delivery: DeliveryState.failed);
        ref.read(localStorageRepositoryProvider).saveMessage(failed);
        return failed;
      });
    }
  }

  /// Applies a verified, decrypted message from the gateway. If it is the
  /// echo of a pending local message, the pending copy is reconciled in place.
  void applyIncoming(ChatMessage message, {String? clientNonce}) {
    ref.read(localStorageRepositoryProvider).saveMessage(message);
    if (clientNonce != null && state.any((m) => m.id == clientNonce)) {
      _replace(
        clientNonce,
        (m) => m.copyWith(
          id: message.id,
          seq: message.seq,
          delivery: DeliveryState.sent,
        ),
      );
      return;
    }
    if (state.any((m) => m.id == message.id)) return; // idempotent
    final pending = state.where((m) => m.delivery != DeliveryState.sent);
    final confirmed = state.where((m) => m.delivery == DeliveryState.sent);
    state = List.unmodifiable([...confirmed, message, ...pending]);
  }

  void toggleReaction(String messageId, String emoji) {
    final me = SeedData.currentUserId;
    _replace(messageId, (m) {
      final reactions = {
        for (final e in m.reactions.entries) e.key: {...e.value},
      };
      final users = reactions.putIfAbsent(emoji, () => <String>{});
      if (!users.remove(me)) users.add(me);
      if (users.isEmpty) reactions.remove(emoji);
      final updated = m.copyWith(reactions: reactions);
      ref.read(localStorageRepositoryProvider).saveMessage(updated);
      return updated;
    });
  }

  void delete(String messageId) {
    state = List.unmodifiable(state.where((m) => m.id != messageId));
    ref.read(localStorageRepositoryProvider).deleteMessage(messageId);
  }

  Future<void> retry(String messageId) async {
    final failed = state.where((m) => m.id == messageId).firstOrNull;
    if (failed == null || failed.delivery != DeliveryState.failed) return;
    delete(messageId);
    await send(
      failed.body,
      attachment: failed.attachment,
      replyToId: failed.replyToId,
    );
  }

  void _replace(String id, ChatMessage Function(ChatMessage) update) {
    state = List.unmodifiable([
      for (final m in state) m.id == id ? update(m) : m,
    ]);
  }
}

final messagesProvider =
    NotifierProvider.family<MessagesNotifier, List<ChatMessage>, String>(
      MessagesNotifier.new,
    );

// --- Typing indicators ---------------------------------------------------------------

/// channelId → (userId → expiry timer).
class TypingNotifier extends Notifier<Map<String, Set<String>>> {
  static const ttl = Duration(seconds: 4);
  final _timers = <String, Timer>{};

  @override
  Map<String, Set<String>> build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
    });
    return const {};
  }

  void started(String channelId, String userId) {
    final key = '$channelId/$userId';
    _timers.remove(key)?.cancel();
    _timers[key] = Timer(ttl, () => stopped(channelId, userId));
    final users = {...?state[channelId], userId};
    state = {...state, channelId: users};
  }

  void stopped(String channelId, String userId) {
    _timers.remove('$channelId/$userId')?.cancel();
    final users = {...?state[channelId]}..remove(userId);
    state = {...state, channelId: users};
  }
}

final typingProvider =
    NotifierProvider<TypingNotifier, Map<String, Set<String>>>(
      TypingNotifier.new,
    );

final typingUsersProvider = Provider.family<List<ChatUser>, String>((
  ref,
  channelId,
) {
  final ids = ref.watch(typingProvider)[channelId] ?? const {};
  final users = ref.watch(usersProvider);
  return [
    for (final id in ids) ?users[id],
  ];
});

// --- Connection state -------------------------------------------------------------

class ConnectionStateNotifier extends Notifier<GatewayConnectionState> {
  @override
  GatewayConnectionState build() =>
      ref.read(gatewayClientProvider).connectionState;

  void set(GatewayConnectionState value) => state = value;
}

final connectionStateProvider =
    NotifierProvider<ConnectionStateNotifier, GatewayConnectionState>(
      ConnectionStateNotifier.new,
    );

// --- Gateway → state dispatcher ------------------------------------------------------

/// Subscribes to the gateway and routes frames into the relevant notifiers.
/// Watched once at the app root so it lives for the whole session.
final gatewaySyncProvider = Provider<void>((ref) {
  final gateway = ref.watch(gatewayClientProvider);
  final crypto = ref.watch(cryptoEngineProvider);

  Future<void> onMessage(MessageReceived e) async {
    final channel = ref.read(channelByIdProvider(e.channelId));
    if (channel == null) return;
    final decrypted = await crypto.decrypt(
      conversationId: e.channelId,
      scheme: channel.scheme,
      envelope: e.envelope,
    );
    if (!ref.mounted) return;

    ref.read(typingProvider.notifier).stopped(e.channelId, e.authorId);
    ref
        .read(messagesProvider(e.channelId).notifier)
        .applyIncoming(
          ChatMessage(
            id: e.messageId,
            channelId: e.channelId,
            authorId: e.authorId,
            body: decrypted.plaintext,
            sentAt: e.sentAt,
            seq: e.seq,
            verified: decrypted.verified,
            attachment: e.attachment,
            replyToId: e.replyToId,
          ),
          clientNonce: e.clientNonce,
        );

    final active = ref.read(activeLocationProvider);
    if (e.authorId != SeedData.currentUserId &&
        active?.channelId != e.channelId) {
      ref.read(unreadProvider.notifier).increment(e.channelId);
    }
  }

  final sub = gateway.events.listen((event) {
    switch (event) {
      case ConnectionStateChanged(:final state):
        ref.read(connectionStateProvider.notifier).set(state);
      case MessageReceived():
        onMessage(event);
      case TypingStarted():
        // Disabled mock typing simulation
        break;
      case PresenceChanged(:final userId, :final presence):
        ref.read(usersProvider.notifier).setPresence(userId, presence);
    }
  });
  ref.onDispose(sub.cancel);
});

// --- Composer -------------------------------------------------------------------------

class ComposerState {
  const ComposerState({this.replyTo, this.attachment});

  final ChatMessage? replyTo;
  final Attachment? attachment;
}

/// Per-channel draft metadata (reply target, staged attachment).
class ComposerNotifier extends Notifier<ComposerState> {
  ComposerNotifier(this.channelId);

  final String channelId;

  @override
  ComposerState build() => const ComposerState();

  void replyTo(ChatMessage? message) =>
      state = ComposerState(replyTo: message, attachment: state.attachment);

  void attach(Attachment? attachment) =>
      state = ComposerState(replyTo: state.replyTo, attachment: attachment);

  void reset() => state = const ComposerState();
}

final composerProvider =
    NotifierProvider.family<ComposerNotifier, ComposerState, String>(
      ComposerNotifier.new,
    );

// --- Voice / audio status -----------------------------------------------------------------

class VoiceState {
  const VoiceState({
    this.muted = false,
    this.deafened = false,
    this.connectedChannelId,
  });

  final bool muted;
  final bool deafened;
  final String? connectedChannelId;
}

/// Local voice controls. LiveKit wiring lands later; this only drives UI.
class VoiceNotifier extends Notifier<VoiceState> {
  @override
  VoiceState build() => const VoiceState();

  /// Unmuting while deafened also undeafens.
  void toggleMute() => state = VoiceState(
    muted: !state.muted,
    deafened: state.muted ? false : state.deafened,
    connectedChannelId: state.connectedChannelId,
  );

  /// Deafening also mutes, like every voice app users already know.
  void toggleDeafen() {
    final deafen = !state.deafened;
    state = VoiceState(
      muted: deafen ? true : state.muted,
      deafened: deafen,
      connectedChannelId: state.connectedChannelId,
    );
  }

  void join(String channelId) => state = VoiceState(
    muted: state.muted,
    deafened: state.deafened,
    connectedChannelId: channelId,
  );

  void leave() =>
      state = VoiceState(muted: state.muted, deafened: state.deafened);
}

final voiceProvider = NotifierProvider<VoiceNotifier, VoiceState>(
  VoiceNotifier.new,
);

// --- Layout preferences ------------------------------------------------------------------

class MemberListVisible extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final memberListVisibleProvider = NotifierProvider<MemberListVisible, bool>(
  MemberListVisible.new,
);
