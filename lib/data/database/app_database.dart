import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'edge_chat.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ChatSessionEntity (
            Id TEXT PRIMARY KEY,
            Title TEXT NOT NULL,
            CreatedAt TEXT NOT NULL,
            UpdatedAt TEXT NOT NULL,
            Summary TEXT NOT NULL DEFAULT '',
            SummarizedUpToMessageId TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE ChatMessageEntity (
            Id TEXT PRIMARY KEY,
            SessionId TEXT NOT NULL,
            Role TEXT NOT NULL,
            Content TEXT NOT NULL,
            Timestamp TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_chat_msg_session ON ChatMessageEntity (SessionId)',
        );

        await db.execute('''
          CREATE TABLE CustomSkillEntity (
            Id TEXT PRIMARY KEY,
            Name TEXT NOT NULL,
            Description TEXT NOT NULL,
            Icon TEXT NOT NULL,
            SystemPrompt TEXT NOT NULL,
            InputPlaceholder TEXT NOT NULL,
            Category TEXT NOT NULL,
            CreatedAt TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE CustomGameEntity (
            Id TEXT PRIMARY KEY,
            Name TEXT NOT NULL,
            Description TEXT NOT NULL,
            Icon TEXT NOT NULL,
            Category TEXT NOT NULL,
            SystemPrompt TEXT NOT NULL,
            StarterMessage TEXT NOT NULL,
            HowToPlay TEXT NOT NULL,
            CreatedAt TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }
}
