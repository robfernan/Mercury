import 'package:flutter/widgets.dart';

import '../core/crypto/crypto_engine.dart';
import 'models.dart';

/// Static demo data used to populate the UI shell before the real API and
/// local Drift store are wired up. Timestamps are relative to [now] so the
/// feed always looks fresh.
abstract final class SeedData {
  static const currentUserId = 'u_rob';

  static const users = <ChatUser>[
    ChatUser(
      id: currentUserId,
      displayName: 'Rob Fernandez',
      handle: 'robfernan',
      avatarColor: Color(0xFF7C6CF2),
      statusText: 'Shipping the client shell',
      role: 'Maintainer',
    ),
    ChatUser(
      id: 'u_ada',
      displayName: 'Ada Okafor',
      handle: 'ada',
      avatarColor: Color(0xFF2EB67D),
      statusText: 'MLS tree math all day',
      role: 'Crypto',
    ),
    ChatUser(
      id: 'u_kenji',
      displayName: 'Kenji Watanabe',
      handle: 'kenji',
      avatarColor: Color(0xFFE8A33D),
      role: 'Gateway',
    ),
    ChatUser(
      id: 'u_lena',
      displayName: 'Lena Fischer',
      handle: 'lena',
      avatarColor: Color(0xFFE5537A),
      presence: Presence.idle,
      statusText: 'Back in 20',
      role: 'Design',
    ),
    ChatUser(
      id: 'u_marco',
      displayName: 'Marco Rossi',
      handle: 'marco',
      avatarColor: Color(0xFF3FA7D6),
      presence: Presence.doNotDisturb,
      statusText: 'Focus mode',
    ),
    ChatUser(
      id: 'u_priya',
      displayName: 'Priya Natarajan',
      handle: 'priya',
      avatarColor: Color(0xFFB36AE2),
      role: 'Flutter',
    ),
    ChatUser(
      id: 'u_sam',
      displayName: 'Sam Lee',
      handle: 'sam',
      avatarColor: Color(0xFF5BC0BE),
      presence: Presence.offline,
    ),
    ChatUser(
      id: 'u_noor',
      displayName: 'Noor Haddad',
      handle: 'noor',
      avatarColor: Color(0xFFF2785C),
      presence: Presence.offline,
    ),
  ];

  static const servers = <ChatServer>[
    ChatServer(
      id: 's_mercury',
      name: 'Mercury Core',
      accent: Color(0xFF7C6CF2),
      memberIds: [
        currentUserId,
        'u_ada',
        'u_kenji',
        'u_lena',
        'u_marco',
        'u_priya',
        'u_sam',
        'u_noor',
      ],
    ),
    ChatServer(
      id: 's_rust',
      name: 'Rust Crew',
      accent: Color(0xFFE8743D),
      memberIds: [currentUserId, 'u_ada', 'u_kenji', 'u_sam'],
    ),
    ChatServer(
      id: 's_design',
      name: 'Design Guild',
      accent: Color(0xFFE5537A),
      memberIds: [currentUserId, 'u_lena', 'u_priya', 'u_noor', 'u_marco'],
    ),
  ];

