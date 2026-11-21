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
  bool _authed = false;
  String? _phone;
  String? _otp;

  @override
  Future<bool> isAuthenticated() async => _authed;

  @override
  Future<String?> getPhoneNumber() async => _phone;

  @override
  Future<String> sendOtp(String fullPhoneNumber) async {
    _phone = fullPhoneNumber;
    _otp = '123456';
    return _otp!;
  }

  @override
  Future<String?> getPendingOtp() async => _otp;

  @override
  Future<bool> verifyOtp(String code) async {
    if (code.trim() == _otp) {
      _authed = true;
      _otp = null;
      return true;
    }
    return false;
  }

  @override
  Future<void> signOut() async {
    _authed = false;
    _phone = null;
    _otp = null;
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

  testWidgets('Full E2E: Auth -> Model Download -> Chat -> Skills -> Games -> Sign Out',
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

    // 1. Splash -> Phone Sign-In
    await tester.pumpAndSettle();
    expect(find.text('Edged'), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Phone number'),
      '5551234567',
    );
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();

    // 2. OTP Verification
    expect(find.text('Enter verification code'), findsOneWidget);
    expect(find.text('Local OTP code: 123456'), findsOneWidget);
    await tester.tap(find.text('Fill'));
    await tester.pump();
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();

    // 3. Settings (no model downloaded yet -> only Settings visible)
    expect(find.text('No AI model downloaded'), findsOneWidget);
    await tester.tap(find.text('Choose & Download Model'));
    await tester.pumpAndSettle();

    // 4. Model Selection -> Download Qwen2.5-VL 3B (Vision + Docs)
    expect(find.text('Qwen2.5-VL 3B'), findsOneWidget);
    await tester.tap(find.text('Qwen2.5-VL 3B'));
    await tester.pumpAndSettle();

    // 5. Capability-gated tabs are now unlocked
    expect(find.text('Chats'), findsWidgets);
    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Docs'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // 6. AI Chat E2E
    await tester.tap(find.text('New Chat').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Message Edged...'),
      'Hello Edged!',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
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

    // 8. AI Games E2E (Word Chain validation)
    await tester.tap(find.text('Games'));
    await tester.pumpAndSettle();
    expect(find.text('Word Chain'), findsOneWidget);
    await tester.tap(find.text('Word Chain'));
    await tester.pumpAndSettle();

    // Invalid multi-word input rejected client-side
    await tester.enterText(find.byType(TextField), 'two words');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('single English word'),
      findsOneWidget,
    );

    // Valid word input
    await tester.enterText(find.byType(TextField), 'apple');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('Next word must start with:'), findsOneWidget);

    // How to Play dialog
    await tester.tap(find.byIcon(Icons.help_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('How to Play: Word Chain'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    // 9. Settings & Sign Out E2E
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Edged v1.0.0'), findsOneWidget);
    expect(find.text('Built by Sambeet Das'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Sign Out'), 200);
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
    expect(find.text('Send Code'), findsOneWidget);
  });
}
