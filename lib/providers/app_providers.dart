import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/services/auth_service.dart';
import '../data/services/chat_history_service.dart';
import '../data/services/custom_skills_service.dart';
import '../data/services/device_service.dart';
import '../data/services/document_service.dart';
import '../data/services/games_service.dart';
import '../engine/models/chat_models.dart';
import '../engine/models/model_tier.dart';
import '../engine/services/chat_engine.dart';
import '../engine/services/model_manager.dart';
import '../engine/services/skills_engine.dart';
import '../engine/services/vision_engine.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final modelManagerProvider = Provider<ModelManager>((ref) => ModelManager());
final chatEngineProvider = Provider<ChatEngine>((ref) => ChatEngine());

final skillsEngineProvider = Provider<SkillsEngine>(
  (ref) => SkillsEngine(ref.watch(chatEngineProvider)),
);

final visionEngineProvider = Provider<VisionEngine>(
  (ref) => VisionEngine(ref.watch(chatEngineProvider)),
);

final chatHistoryServiceProvider = Provider<ChatHistoryService>(
  (ref) => ChatHistoryService(ref.watch(appDatabaseProvider)),
);

final customSkillsServiceProvider = Provider<CustomSkillsService>(
  (ref) => CustomSkillsService(ref.watch(appDatabaseProvider)),
);

final gamesServiceProvider = Provider<GamesService>(
  (ref) => GamesService(ref.watch(appDatabaseProvider)),
);

final documentServiceProvider = Provider<DocumentService>(
  (ref) => DocumentService(),
);

final deviceServiceProvider = Provider<DeviceService>(
  (ref) => DeviceService(),
);

class DownloadedModelNotifier extends AsyncNotifier<DownloadedModelInfo?> {
  @override
  Future<DownloadedModelInfo?> build() async {
    return ref.read(modelManagerProvider).getDownloadedModel();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(modelManagerProvider).getDownloadedModel(),
    );
  }

  Future<void> deleteModel() async {
    await ref.read(chatEngineProvider).unloadModel();
    await ref.read(modelManagerProvider).deleteDownloadedModel();
    state = const AsyncData(null);
  }
}

final downloadedModelProvider =
    AsyncNotifierProvider<DownloadedModelNotifier, DownloadedModelInfo?>(
  DownloadedModelNotifier.new,
);

final activeModelTierProvider = Provider<ModelTier?>((ref) {
  final info = ref.watch(downloadedModelProvider).value;
  if (info == null) return null;
  return ModelTier.getById(info.tierId);
});
