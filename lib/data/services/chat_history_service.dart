import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class ChatSessionEntity {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String summary;
  final String? summarizedUpToMessageId;

  const ChatSessionEntity({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.summary = '',
    this.summarizedUpToMessageId,
  });

  factory ChatSessionEntity.fromMap(Map<String, Object?> map) {
    return ChatSessionEntity(
      id: map['Id'] as String,
      title: map['Title'] as String,
      createdAt: DateTime.parse(map['CreatedAt'] as String),
      updatedAt: DateTime.parse(map['UpdatedAt'] as String),
      summary: (map['Summary'] as String?) ?? '',
      summarizedUpToMessageId: map['SummarizedUpToMessageId'] as String?,
    );
  }
}

class ChatMessageEntity {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final DateTime timestamp;

  const ChatMessageEntity({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessageEntity.fromMap(Map<String, Object?> map) {
    return ChatMessageEntity(
      id: map['Id'] as String,
      sessionId: map['SessionId'] as String,
      role: map['Role'] as String,
      content: map['Content'] as String,
      timestamp: DateTime.parse(map['Timestamp'] as String),
    );
  }
}

class ChatHistoryService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  ChatHistoryService(this._db);

  Future<List<ChatSessionEntity>> getSessions() async {
    final db = await _db.database;
    final rows = await db.query(
      'ChatSessionEntity',
      orderBy: 'UpdatedAt DESC',
    );
    return rows.map(ChatSessionEntity.fromMap).toList();
  }

  Future<ChatSessionEntity?> getSession(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'ChatSessionEntity',
      where: 'Id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ChatSessionEntity.fromMap(rows.first);
  }

  Future<ChatSessionEntity> createSession({String title = 'New Chat'}) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await db.insert('ChatSessionEntity', {
      'Id': id,
      'Title': title,
      'CreatedAt': now.toIso8601String(),
      'UpdatedAt': now.toIso8601String(),
      'Summary': '',
      'SummarizedUpToMessageId': null,
    });
    return ChatSessionEntity(
      id: id,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateSessionTitle(String sessionId, String title) async {
    final db = await _db.database;
    await db.update(
      'ChatSessionEntity',
      {
        'Title': title,
        'UpdatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'Id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> updateSessionSummary({
    required String sessionId,
    required String summary,
    required String summarizedUpToMessageId,
  }) async {
    final db = await _db.database;
    await db.update(
      'ChatSessionEntity',
      {
        'Summary': summary,
        'SummarizedUpToMessageId': summarizedUpToMessageId,
      },
      where: 'Id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await _db.database;
    await db.delete(
      'ChatMessageEntity',
      where: 'SessionId = ?',
      whereArgs: [sessionId],
    );
    await db.delete(
      'ChatSessionEntity',
      where: 'Id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<ChatMessageEntity>> getMessages(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'ChatMessageEntity',
      where: 'SessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'Timestamp ASC',
    );
    return rows.map(ChatMessageEntity.fromMap).toList();
  }

  Future<ChatMessageEntity> addMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await db.insert('ChatMessageEntity', {
      'Id': id,
      'SessionId': sessionId,
      'Role': role,
      'Content': content,
      'Timestamp': now.toIso8601String(),
    });
    await db.update(
      'ChatSessionEntity',
      {'UpdatedAt': now.toIso8601String()},
      where: 'Id = ?',
      whereArgs: [sessionId],
    );
    return ChatMessageEntity(
      id: id,
      sessionId: sessionId,
      role: role,
      content: content,
      timestamp: now,
    );
  }
}
