import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'document_service.dart';

class KnowledgeDocumentEntity {
  final String id;
  final String fileName;
  final int fileSizeBytes;
  final int chunkCount;
  final DateTime createdAt;

  const KnowledgeDocumentEntity({
    required this.id,
    required this.fileName,
    required this.fileSizeBytes,
    required this.chunkCount,
    required this.createdAt,
  });

  factory KnowledgeDocumentEntity.fromMap(Map<String, Object?> map) {
    return KnowledgeDocumentEntity(
      id: map['Id'] as String,
      fileName: map['FileName'] as String,
      fileSizeBytes: map['FileSizeBytes'] as int,
      chunkCount: map['ChunkCount'] as int,
      createdAt: DateTime.parse(map['CreatedAt'] as String),
    );
  }
}

class KnowledgeChunkMatch {
  final String documentId;
  final String fileName;
  final int chunkIndex;
  final String content;
  final double score;

  const KnowledgeChunkMatch({
    required this.documentId,
    required this.fileName,
    required this.chunkIndex,
    required this.content,
    required this.score,
  });

  String get citationLabel => '$fileName §${chunkIndex + 1}';
}

/// 100% offline SQLite-backed document chunking and hybrid keyword/BM25 retrieval.
class KnowledgeService {
  final AppDatabase _db;
  final DocumentService _docService;
  static const _uuid = Uuid();

  static const Set<String> _stopWords = {
    'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'what', 'which', 'who', 'whom', 'this', 'that', 'these', 'those', 'it',
    'its', 'from', 'as', 'about', 'into', 'how', 'when', 'where', 'why',
  };

  KnowledgeService(this._db, this._docService);

  Future<List<KnowledgeDocumentEntity>> getDocuments() async {
    final db = await _db.database;
    final rows = await db.query(
      'KnowledgeDocumentEntity',
      orderBy: 'CreatedAt DESC',
    );
    return rows.map(KnowledgeDocumentEntity.fromMap).toList();
  }

  Future<KnowledgeDocumentEntity> addDocument({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final chunks = _docService.extractChunksFromBytes(
      fileName: fileName,
      bytes: bytes,
    );
    final db = await _db.database;
    final docId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await db.transaction((txn) async {
      await txn.insert('KnowledgeDocumentEntity', {
        'Id': docId,
        'FileName': fileName,
        'FileSizeBytes': bytes.length,
        'ChunkCount': chunks.length,
        'CreatedAt': now.toIso8601String(),
      });
      for (var i = 0; i < chunks.length; i++) {
        await txn.insert('KnowledgeChunkEntity', {
          'Id': _uuid.v4(),
          'DocumentId': docId,
          'FileName': fileName,
          'ChunkIndex': i,
          'Content': chunks[i],
        });
      }
    });

    return KnowledgeDocumentEntity(
      id: docId,
      fileName: fileName,
      fileSizeBytes: bytes.length,
      chunkCount: chunks.length,
      createdAt: now,
    );
  }

  Future<void> deleteDocument(String documentId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'KnowledgeChunkEntity',
        where: 'DocumentId = ?',
        whereArgs: [documentId],
      );
      await txn.delete(
        'KnowledgeDocumentEntity',
        where: 'Id = ?',
        whereArgs: [documentId],
      );
    });
  }

  Future<List<KnowledgeChunkMatch>> searchChunks(
    String query, {
    int topK = 4,
  }) async {
    final db = await _db.database;
    final rows = await db.query('KnowledgeChunkEntity');
    if (rows.isEmpty) return const [];

    final queryTokens = _tokenize(query);
    final lowerQuery = query.trim().toLowerCase();

    final scored = <KnowledgeChunkMatch>[];
    for (final row in rows) {
      final content = row['Content'] as String;
      final lowerContent = content.toLowerCase();

      double score = 0;
      if (lowerQuery.length >= 4 && lowerContent.contains(lowerQuery)) {
        score += 5.0;
      }

      if (queryTokens.isNotEmpty) {
        final contentTokens = _tokenize(content);
        final freq = <String, int>{};
        for (final t in contentTokens) {
          freq[t] = (freq[t] ?? 0) + 1;
        }
        var matchedTerms = 0;
        for (final qt in queryTokens) {
          final count = freq[qt] ?? 0;
          if (count > 0) {
            matchedTerms++;
            score += 1.0 + (count > 3 ? 3 : count) * 0.35;
          }
        }
        score += (matchedTerms / queryTokens.length) * 2.0;
      }

      scored.add(
        KnowledgeChunkMatch(
          documentId: row['DocumentId'] as String,
          fileName: row['FileName'] as String,
          chunkIndex: row['ChunkIndex'] as int,
          content: content,
          score: score,
        ),
      );
    }

    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return a.chunkIndex.compareTo(b.chunkIndex);
    });

    final nonZero = scored.where((m) => m.score > 0).take(topK).toList();
    if (nonZero.isNotEmpty) return nonZero;
    return scored.take(topK).toList();
  }

  List<String> _tokenize(String text) {
    return RegExp(r'[a-z0-9]{2,}')
        .allMatches(text.toLowerCase())
        .map((m) => m.group(0)!)
        .where((w) => !_stopWords.contains(w))
        .toList();
  }
}
