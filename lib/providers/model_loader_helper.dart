import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/models/chat_models.dart';
import '../engine/models/model_tier.dart';
import 'app_providers.dart';

Future<ModelTier> ensureModelLoaded(Ref ref) async {
  final engine = ref.read(chatEngineProvider);
  final info = await ref.read(modelManagerProvider).getDownloadedModel();
  if (info == null) {
    throw StateError('No model downloaded. Go to Settings to download a model.');
  }

  final tier = ModelTier.getById(info.tierId);
  if (tier == null) {
    throw StateError('Unknown model tier: ${info.tierId}');
  }

  if (!engine.isLoaded || engine.loadedModelPath != info.modelPath) {
    await engine.loadModel(
      modelPath: info.modelPath,
      promptFormat: tier.promptFormat,
      suppressThinkingMode: tier.suppressThinkingMode,
      options: ModelOptions(contextSize: tier.recommendedContextSize),
    );
  }
  return tier;
}

Future<ModelTier> ensureModelLoadedFromWidget(WidgetRef ref) async {
  final engine = ref.read(chatEngineProvider);
  final info = await ref.read(modelManagerProvider).getDownloadedModel();
  if (info == null) {
    throw StateError('No model downloaded. Go to Settings to download a model.');
  }

  final tier = ModelTier.getById(info.tierId);
  if (tier == null) {
    throw StateError('Unknown model tier: ${info.tierId}');
  }

  if (!engine.isLoaded || engine.loadedModelPath != info.modelPath) {
    await engine.loadModel(
      modelPath: info.modelPath,
      promptFormat: tier.promptFormat,
      suppressThinkingMode: tier.suppressThinkingMode,
      options: ModelOptions(contextSize: tier.recommendedContextSize),
    );
  }
  return tier;
}
