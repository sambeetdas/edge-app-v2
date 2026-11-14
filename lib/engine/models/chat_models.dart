enum ChatRole { system, user, assistant }

class ChatMessage {
  final ChatRole role;
  final String content;

  const ChatMessage({required this.role, required this.content});
}

class ModelOptions {
  final int contextSize;
  final int batchSize;
  final int gpuLayers;
  final int threadCount;
  final double temperature;
  final double topP;
  final int maxTokens;
  final double repeatPenalty;

  const ModelOptions({
    this.contextSize = 512,
    this.batchSize = 128,
    this.gpuLayers = 0,
    this.threadCount = 4,
    this.temperature = 0.7,
    this.topP = 0.9,
    this.maxTokens = 512,
    this.repeatPenalty = 1.1,
  });

  static const ModelOptions defaults = ModelOptions();

  ModelOptions copyWith({
    int? contextSize,
    int? batchSize,
    int? gpuLayers,
    int? threadCount,
    double? temperature,
    double? topP,
    int? maxTokens,
    double? repeatPenalty,
  }) {
    return ModelOptions(
      contextSize: contextSize ?? this.contextSize,
      batchSize: batchSize ?? this.batchSize,
      gpuLayers: gpuLayers ?? this.gpuLayers,
      threadCount: threadCount ?? this.threadCount,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
    );
  }
}

class ChatRequest {
  final String? systemPrompt;
  final List<ChatMessage> messages;
  final double? temperature;
  final double? topP;
  final int? maxTokens;
  final double? repeatPenalty;

  const ChatRequest({
    this.systemPrompt,
    required this.messages,
    this.temperature,
    this.topP,
    this.maxTokens,
    this.repeatPenalty,
  });
}

enum DownloadStatus {
  idle,
  downloading,
  paused,
  completed,
  error,
}

class DownloadProgress {
  final DownloadStatus status;
  final int bytesReceived;
  final int totalBytes;
  final String currentFileLabel;
  final String? errorMessage;

  const DownloadProgress({
    required this.status,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.currentFileLabel = '',
    this.errorMessage,
  });

  double get fraction =>
      totalBytes > 0 ? (bytesReceived / totalBytes).clamp(0.0, 1.0) : 0.0;
}

class DownloadedModelInfo {
  final String tierId;
  final String modelPath;
  final String? mmProjPath;
  final DateTime downloadDate;
  final int totalBytes;

  const DownloadedModelInfo({
    required this.tierId,
    required this.modelPath,
    this.mmProjPath,
    required this.downloadDate,
    required this.totalBytes,
  });
}

class SkillDefinition {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final String systemPrompt;
  final String inputPlaceholder;
  final bool isBuiltIn;

  const SkillDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.systemPrompt,
    required this.inputPlaceholder,
    this.isBuiltIn = true,
  });
}
