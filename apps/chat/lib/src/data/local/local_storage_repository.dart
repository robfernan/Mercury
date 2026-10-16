import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';

import '../models.dart';
import '../seed_data.dart';
import '../../theme/theme_state.dart';
import 'mercury_database.dart';

/// Repository that translates domain models to/from the local Drift database.
class LocalStorageRepository {
  LocalStorageRepository(this.db);

  final MercuryDatabase db;

  // --- Theme Persistence -----------------------------------------------------

  Future<void> saveTheme(MercuryThemeState state) async {
    final payload = {
      'accentColor': state.accentColor.toARGB32(),
      'surfaceColor': state.surfaceColor.toARGB32(),
      'sidebarColor': state.sidebarColor.toARGB32(),
      'railColor': state.railColor.toARGB32(),
      'bubbleStyle': state.bubbleStyle.name,
      'typographyScale': state.typographyScale,
      'glassmorphismBlur': state.glassmorphismBlur,
      'wallpaper': {
        'imagePath': state.wallpaper.imagePath,
        'blur': state.wallpaper.blur,
        'brightness': state.wallpaper.brightness,
        'opacity': state.wallpaper.opacity,
      },
    };

    await db.into(db.localSettings).insertOnConflictUpdate(
          LocalSettingsCompanion.insert(
            key: 'mercury_theme',
            value: jsonEncode(payload),
          ),
        );
  }

  Future<MercuryThemeState?> loadTheme() async {
    final query = db.select(db.localSettings)..where((t) => t.key.equals('mercury_theme'));
    final row = await query.getSingleOrNull();
    if (row == null) return null;

    try {
      final json = jsonDecode(row.value) as Map<String, dynamic>;
      final wpJson = json['wallpaper'] as Map<String, dynamic>?;

      return MercuryThemeState(
        accentColor: Color(json['accentColor'] as int? ?? 0xFF7C6CF2),
        surfaceColor: Color(json['surfaceColor'] as int? ?? 0xFF1B1E26),
        sidebarColor: Color(json['sidebarColor'] as int? ?? 0xFF15171E),
        railColor: Color(json['railColor'] as int? ?? 0xFF0E1015),
        bubbleStyle: MessageBubbleStyle.values.byName(
          json['bubbleStyle'] as String? ?? 'modern',
        ),
        typographyScale: (json['typographyScale'] as num?)?.toDouble() ?? 1.0,
        glassmorphismBlur: (json['glassmorphismBlur'] as num?)?.toDouble() ?? 12.0,
        wallpaper: wpJson == null
            ? const WallpaperConfig()
            : WallpaperConfig(
                imagePath: wpJson['imagePath'] as String?,
                blur: (wpJson['blur'] as num?)?.toDouble() ?? 0.0,
                brightness: (wpJson['brightness'] as num?)?.toDouble() ?? 1.0,
                opacity: (wpJson['opacity'] as num?)?.toDouble() ?? 1.0,
              ),
      );
    } catch (_) {
      return null;
    }
  }

  // --- User Profile Persistence ----------------------------------------------

  Future<void> saveProfile(ChatUser user) async {
    await db.into(db.localProfiles).insertOnConflictUpdate(
          LocalProfilesCompanion.insert(
            id: user.id,
            displayName: user.displayName,
            handle: user.handle,
            avatarColorValue: user.avatarColor.toARGB32(),
            statusText: Value(user.statusText),
            role: Value(user.role),
          ),
        );
  }

  Future<Map<String, ChatUser>> loadProfiles() async {
    final rows = await db.select(db.localProfiles).get();
    return {
      for (final r in rows)
        r.id: ChatUser(
          id: r.id,
          displayName: r.displayName,
          handle: r.handle,
          avatarColor: Color(r.avatarColorValue),
          statusText: r.statusText,
          role: r.role,
        ),
    };
  }

  // --- Chat Messages Persistence ---------------------------------------------

  Future<void> saveMessage(ChatMessage message) async {
    await db.into(db.localMessages).insertOnConflictUpdate(
          LocalMessagesCompanion.insert(
            id: message.id,
            channelId: message.channelId,
            authorId: message.authorId,
            body: message.body,
            sentAt: message.sentAt,
            seq: Value(message.seq),
            delivery: message.delivery.name,
            verified: Value(message.verified),
            replyToId: Value(message.replyToId),
            attachmentJson: message.attachment == null
                ? const Value.absent()
                : Value(jsonEncode({
                    'name': message.attachment!.name,
                    'sizeBytes': message.attachment!.sizeBytes,
                    'kind': message.attachment!.kind.name,
                  })),
            reactionsJson: message.reactions.isEmpty
                ? const Value.absent()
                : Value(jsonEncode(
                    message.reactions.map((k, v) => MapEntry(k, v.toList())),
                  )),
          ),
        );
  }

  Future<void> deleteMessage(String messageId) async {
    final query = db.delete(db.localMessages)..where((t) => t.id.equals(messageId));
    await query.go();
  }

  Future<List<ChatMessage>> loadMessagesForChannel(String channelId) async {
    final query = db.select(db.localMessages)
      ..where((t) => t.channelId.equals(channelId))
      ..orderBy([(t) => OrderingTerm.asc(t.sentAt)]);
    final rows = await query.get();

    return rows.map((r) {
      Attachment? attachment;
      if (r.attachmentJson != null) {
        final aJson = jsonDecode(r.attachmentJson!) as Map<String, dynamic>;
        attachment = Attachment(
          name: aJson['name'] as String,
          sizeBytes: aJson['sizeBytes'] as int,
          kind: AttachmentKind.values.byName(aJson['kind'] as String),
        );
      }

      var reactions = <String, Set<String>>{};
      if (r.reactionsJson != null) {
        final rJson = jsonDecode(r.reactionsJson!) as Map<String, dynamic>;
        reactions = rJson.map(
          (k, v) => MapEntry(k, (v as List<dynamic>).map((e) => e.toString()).toSet()),
        );
      }

      return ChatMessage(
        id: r.id,
        channelId: r.channelId,
        authorId: r.authorId,
        body: r.body,
        sentAt: r.sentAt,
        seq: r.seq,
        delivery: DeliveryState.values.byName(r.delivery),
        verified: r.verified,
        replyToId: r.replyToId,
        attachment: attachment,
        reactions: reactions,
      );
    }).toList();
  }

  /// Populates the database with initial seed data on first run
  Future<void> seedIfEmpty() async {
    final count = await db.select(db.localMessages).get();
    if (count.isEmpty) {
      final now = DateTime.now();
      final seed = SeedData.messages(now);
      for (final messages in seed.values) {
        for (final m in messages) {
          await saveMessage(m);
        }
      }
      for (final u in SeedData.users) {
        await saveProfile(u);
      }
    }
  }

  // --- FTS5 Search -----------------------------------------------------------

  Future<List<ChatMessage>> search(String query, {String? channelId}) async {
    final messageIds = await db.searchMessages(query, channelId: channelId);
    if (messageIds.isEmpty) return [];

    final rows = await (db.select(db.localMessages)
          ..where((t) => t.id.isIn(messageIds)))
        .get();

    final map = {for (final r in rows) r.id: r};
    // Preserve FTS5 rank order
    return messageIds.map((id) => map[id]).whereType<LocalMessage>().map((r) {
      return ChatMessage(
        id: r.id,
        channelId: r.channelId,
        authorId: r.authorId,
        body: r.body,
        sentAt: r.sentAt,
        seq: r.seq,
        delivery: DeliveryState.values.byName(r.delivery),
        verified: r.verified,
        replyToId: r.replyToId,
      );
    }).toList();
  }
}
