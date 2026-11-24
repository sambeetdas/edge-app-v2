import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

class ExtractedDocument {
  final String fileName;
  final int fileSizeBytes;
  final String fullText;
  final String contextText;
  final int estimatedTokens;
  final int usedTokens;
  final bool wasTruncated;

  const ExtractedDocument({
    required this.fileName,
    required this.fileSizeBytes,
    required this.fullText,
    required this.contextText,
    required this.estimatedTokens,
    required this.usedTokens,
    required this.wasTruncated,
  });

  double get percentUsed {
    if (fullText.isEmpty) return 100.0;
    return ((contextText.length / fullText.length) * 100).clamp(0.0, 100.0);
  }
}

class DocumentService {
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const int charsPerToken = 4;
  static const int reservedTokens = 750;
  static const List<String> supportedExtensions = ['txt', 'md', 'docx', 'pdf'];

  Future<ExtractedDocument> extractAndFit({
    required File file,
    required int modelMaxContextTokens,
  }) async {
    final stat = await file.stat();
    if (stat.size > maxFileSizeBytes) {
      throw Exception('File exceeds the 10 MB limit.');
    }

    final bytes = await file.readAsBytes();
    return extractAndFitBytes(
      fileName: p.basename(file.path),
      bytes: bytes,
      modelMaxContextTokens: modelMaxContextTokens,
    );
  }

  Future<ExtractedDocument> extractAndFitBytes({
    required String fileName,
    required Uint8List bytes,
    required int modelMaxContextTokens,
  }) async {
    if (bytes.length > maxFileSizeBytes) {
      throw Exception('File exceeds the 10 MB limit.');
    }

    final ext = p.extension(fileName).toLowerCase().replaceFirst('.', '');
    if (!supportedExtensions.contains(ext)) {
      throw Exception(
        'Unsupported file type ".$ext". Supported: .txt, .md, .docx, .pdf',
      );
    }

    String text;
    switch (ext) {
      case 'txt':
      case 'md':
        text = utf8.decode(bytes, allowMalformed: true);
        break;
      case 'docx':
        text = _extractDocxBytes(bytes);
        break;
      case 'pdf':
        text = _extractPdfBytes(bytes);
        break;
      default:
        throw Exception('Unsupported file format.');
    }

    text = text.trim();
    if (text.isEmpty) {
      throw Exception(
        'No extractable text found. Scanned or image-only PDFs are not supported.',
      );
    }

    final availableTokens =
        (modelMaxContextTokens - reservedTokens).clamp(256, modelMaxContextTokens);
    final maxChars = availableTokens * charsPerToken;
    final estimatedTokens = (text.length / charsPerToken).ceil();
    final wasTruncated = text.length > maxChars;
    final contextText =
        wasTruncated ? text.substring(0, maxChars) : text;
    final usedTokens = (contextText.length / charsPerToken).ceil();

    return ExtractedDocument(
      fileName: fileName,
      fileSizeBytes: bytes.length,
      fullText: text,
      contextText: contextText,
      estimatedTokens: estimatedTokens,
      usedTokens: usedTokens,
      wasTruncated: wasTruncated,
    );
  }

  /// Extracts full text from [bytes] and splits it into overlapping chunks for offline RAG.
  List<String> extractChunksFromBytes({
    required String fileName,
    required Uint8List bytes,
    int chunkChars = 1100,
    int overlapChars = 150,
  }) {
    if (bytes.length > maxFileSizeBytes) {
      throw Exception('File exceeds the 10 MB limit.');
    }
    final ext = p.extension(fileName).toLowerCase().replaceFirst('.', '');
    if (!supportedExtensions.contains(ext)) {
      throw Exception(
        'Unsupported file type ".$ext". Supported: .txt, .md, .docx, .pdf',
      );
    }

    String text;
    switch (ext) {
      case 'txt':
      case 'md':
        text = utf8.decode(bytes, allowMalformed: true);
        break;
      case 'docx':
        text = _extractDocxBytes(bytes);
        break;
      case 'pdf':
        text = _extractPdfBytes(bytes);
        break;
      default:
        throw Exception('Unsupported file format.');
    }

    text = text.trim();
    if (text.isEmpty) {
      throw Exception(
        'No extractable text found. Scanned or image-only PDFs are not supported.',
      );
    }
    return chunkText(text, chunkChars: chunkChars, overlapChars: overlapChars);
  }

  List<String> chunkText(
    String text, {
    int chunkChars = 1100,
    int overlapChars = 150,
  }) {
    final normalized = text.replaceAll(RegExp(r'\r\n?'), '\n').trim();
    if (normalized.isEmpty) return const [];
    if (normalized.length <= chunkChars) return [normalized];

    final chunks = <String>[];
    var start = 0;
    while (start < normalized.length) {
      var end = (start + chunkChars).clamp(0, normalized.length);
      if (end < normalized.length) {
        final breakAt = normalized.lastIndexOf(RegExp(r'[\n.!? ]'), end);
        if (breakAt > start + (chunkChars ~/ 2)) {
          end = breakAt + 1;
        }
      }
      final slice = normalized.substring(start, end).trim();
      if (slice.isNotEmpty) {
        chunks.add(slice);
      }
      if (end >= normalized.length) break;
      start = (end - overlapChars).clamp(start + 1, normalized.length);
    }
    return chunks;
  }

  String _extractDocxBytes(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docEntry = archive.findFile('word/document.xml');
    if (docEntry == null) {
      throw Exception('Invalid DOCX file: missing word/document.xml.');
    }
    final xmlString = utf8.decode(
      docEntry.content as List<int>,
      allowMalformed: true,
    );
    final doc = XmlDocument.parse(xmlString);
    final sb = StringBuffer();

    for (final para in doc.findAllElements('w:p')) {
      final line = para.findAllElements('w:t').map((e) => e.innerText).join();
      if (line.isNotEmpty) {
        sb.writeln(line);
      }
    }
    return sb.toString();
  }

  String _extractPdfBytes(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      return extractor.extractText();
    } finally {
      document.dispose();
    }
  }
}
