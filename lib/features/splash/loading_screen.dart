import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/edged_logo.dart';
import '../../providers/app_providers.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  bool _needsUnlock = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_needsUnlock && mounted) {
      setState(() => _needsUnlock = false);
    }
    final auth = ref.read(authServiceProvider);
    final lockEnabled = await auth.isAppLockEnabled();
    if (lockEnabled) {
      final unlocked = await auth.authenticateWithDevice();
      if (!mounted) return;
      if (!unlocked) {
        setState(() => _needsUnlock = true);
        return;
      }
    }
    await ref.read(downloadedModelProvider.notifier).refresh();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EdgedLogo(size: 84, borderRadius: 22),
            const SizedBox(height: 20),
            Text(
              'Edged',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 24),
            if (_needsUnlock)
              FilledButton.icon(
                onPressed: _bootstrap,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock Edged'),
              )
            else
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
          ],
        ),
      ),
    );
  }
}