  static const channels = <ChatChannel>[
    // Mercury Core
    ChatChannel(
      id: 'c_announcements',
      serverId: 's_mercury',
      name: 'announcements',
      category: 'Information',
      topic: 'Release notes and project-wide news',
    ),
    ChatChannel(
      id: 'c_roadmap',
      serverId: 's_mercury',
      name: 'roadmap',
      category: 'Information',
      topic: 'What we are building next',
    ),
    ChatChannel(
      id: 'c_general',
      serverId: 's_mercury',
      name: 'general',
      category: 'Engineering',
      topic: 'Day-to-day chatter · hybrid PQ-MLS encrypted',
    ),
    ChatChannel(
      id: 'c_flutter',
      serverId: 's_mercury',
      name: 'client-flutter',
      category: 'Engineering',
      topic: 'Flutter 3.47 · Riverpod 3.4 · go_router',
    ),
    ChatChannel(
      id: 'c_crypto',
      serverId: 's_mercury',
      name: 'crypto-core',
      category: 'Engineering',
      topic: 'Rust core: Double Ratchet, MLS, CRDT, FTS5',
    ),
    ChatChannel(
      id: 'c_gateway',
      serverId: 's_mercury',
      name: 'gateway',
      category: 'Engineering',
      topic: 'WebTransport / QUIC, seq + gap-fill',
    ),
    ChatChannel(
      id: 'v_standup',
      serverId: 's_mercury',
      name: 'Standup',
      category: 'Voice',
      kind: ChannelKind.voice,
    ),
    ChatChannel(
      id: 'v_pairing',
      serverId: 's_mercury',
      name: 'Pairing',
      category: 'Voice',
      kind: ChannelKind.voice,
    ),
    // Rust Crew
    ChatChannel(
      id: 'c_rust_general',
      serverId: 's_rust',
      name: 'general',
      category: 'Text',
      topic: 'Borrow checker support group',
    ),
    ChatChannel(
      id: 'c_rust_help',
      serverId: 's_rust',
      name: 'help',
      category: 'Text',
    ),
    ChatChannel(
      id: 'c_rust_showcase',
      serverId: 's_rust',
      name: 'showcase',
      category: 'Text',
    ),
    ChatChannel(
      id: 'v_rust_lounge',
      serverId: 's_rust',
      name: 'Lounge',
      category: 'Voice',
      kind: ChannelKind.voice,
    ),
    // Design Guild
    ChatChannel(
      id: 'c_critique',
      serverId: 's_design',
      name: 'critique',
      category: 'Studio',
      topic: 'Post work, get honest feedback',
    ),
    ChatChannel(
      id: 'c_inspiration',
      serverId: 's_design',
      name: 'inspiration',
      category: 'Studio',
    ),
    ChatChannel(
      id: 'c_type_color',
      serverId: 's_design',
      name: 'type-and-color',
      category: 'Studio',
      scheme: EncryptionScheme.hybridPqMls,
    ),
    ChatChannel(
      id: 'v_studio',
      serverId: 's_design',
      name: 'Studio',
      category: 'Voice',
      kind: ChannelKind.voice,
    ),
  ];

  /// Users currently sitting in each voice channel.
  static const voiceOccupants = <String, List<String>>{
    'v_standup': ['u_kenji', 'u_priya'],
    'v_rust_lounge': ['u_ada'],
  };

