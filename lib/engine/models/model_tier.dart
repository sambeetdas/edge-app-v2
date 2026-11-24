import 'prompt_format.dart';

enum ModelCategory {
  lite('Lite'),
  standard('Standard'),
  pro('Pro');

  final String label;
  const ModelCategory(this.label);
}

class ModelTier {
  final String id;
  final String displayName;
  final ModelCategory category;
  final String description;
  final String notes;
  final bool isRecommended;
  final bool supportsVision;
  final int maxContextTokens;
  final int recommendedContextSize;
  final int minRamGb;
  final int runtimeRamGb;
  final PromptFormat promptFormat;
  final bool suppressThinkingMode;
  final String modelFileName;
  final String downloadUrl;
  final int modelSizeBytes;
  final String? mmProjFileName;
  final String? mmProjDownloadUrl;
  final int mmProjSizeBytes;

  const ModelTier({
    required this.id,
    required this.displayName,
    required this.category,
    required this.description,
    required this.notes,
    required this.isRecommended,
    required this.supportsVision,
    required this.maxContextTokens,
    required this.recommendedContextSize,
    required this.minRamGb,
    required this.runtimeRamGb,
    required this.promptFormat,
    required this.suppressThinkingMode,
    required this.modelFileName,
    required this.downloadUrl,
    required this.modelSizeBytes,
    this.mmProjFileName,
    this.mmProjDownloadUrl,
    this.mmProjSizeBytes = 0,
  });

  bool get supportsDocumentQa => maxContextTokens >= 2048;

  int get totalDownloadBytes => modelSizeBytes + mmProjSizeBytes;

  String get downloadSizeLabel {
    final gb = totalDownloadBytes / (1024 * 1024 * 1024);
    return '~${gb.toStringAsFixed(1)} GB';
  }

  static const List<ModelTier> availableTiers = [
    ModelTier(
      id: 'qwen35-0.8b',
      displayName: 'Qwen3.5 0.8B',
      category: ModelCategory.lite,
      description:
          'Smallest model — fast on any phone. Great for quick text chat, skills, and short prompts.',
      notes: 'Ultra-fast · Text chat · Low RAM',
      isRecommended: false,
      supportsVision: false,
      maxContextTokens: 1024,
      recommendedContextSize: 1024,
      minRamGb: 4,
      runtimeRamGb: 2,
      promptFormat: PromptFormat.chatML,
      suppressThinkingMode: true,
      modelFileName: 'Qwen3.5-0.8B-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf',
      modelSizeBytes: 532517120,
    ),
    ModelTier(
      id: 'qwen35-2b',
      displayName: 'Qwen3.5 2B',
      category: ModelCategory.standard,
      description:
          'Best all-rounder for most phones. Compact download, fast replies, and strong text chat, skills, and document Q&A.',
      notes: 'Recommended · Fast · Documents & Q&A',
      isRecommended: true,
      supportsVision: false,
      maxContextTokens: 4096,
      recommendedContextSize: 2048,
      minRamGb: 4,
      runtimeRamGb: 3,
      promptFormat: PromptFormat.chatML,
      suppressThinkingMode: true,
      modelFileName: 'Qwen3.5-2B-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
      modelSizeBytes: 1280835840,
    ),
    ModelTier(
      id: 'phi4-mini',
      displayName: 'Phi-4-mini Instruct',
      category: ModelCategory.standard,
      description:
          'Microsoft\'s compact 3.8B reasoning model. Strong at logic, STEM, and structured document analysis.',
      notes: 'Strong logic · STEM · Long context',
      isRecommended: false,
      supportsVision: false,
      maxContextTokens: 8192,
      recommendedContextSize: 2048,
      minRamGb: 6,
      runtimeRamGb: 4,
      promptFormat: PromptFormat.phi3,
      suppressThinkingMode: false,
      modelFileName: 'Phi-4-mini-instruct-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/unsloth/Phi-4-mini-instruct-GGUF/resolve/main/Phi-4-mini-instruct-Q4_K_M.gguf',
      modelSizeBytes: 2491874272,
    ),
    ModelTier(
      id: 'gemma3n-e2b',
      displayName: 'Gemma 3n E2B IT',
      category: ModelCategory.standard,
      description:
          'Google\'s mobile-first Gemma 3n model. Optimized for lower RAM spikes and responsive on-device chat.',
      notes: 'Mobile-optimized · Balanced speed & quality',
      isRecommended: false,
      supportsVision: false,
      maxContextTokens: 4096,
      recommendedContextSize: 2048,
      minRamGb: 6,
      runtimeRamGb: 4,
      promptFormat: PromptFormat.gemma,
      suppressThinkingMode: false,
      modelFileName: 'gemma-3n-E2B-it-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/unsloth/gemma-3n-E2B-it-GGUF/resolve/main/gemma-3n-E2B-it-Q4_K_M.gguf',
      modelSizeBytes: 3026881888,
    ),
    ModelTier(
      id: 'qwen35-4b',
      displayName: 'Qwen3.5 4B',
      category: ModelCategory.standard,
      description:
          'Alibaba\'s 4B text & reasoning specialist. Great for deeper chat, summarization, coding, and document Q&A.',
      notes: 'Strong reasoning · Coding · Documents',
      isRecommended: false,
      supportsVision: false,
      maxContextTokens: 8192,
      recommendedContextSize: 2048,
      minRamGb: 6,
      runtimeRamGb: 4,
      promptFormat: PromptFormat.chatML,
      suppressThinkingMode: true,
      modelFileName: 'Qwen3.5-4B-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/ggml-org/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf',
      modelSizeBytes: 3032091584,
    ),
    ModelTier(
      id: 'gemma3n-e4b',
      displayName: 'Gemma 3n E4B IT',
      category: ModelCategory.pro,
      description:
          'Higher-capacity mobile Gemma 3n model. Richer writing and instruction following for 8 GB+ devices.',
      notes: 'Pro quality · Writing · Long context',
      isRecommended: false,
      supportsVision: false,
      maxContextTokens: 8192,
      recommendedContextSize: 4096,
      minRamGb: 8,
      runtimeRamGb: 6,
      promptFormat: PromptFormat.gemma,
      suppressThinkingMode: false,
      modelFileName: 'gemma-3n-E4B-it-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/unsloth/gemma-3n-E4B-it-GGUF/resolve/main/gemma-3n-E4B-it-Q4_K_M.gguf',
      modelSizeBytes: 4539054208,
    ),
    ModelTier(
      id: 'qwen35-9b',
      displayName: 'Qwen3.5 9B',
      category: ModelCategory.pro,
      description:
          'Flagship 9B text model. Exceptional reasoning, coding, and long document analysis for 10 GB+ RAM devices.',
      notes: 'Flagship reasoning · Coding · Long documents',
      isRecommended: false,
      supportsVision: false,
      maxContextTokens: 8192,
      recommendedContextSize: 4096,
      minRamGb: 10,
      runtimeRamGb: 8,
      promptFormat: PromptFormat.chatML,
      suppressThinkingMode: true,
      modelFileName: 'Qwen3.5-9B-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_K_M.gguf',
      modelSizeBytes: 5680522464,
    ),
  ];

  static ModelTier? getById(String id) {
    for (final tier in availableTiers) {
      if (tier.id == id) return tier;
    }
    return null;
  }
}
