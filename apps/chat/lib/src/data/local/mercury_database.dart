import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'mercury_database.g.dart';

/// Messages table storing encrypted or local-plaintext chat history with sequence numbers.
class LocalMessages extends Table {
  TextColumn get id => text()();
  TextColumn get channelId => text()();
  TextColumn get authorId => text()();
  TextColumn get body => text()();
  DateTimeColumn get sentAt => dateTime()();
  IntColumn get seq => integer().nullable()();
  TextColumn get delivery => text()(); // 'pending', 'sent', 'failed'
  BoolColumn get verified => boolean().withDefault(const Constant(true))();
  TextColumn get replyToId => text().nullable()();
  TextColumn get attachmentJson => text().nullable()();
  TextColumn get reactionsJson => text().nullable()(); // JSON map of emoji -> List<userId>

  @override
  Set<Column> get primaryKey => {id};
}

/// App settings and theme persistence (accent color, wallpaper path, blur, opacity).
class LocalSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// User profile cache (display name, bio/status text, avatar color).
class LocalProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get handle => text()();
  IntColumn get avatarColorValue => integer()();
  TextColumn get statusText => text().nullable()();
  TextColumn get role => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalMessages, LocalSettings, LocalProfiles])
class MercuryDatabase extends _$MercuryDatabase {
  MercuryDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'mercury_vault',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
      ),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Enable FTS5 virtual table for lightning-fast zero-knowledge search
      await customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
          message_id UNINDEXED,
          channel_id UNINDEXED,
          body,
          tokenize = 'porter unicode61'
        );
      ''');

      // Create sync triggers to keep FTS5 updated automatically
      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS local_messages_ai AFTER INSERT ON local_messages BEGIN
          INSERT INTO messages_fts(message_id, channel_id, body)
          VALUES (new.id, new.channel_id, new.body);
        END;
      ''');

      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS local_messages_ad AFTER DELETE ON local_messages BEGIN
          DELETE FROM messages_fts WHERE message_id = old.id;
        END;
      ''');

      await customStatement('''
        CREATE TRIGGER IF NOT EXISTS local_messages_au AFTER UPDATE ON local_messages BEGIN
          DELETE FROM messages_fts WHERE message_id = old.id;
          INSERT INTO messages_fts(message_id, channel_id, body)
          VALUES (new.id, new.channel_id, new.body);
        END;
      ''');
    },
  );

  /// Full-text search using SQLite FTS5 extension. Returns matching message IDs.
  Future<List<String>> searchMessages(String query, {String? channelId}) async {
    final sanitized = query
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .map((t) => '$t*')
        .join(' ');

    if (sanitized.isEmpty) return [];

    final rows = channelId != null
        ? await customSelect(
            'SELECT message_id FROM messages_fts WHERE channel_id = ? AND messages_fts MATCH ? ORDER BY rank',
            variables: [Variable.withString(channelId), Variable.withString(sanitized)],
          ).get()
        : await customSelect(
            'SELECT message_id FROM messages_fts WHERE messages_fts MATCH ? ORDER BY rank',
            variables: [Variable.withString(sanitized)],
          ).get();

    return rows.map((r) => r.read<String>('message_id')).toList();
  }
}