  /// Seeded history, keyed by channel id. Represents what the local Drift
  /// store would hold after decrypting previously synced messages.
  static Map<String, List<ChatMessage>> messages(DateTime now) {
    final seqs = <String, int>{};
    ChatMessage m(
      String channelId,
      String authorId,
      int minutesAgo,
      String body, {
      String? replyTo,
      Attachment? attachment,
      Map<String, Set<String>> reactions = const {},
    }) {
      final seq = seqs[channelId] = (seqs[channelId] ?? 0) + 1;
      return ChatMessage(
        id: 'm_${channelId}_$seq',
        channelId: channelId,
        authorId: authorId,
        body: body,
        sentAt: now.subtract(Duration(minutes: minutesAgo)),
        seq: seq,
        replyToId: replyTo,
        attachment: attachment,
        reactions: reactions,
      );
    }

    final general = <ChatMessage>[
      m('c_general', 'u_kenji', 182,
          'Morning all. Gateway p99 on the staging fleet is down to **31ms** after the quic-go bump.'),
      m('c_general', 'u_ada', 180, 'Nice. Was that the stream-level flow control change?'),
      m('c_general', 'u_kenji', 179,
          'Yep, plus we stopped coalescing small frames. Head-of-line blocking is basically gone now.',
          reactions: {'🚀': {'u_ada', 'u_priya', currentUserId}}),
      m('c_general', 'u_lena', 121,
          'Dropping the updated chat feed spec here. Grouped messages, hover actions, and the new composer.',
          attachment: const Attachment(
              name: 'chat-feed-spec-v3.pdf',
              sizeBytes: 2516582,
              kind: AttachmentKind.file)),
      m('c_general', 'u_priya', 118,
          'Love the hover toolbar. Are we keeping the *markdown hints* under the composer?'),
      m('c_general', 'u_lena', 117,
          'Yes, but subtle. Only `**bold**`, `*italic*`, `` `code` `` and `> quote` for now.'),
      m('c_general', currentUserId, 64,
          'Starting the Flutter shell today: multi-pane layout, mock crypto engine, mock gateway stream. No native binaries needed to run it.',
          reactions: {'🔥': {'u_ada', 'u_kenji'}, '👀': {'u_lena'}}),
      m('c_general', 'u_ada', 61,
          'Make sure the `CryptoEngine` interface stays async. The uniffi calls will be off the UI isolate.',
          replyTo: 'm_c_general_7'),
      m('c_general', currentUserId, 60, 'Already async across the board 👍'),
      m('c_general', 'u_marco', 22,
          'Reminder: rate limit is **100 msg/min per user**, so please don\'t demo the spam bot in here again 😅',
          reactions: {'😂': {'u_kenji', 'u_priya', 'u_ada'}}),
      m('c_general', 'u_priya', 9,
          'Riverpod 3.4 families with constructor args are so much cleaner than the old FamilyNotifier.'),
      m('c_general', 'u_kenji', 3, 'Gap-fill on reconnect is merged. Send your last acked seq and you get everything after it.'),
    ];

    return {
      'c_general': general,
      'c_announcements': [
        m('c_announcements', currentUserId, 60 * 26,
            '**Mercury v0.1 scaffold is live.** Monorepo layout, pinned toolchains, and docs are in `main`.',
            reactions: {'🎉': {'u_ada', 'u_kenji', 'u_lena', 'u_priya'}}),
        m('c_announcements', 'u_marco', 60 * 5,
            'Security review for the hybrid PQ-MLS handshake is scheduled for Friday.'),
      ],
      'c_roadmap': [
        m('c_roadmap', currentUserId, 60 * 48,
            '> Q4: client shell → Rust core bindings → gateway integration → voice via LiveKit'),
        m('c_roadmap', 'u_ada', 60 * 47, 'Adding passkey enrollment to Q4 as well.'),
      ],
      'c_flutter': [
        m('c_flutter', 'u_priya', 240,
            'Web builds should use `flutter build web --wasm` going forward. WasmGC is fine in all evergreen browsers.'),
        m('c_flutter', currentUserId, 200,
            'Heads up, the `--web-renderer` flag is gone in current Flutter. We need to update the README.'),
        m('c_flutter', 'u_priya', 198, 'Good catch, I\'ll open a PR.'),
      ],
      'c_crypto': [
        m('c_crypto', 'u_ada', 300,
            'ML-KEM-768 + X25519 combiner is in. Benchmarks: keygen 0.09ms, encap 0.11ms on M3.'),
        m('c_crypto', 'u_kenji', 290, 'And Ed25519 verify?'),
        m('c_crypto', 'u_ada', 289, 'Well under the 1ms budget, around 40µs.'),
      ],
      'c_gateway': [
        m('c_gateway', 'u_kenji', 400,
            'Redis fan-out channel naming: `server:{id}:channel:{id}`. Please don\'t invent new patterns.'),
      ],
      'c_rust_general': [
        m('c_rust_general', 'u_ada', 90, 'uniffi 0.29 finally generates sane Dart bindings.'),
        m('c_rust_general', 'u_sam', 85, 'Does it handle async fns yet?'),
        m('c_rust_general', 'u_ada', 84, 'Yes, they come back as `Future`s on the Dart side.'),
      ],
      'c_rust_help': [
        m('c_rust_help', 'u_kenji', 30,
            'Anyone seen `cannot borrow *self as mutable more than once` in a CRDT merge loop?'),
      ],
      'c_rust_showcase': [
        m('c_rust_showcase', 'u_sam', 60 * 30,
            'Wrote a tiny FTS5 tokenizer for CJK text.',
            attachment: const Attachment(
                name: 'cjk_tokenizer.rs', sizeBytes: 14336, kind: AttachmentKind.file)),
      ],
      'c_critique': [
        m('c_critique', 'u_lena', 50, 'New server rail icons, thoughts?',
            attachment: const Attachment(
                name: 'rail-icons.png', sizeBytes: 842137, kind: AttachmentKind.image)),
        m('c_critique', 'u_priya', 45, 'The active indicator pill reads really well.'),
      ],
      'c_inspiration': [
        m('c_inspiration', 'u_noor', 60 * 12, 'Dark UIs that still feel warm, collecting references.'),
      ],
      'c_type_color': [
        m('c_type_color', 'u_lena', 60 * 3,
            'Proposal: neutral surfaces in cool slate, accent stays Mercury violet `#7C6CF2`.'),
      ],
    };
  }

  /// Lines the mock gateway uses for simulated incoming messages.
  static const cannedLines = <String>[
    'Just pushed a fix, can someone take a look?',
    'Sequence numbers look correct on reconnect now.',
    'Signature verification passes on all three test devices ✅',
    'Lunch break, back in 30.',
    'Anyone up for a quick pairing session?',
    'The new **composer** feels great.',
    'CI is green again 🟢',
    'Has anyone tried the `--wasm` build on Safari yet?',
    'MLS epoch rotated cleanly after the member was removed.',
    'I think we should profile scroll perf on the Pixel 6.',
    'Noted, adding it to the roadmap.',
    '> zero data loss across devices\nThat is the whole point of the CRDT layer.',
  ];
}
