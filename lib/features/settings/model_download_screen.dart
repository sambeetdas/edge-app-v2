import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../engine/models/chat_models.dart';
import '../../engine/models/model_tier.dart';
import '../../providers/app_providers.dart';

class ModelDownloadScreen extends ConsumerStatefulWidget {
  final String tierId;

  const ModelDownloadScreen({super.key, required this.tierId});

  @override
  ConsumerState<ModelDownloadScreen> createState() =>
      _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen>
    with WidgetsBindingObserver {
  StreamSubscription<DownloadProgress>? _sub;
  DownloadProgress _progress =
      const DownloadProgress(status: DownloadStatus.idle);

  ModelTier? get _tier => ModelTier.getById(widget.tierId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startDownload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _progress.status == DownloadStatus.error) {
      final msg = _progress.errorMessage ?? '';
      if (msg.contains('Connection') ||
          msg.contains('Socket') ||
          msg.contains('timed out') ||
          msg.contains('HttpException')) {
        _startDownload();
      }
    }
  }

  void _startDownload() {
    final tier = _tier;
    if (tier == null) return;

    _sub?.cancel();
    setState(() {
      _progress = DownloadProgress(
        status: DownloadStatus.downloading,
        totalBytes: tier.totalDownloadBytes,
        currentFileLabel: tier.modelFileName,
      );
    });

    _sub = ref.read(modelManagerProvider).downloadModel(tier).listen(
      (event) async {
        if (!mounted) return;
        setState(() => _progress = event);
        if (event.status == DownloadStatus.completed) {
          await ref.read(downloadedModelProvider.notifier).refresh();
          if (!mounted) return;
          context.go('/home');
        }
      },
    );
  }

  void _pause() {
    ref.read(modelManagerProvider).pauseDownload();
  }

  String _formatDownloadError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('connection closed') ||
        lower.contains('connection reset') ||
        lower.contains('socketexception') ||
        lower.contains('timed out')) {
      return 'Connection interrupted while in background. Tap Resume to continue.';
    }
    return raw.replaceAll(RegExp(r',?\s*uri\s*=\s*\S+'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tier;
    if (tier == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Model Download')),
        body: const Center(child: Text('Unknown model tier.')),
      );
    }

    final pct = (_progress.fraction * 100).toStringAsFixed(1);
    final isDownloading = _progress.status == DownloadStatus.downloading;
    final isPausedOrError = _progress.status == DownloadStatus.paused ||
        _progress.status == DownloadStatus.error;

    return Scaffold(
      appBar: AppBar(title: Text('Download ${tier.displayName}')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  isPausedOrError
                      ? Icons.pause_circle_outline_rounded
                      : Icons.cloud_download_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  tier.displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _progress.currentFileLabel.isNotEmpty
                      ? _progress.currentFileLabel
                      : tier.downloadSizeLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: _progress.fraction,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                Text(
                  '$pct%  (${Formatters.formatBytes(_progress.bytesReceived)} / ${Formatters.formatBytes(_progress.totalBytes)})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                if (isDownloading)
                  OutlinedButton.icon(
                    onPressed: _pause,
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Pause Download'),
                  )
                else if (isPausedOrError)
                  FilledButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Resume / Retry'),
                  ),
                if (_progress.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _formatDownloadError(_progress.errorMessage!),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
