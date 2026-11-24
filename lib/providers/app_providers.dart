import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/database/app_database.dart';
import '../data/services/auth_service.dart';
import '../data/services/chat_history_service.dart';
import '../data/services/custom_skills_service.dart';
import '../data/services/device_service.dart';
import '../data/services/document_service.dart';
import '../data/services/knowledge_service.dart';
import '../data/services/proactive_service.dart';
import '../engine/models/chat_models.dart';
import '../engine/models/model_tier.dart';
import '../engine/services/chat_engine.dart';
import '../engine/services/model_manager.dart';
import '../engine/services/skills_engine.dart';
import '../engine/services/vision_engine.dart';
import '../engine/services/voice_service.dart';

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

final voiceServiceProvider = Provider<VoiceService>((ref) => VoiceService());

final chatHistoryServiceProvider = Provider<ChatHistoryService>(
  (ref) => ChatHistoryService(ref.watch(appDatabaseProvider)),
);

final customSkillsServiceProvider = Provider<CustomSkillsService>(
  (ref) => CustomSkillsService(ref.watch(appDatabaseProvider)),
);

final documentServiceProvider = Provider<DocumentService>(
  (ref) => DocumentService(),
);

final knowledgeServiceProvider = Provider<KnowledgeService>(
  (ref) => KnowledgeService(
    ref.watch(appDatabaseProvider),
    ref.watch(documentServiceProvider),
  ),
);

final deviceServiceProvider = Provider<DeviceService>(
  (ref) => DeviceService(),
);

final proactiveServiceProvider = Provider<ProactiveService>(
  (ref) => ProactiveService(ref.watch(appDatabaseProvider)),
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

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();
  static const _keyThemeMode = 'app_theme_mode';

  @override
  ThemeMode build() {
    _loadSaved();
    return ThemeMode.dark;
  }

  Future<void> _loadSaved() async {
    try {
      final raw = await _storage.read(key: _keyThemeMode);
      if (raw == 'dark') {
        state = ThemeMode.dark;
      } else if (raw == 'light') {
        state = ThemeMode.light;
      } else if (raw == 'system') {
        state = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      await _storage.write(key: _keyThemeMode, value: mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
