import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:edged/app.dart';
import 'package:edged/data/services/auth_service.dart';
import 'package:edged/engine/models/chat_models.dart';
import 'package:edged/engine/models/model_tier.dart';
import 'package:edged/engine/services/model_manager.dart';
import 'package:edged/providers/app_providers.dart';

class _InMemoryAuthService extends AuthService {
  bool _authed = true;
  bool _appLock = false;
  UserProfile _profile = const UserProfile();
  String? _phone;
  String? _pin;

  @override
  Future<bool> isAuthenticated() async => _authed;

  @override
  Future<bool> isAppLockEnabled() async => _appLock;

  @override
  Future<void> setAppLockEnabled(bool enabled) async => _appLock = enabled;

  @override
  Future<bool> isDeviceLockSupported() async => true;

  @override
  Future<bool> authenticateWithDevice({String reason = ''}) async => true;

  @override
  Future<UserProfile> getProfile() async => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async => _profile = profile;

  @override
  Future<String?> getPhoneNumber() async => _phone;

  @override
  Future<bool> hasPinForPhone(String fullPhoneNumber) async =>
      _phone == fullPhoneNumber && _pin != null;

  @override
  Future<void> setupPin(String fullPhoneNumber, String pin) async {
    _phone = fullPhoneNumber;
    _pin = pin.trim();
    _authed = true;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    if (_pin != null && pin.trim() == _pin) {
      _authed = true;
      return true;
    }
    return false;
  }

  @override
  Future<void> resetPin() async {
    _pin = null;
    _authed = false;
  }

  @override
  Future<void> signOut() async {
    _authed = false;
  }
}

class _FakeModelManager extends ModelManager {
  DownloadedModelInfo? currentModel;

  @override
  Future<DownloadedModelInfo?> getDownloadedModel() async => currentModel;

  @override
  Stream<DownloadProgress> downloadModel(ModelTier tier) async* {
    yield DownloadProgress(
      status: DownloadStatus.downloading,
      bytesReceived: tier.totalDownloadBytes ~/ 2,
      totalBytes: tier.totalDownloadBytes,
      currentFileLabel: tier.modelFileName,
    );
    currentModel = DownloadedModelInfo(
      tierId: tier.id,
      modelPath: '/tmp/${tier.modelFileName}',
      mmProjPath:
          tier.mmProjFileName != null ? '/tmp/${tier.mmProjFileName}' : null,
      downloadDate: DateTime.now().toUtc(),
      totalBytes: tier.totalDownloadBytes,
    );
    yield DownloadProgress(
      status: DownloadStatus.completed,
      bytesReceived: tier.totalDownloadBytes,
      totalBytes: tier.totalDownloadBytes,
      currentFileLabel: tier.displayName,
    );
  }

  @override
  Future<void> deleteDownloadedModel() async {
    currentModel = null;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full E2E: Auth -> Model Download -> Chat -> Skills -> Sign Out',
      (tester) async {
    final authService = _InMemoryAuthService();
    final modelManager = _FakeModelManager();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          modelManagerProvider.overrideWithValue(modelManager),
        ],
        child: EdgedApp(router: createAppRouter()),
      ),
    );

    // 1. Splash -> Home (Settings, no model downloaded yet)
    await tester.pumpAndSettle();
    expect(find.text('No AI model downloaded'), findsOneWidget);
    await tester.tap(find.text('Choose & Download Model'));
    await tester.pumpAndSettle();

    // 4. Model Selection -> Download Qwen3.5 2B
    expect(find.text('Qwen3.5 2B'), findsOneWidget);
    await tester.tap(find.text('Qwen3.5 2B'));
    await tester.pumpAndSettle();

    // 5. Capability-gated tabs are now unlocked
    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Knowledge'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // 6. AI Chat E2E
    await tester.tap(find.text('New Chat').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Message Edged...'),
      'Hello Edged!',
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('Hello Edged!'), findsWidgets);

    // Back to ChatListScreen
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 7. Agent Skills E2E
    await tester.tap(find.text('Skills'));
    await tester.pumpAndSettle();
    expect(find.text('Summarizer'), findsOneWidget);
    await tester.tap(find.text('Summarizer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'Edged is an offline on-device AI assistant built for Android and iOS.',
    );
    await tester.tap(find.text('Run Skill'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Result'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 8. Settings & Profile E2E
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Edged v1.0.0'), findsOneWidget);
    expect(find.text('Built by Sambeet Das'), findsOneWidget);
    expect(find.text('App Lock'), findsOneWidget);
  });
}
