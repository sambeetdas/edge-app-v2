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
      id: 'smolvlm2-500m',
      displayName: 'SmolVLM2 500M',
      category: ModelCategory.lite,
      description:
          'Smallest model — fast on any phone. Good for quick text chat and basic image questions. Limited on long documents.',
      notes: 'Fast · Basic image Q&A · Short documents only',
      isRecommended: false,
      supportsVision: true,
      maxContextTokens: 1024,
      recommendedContextSize: 1024,
      minRamGb: 4,
      runtimeRamGb: 2,
      promptFormat: PromptFormat.chatML,
      suppressThinkingMode: false,
      modelFileName: 'SmolVLM2-500M-Video-Instruct-Q8_0.gguf',
      downloadUrl:
          'https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/SmolVLM2-500M-Video-Instruct-Q8_0.gguf',
      modelSizeBytes: 436808704,
      mmProjFileName: 'mmproj-SmolVLM2-500M-Video-Instruct-f16.gguf',
      mmProjDownloadUrl:
          'https://huggingface.co/ggml-org/SmolVLM2-500M-Video-Instruct-GGUF/resolve/main/mmproj-SmolVLM2-500M-Video-Instruct-f16.gguf',
      mmProjSizeBytes: 199470624,
    ),
    ModelTier(
      id: 'qwen25-vl-3b',
      displayName: 'Qwen2.5-VL 3B',
      category: ModelCategory.standard,
      description:
          'Best all-rounder for most phones. Excellent at reading screenshots, PDFs, receipts, and charts. Strong text chat.',
      notes: 'Excellent OCR · Screenshots · Documents · Charts',
      isRecommended: true,
      supportsVision: true,
      maxContextTokens: 4096,
      recommendedContextSize: 2048,
      minRamGb: 6,
      runtimeRamGb: 3,
      promptFormat: PromptFormat.chatML,
      suppressThinkingMode: false,
      modelFileName: 'Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf',
      modelSizeBytes: 2072674304,
      mmProjFileName: 'mmproj-Qwen2.5-VL-3B-Instruct-f16.gguf',
      mmProjDownloadUrl:
          'https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/mmproj-Qwen2.5-VL-3B-Instruct-f16.gguf',
      mmProjSizeBytes: 1438646272,
    ),
    ModelTier(
      id: 'gemma3-4b',
      displayName: 'Gemma 3 4B IT',
      category: ModelCategory.standard,
      description:
          'Google\'s 4B model. Strong reasoning and text generation. Supports image analysis with the vision projector.',
      notes: 'Strong reasoning · Good instruction following',
      isRecommended: false,
      supportsVision: true,
      maxContextTokens: 4096,
      recommendedContextSize: 2048,
      minRamGb: 6,
      runtimeRamGb: 4,
      promptFormat: PromptFormat.gemma,
      suppressThinkingMode: false,
      modelFileName: 'gemma-3-4b-it-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf',
      modelSizeBytes: 2621440000,
      mmProjFileName: 'mmproj-model-f16.gguf',
      mmProjDownloadUrl:
          'https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/mmproj-model-f16.gguf',
      mmProjSizeBytes: 851251104,
    ),
    ModelTier(
      id: 'qwen3-4b',
      displayName: 'Qwen3 4B',
      category: ModelCategory.standard,
      description:
          'Alibaba\'s latest 4B reasoning model. Text and document specialist — no image support. Great for chat, summarisation, and Q&A.',
      notes: 'Latest reasoning · Text & document specialist · No images',
      isRecommended: false,
      supportsVision: false,
      maxContextTokens: 8192,
      recommendedContextSize: 2048,
      minRamGb: 6,
      runtimeRamGb: 4,
      promptFormat: PromptFormat.chatML,
      suppressThinkingMode: true,
      modelFileName: 'Qwen3-4B-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf',
      modelSizeBytes: 2684354560,
    ),
    ModelTier(
      id: 'phi4-mm',
      displayName: 'Phi-4 Multimodal',
      category: ModelCategory.pro,
      description:
          'Microsoft\'s multimodal model — best vision quality. Reads handwriting, complex charts, and math. Needs a flagship device.',
      notes: 'Best vision quality · Math · Handwriting · Charts',
      isRecommended: false,
      supportsVision: true,
      maxContextTokens: 4096,
      recommendedContextSize: 2048,
      minRamGb: 8,
      runtimeRamGb: 5,
      promptFormat: PromptFormat.phi3,
      suppressThinkingMode: false,
      modelFileName: 'phi4-mm-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/Swicked86/phi4-mm-gguf/resolve/main/phi4-mm-Q4_K_M.gguf',
      modelSizeBytes: 2516582400,
      mmProjFileName: 'mmproj-phi4-mm-f16.gguf',
      mmProjDownloadUrl:
          'https://huggingface.co/Swicked86/phi4-mm-gguf/resolve/main/mmproj-phi4-mm-f16.gguf',
      mmProjSizeBytes: 864026624,
    ),
    ModelTier(
      id: 'qwen3-14b',
      displayName: 'Qwen3 14B',
      category: ModelCategory.pro,
      description:
          'High-end 14B text model. Exceptional reasoning, coding, and long document analysis. No image support. Flagship devices only.',
      notes: 'Best text reasoning · Coding · Long documents',
      isRecommended: false,
      supportsVision: false,
      maxContextTokens: 8192,
      recommendedContextSize: 4096,
      minRamGb: 12,
      runtimeRamGb: 11,
      promptFormat: PromptFormat.chatML,
      suppressThinkingMode: true,
      modelFileName: 'Qwen3-14B-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/ggml-org/Qwen3-14B-GGUF/resolve/main/Qwen3-14B-Q4_K_M.gguf',
      modelSizeBytes: 9663676416,
    ),
    ModelTier(
      id: 'phi4-14b',
      displayName: 'Phi-4 14B',
      category: ModelCategory.pro,
      description:
          'Microsoft\'s flagship 14B text model. Top-tier reasoning and instruction following. No vision. Requires 12 GB+ RAM.',
      notes: 'Top-tier reasoning · STEM · Coding',
      isRecommended: false,
      supportsVision: false,
      maxContextTokens: 8192,
      recommendedContextSize: 4096,
      minRamGb: 12,
      runtimeRamGb: 10,
      promptFormat: PromptFormat.phi3,
      suppressThinkingMode: false,
      modelFileName: 'phi-4-Q4_K_M.gguf',
      downloadUrl:
          'https://huggingface.co/bartowski/phi-4-GGUF/resolve/main/phi-4-Q4_K_M.gguf',
      modelSizeBytes: 9126805504,
    ),
  ];

  static ModelTier? getById(String id) {
    for (final tier in availableTiers) {
      if (tier.id == id) return tier;
    }
    return null;
  }
}
