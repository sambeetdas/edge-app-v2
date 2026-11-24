import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'features/auth/phone_sign_in_screen.dart';
import 'features/auth/pin_verification_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/proactive/proactive_screen.dart';
import 'features/settings/model_download_screen.dart';
import 'features/settings/model_selection_screen.dart';
import 'features/shell/main_shell_screen.dart';
import 'features/skills/create_skill_screen.dart';
import 'features/skills/skill_execution_screen.dart';
import 'features/splash/loading_screen.dart';

GoRouter createAppRouter({String initialLocation = '/loading'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/loading',
      builder: (_, __) => const LoadingScreen(),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (_, __) => const PhoneSignInScreen(),
    ),
    GoRoute(
      path: '/auth/pin',
      builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return PinVerificationScreen(
          phoneNumber: (extra['phone'] as String?) ?? '',
          hasPin: (extra['hasPin'] as bool?) ?? false,
        );
      },
    ),
    GoRoute(
      path: '/home',
      builder: (_, __) => const MainShellScreen(),
    ),
    GoRoute(
      path: '/chat/:sessionId',
      builder: (_, state) => ChatScreen(
        sessionId: state.pathParameters['sessionId']!,
      ),
    ),
    GoRoute(
      path: '/skills/run/:skillId',
      builder: (_, state) => SkillExecutionScreen(
        skillId: state.pathParameters['skillId']!,
      ),
    ),
    GoRoute(
      path: '/skills/create',
      builder: (_, __) => const CreateSkillScreen(),
    ),
    GoRoute(
      path: '/proactive',
      builder: (_, __) => const ProactiveScreen(),
    ),
    GoRoute(
      path: '/models',
      builder: (_, __) => const ModelSelectionScreen(),
    ),
    GoRoute(
      path: '/models/download/:tierId',
      builder: (_, state) => ModelDownloadScreen(
        tierId: state.pathParameters['tierId']!,
      ),
    ),
  ],
);

class EdgedApp extends ConsumerWidget {
  final GoRouter? router;

  const EdgedApp({super.key, this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Edged',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router ?? createAppRouter(),
    );
  }
}
