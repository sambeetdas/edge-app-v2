import 'dart:io';

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

    final ext = p.extension(file.path).toLowerCase().replaceFirst('.', '');
    if (!supportedExtensions.contains(ext)) {
      throw Exception(
        'Unsupported file type ".$ext". Supported: .txt, .md, .docx, .pdf',
      );
    }

    String text;
    switch (ext) {
      case 'txt':
      case 'md':
        text = await file.readAsString();
        break;
      case 'docx':
        text = await _extractDocx(file);
        break;
      case 'pdf':
        text = await _extractPdf(file);
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
      fileName: p.basename(file.path),
      fileSizeBytes: stat.size,
      fullText: text,
      contextText: contextText,
      estimatedTokens: estimatedTokens,
      usedTokens: usedTokens,
      wasTruncated: wasTruncated,
    );
  }

  Future<String> _extractDocx(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docEntry = archive.findFile('word/document.xml');
    if (docEntry == null) {
      throw Exception('Invalid DOCX file: missing word/document.xml.');
    }
    final xmlString = String.fromCharCodes(docEntry.content as List<int>);
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

  Future<String> _extractPdf(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      return extractor.extractText();
    } finally {
      document.dispose();
    }
  }
}
