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
      version: 4,
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

        await _createKnowledgeTables(db);
        await _createProactiveTables(db);
        await _createAgentTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createKnowledgeTables(db);
        }
        if (oldVersion < 3) {
          await _createProactiveTables(db);
        }
        if (oldVersion < 4) {
          await _createAgentTables(db);
        }
      },
      onOpen: (db) async {
        await _createKnowledgeTables(db);
        await _createProactiveTables(db);
        await _createAgentTables(db);
      },
    );
    return _db!;
  }

  Future<void> _createProactiveTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ProactiveReminderEntity (
        Id TEXT PRIMARY KEY,
        Title TEXT NOT NULL,
        TriggerAt TEXT NOT NULL,
        IsCompleted INTEGER NOT NULL DEFAULT 0,
        CreatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createKnowledgeTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS KnowledgeDocumentEntity (
        Id TEXT PRIMARY KEY,
        FileName TEXT NOT NULL,
        FileSizeBytes INTEGER NOT NULL,
        ChunkCount INTEGER NOT NULL,
        CreatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS KnowledgeChunkEntity (
        Id TEXT PRIMARY KEY,
        DocumentId TEXT NOT NULL,
        FileName TEXT NOT NULL,
        ChunkIndex INTEGER NOT NULL,
        Content TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_knowledge_chunk_doc ON KnowledgeChunkEntity (DocumentId)',
    );
  }

  Future<void> _createAgentTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS CustomAgentEntity (
        Id TEXT PRIMARY KEY,
        Name TEXT NOT NULL,
        Description TEXT NOT NULL,
        Icon TEXT NOT NULL,
        Category TEXT NOT NULL,
        SystemPrompt TEXT NOT NULL,
        InputPlaceholder TEXT NOT NULL,
        Tools TEXT NOT NULL,
        NextAgentId TEXT,
        CreatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS AgentRunEntity (
        Id TEXT PRIMARY KEY,
        Title TEXT NOT NULL,
        CreatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS AgentMessageEntity (
        Id TEXT PRIMARY KEY,
        RunId TEXT NOT NULL,
        FromAgent TEXT NOT NULL,
        ToAgent TEXT NOT NULL,
        Content TEXT NOT NULL,
        ActionType TEXT,
        ActionPayload TEXT,
        CreatedAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_agent_msg_run ON AgentMessageEntity (RunId)',
    );
  }
}
