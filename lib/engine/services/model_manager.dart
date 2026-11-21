import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/chat_models.dart';
import '../models/model_tier.dart';

class ModelManager {
  static const String _metaFileName = 'prompter_model_meta.json';
  static const MethodChannel _deviceChannel =
      MethodChannel('com.edgedai.app/device');
  final Dio _dio;
  CancelToken? _activeCancelToken;

  ModelManager({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(minutes: 30),
                followRedirects: true,
                maxRedirects: 5,
              ),
            );

  Future<Directory> _modelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _metaFile() async {
    final dir = await _modelsDirectory();
    return File(p.join(dir.path, _metaFileName));
  }

  Future<DownloadedModelInfo?> getDownloadedModel() async {
    final dir = await _modelsDirectory();
    final meta = await _metaFile();

    if (await meta.exists()) {
      try {
        final raw = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
        final tierId = raw['tierId'] as String?;
        final dateStr = raw['downloadDate'] as String?;
        if (tierId != null) {
          final tier = ModelTier.getById(tierId);
          if (tier != null) {
            final modelFile = File(p.join(dir.path, tier.modelFileName));
            if (await modelFile.exists()) {
              final modelLen = await modelFile.length();
              String? mmProjPath;
              int mmLen = 0;
              if (tier.mmProjFileName != null) {
                final mmFile = File(p.join(dir.path, tier.mmProjFileName!));
                if (await mmFile.exists()) {
                  mmProjPath = mmFile.path;
                  mmLen = await mmFile.length();
                }
              }
              return DownloadedModelInfo(
                tierId: tier.id,
                modelPath: modelFile.path,
                mmProjPath: mmProjPath,
                downloadDate: DateTime.tryParse(dateStr ?? '') ?? DateTime.now(),
                totalBytes: modelLen + mmLen,
              );
            }
          }
        }
      } catch (_) {
        // Corrupt metadata — fall through to orphan healing.
      }
    }

    return _scanAndHealOrphanedModel(dir);
  }

  /// Self-healing: if metadata was lost, scan for any known GGUF >= 99% expected size.
  Future<DownloadedModelInfo?> _scanAndHealOrphanedModel(Directory dir) async {
    for (final tier in ModelTier.availableTiers) {
      final modelFile = File(p.join(dir.path, tier.modelFileName));
      if (await modelFile.exists()) {
        final len = await modelFile.length();
        if (len >= (tier.modelSizeBytes * 0.99).round()) {
          String? mmProjPath;
          int mmLen = 0;
          if (tier.mmProjFileName != null) {
            final mmFile = File(p.join(dir.path, tier.mmProjFileName!));
            if (await mmFile.exists()) {
              mmProjPath = mmFile.path;
              mmLen = await mmFile.length();
            }
          }
          final now = DateTime.now().toUtc();
          await _writeMeta(tier.id, now);
          return DownloadedModelInfo(
            tierId: tier.id,
            modelPath: modelFile.path,
            mmProjPath: mmProjPath,
            downloadDate: now,
            totalBytes: len + mmLen,
          );
        }
      }
    }
    return null;
  }

  Future<void> _writeMeta(String tierId, DateTime downloadDate) async {
    final meta = await _metaFile();
    await meta.writeAsString(
      jsonEncode({
        'tierId': tierId,
        'downloadDate': downloadDate.toUtc().toIso8601String(),
      }),
    );
  }

  Stream<DownloadProgress> downloadModel(ModelTier tier) async* {
    final controller = StreamController<DownloadProgress>();
    unawaited(_runDownloadWorker(tier, controller));
    yield* controller.stream;
  }

  Future<void> _runDownloadWorker(
    ModelTier tier,
    StreamController<DownloadProgress> controller,
  ) async {
    _activeCancelToken?.cancel('Superseded');
    final cancelToken = CancelToken();
    _activeCancelToken = cancelToken;

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    if (Platform.isAndroid) {
      try {
        await _deviceChannel.invokeMethod('requestNotificationPermission');
        await _deviceChannel.invokeMethod('startDownloadService', {
          'title': 'Downloading ${tier.displayName}',
        });
      } catch (_) {}
    }

    final dir = await _modelsDirectory();
    final totalExpected = tier.totalDownloadBytes;
    int lastNotifiedPct = -1;
    DateTime lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);

    void notifyBackgroundProgress(int bytesReceived, String label) {
      if (!Platform.isAndroid || totalExpected <= 0) return;
      final pct = ((bytesReceived / totalExpected) * 100).clamp(0, 100).round();
      final now = DateTime.now();
      if (pct == lastNotifiedPct &&
          now.difference(lastNotifyTime).inMilliseconds < 800) {
        return;
      }
      lastNotifiedPct = pct;
      lastNotifyTime = now;
      final receivedMb = (bytesReceived / (1024 * 1024)).toStringAsFixed(0);
      final totalMb = (totalExpected / (1024 * 1024)).toStringAsFixed(0);
      _deviceChannel.invokeMethod('updateDownloadProgress', {
        'progress': pct,
        'subtext': '$pct% ($receivedMb / $totalMb MB) • $label',
      }).catchError((_) {});
    }

    try {
      // 1. Download main model
      final modelFile = File(p.join(dir.path, tier.modelFileName));
      await _downloadSingleFile(
        url: tier.downloadUrl,
        destination: modelFile,
        cancelToken: cancelToken,
        onProgress: (received, _) {
          notifyBackgroundProgress(received, tier.modelFileName);
          if (!controller.isClosed) {
            controller.add(
              DownloadProgress(
                status: DownloadStatus.downloading,
                bytesReceived: received,
                totalBytes: totalExpected,
                currentFileLabel: tier.modelFileName,
              ),
            );
          }
        },
      );

      // 2. Download optional mmproj
      if (tier.mmProjDownloadUrl != null && tier.mmProjFileName != null) {
        final mmFile = File(p.join(dir.path, tier.mmProjFileName!));
        await _downloadSingleFile(
          url: tier.mmProjDownloadUrl!,
          destination: mmFile,
          cancelToken: cancelToken,
          onProgress: (received, _) {
            final totalReceived = tier.modelSizeBytes + received;
            notifyBackgroundProgress(totalReceived, tier.mmProjFileName!);
            if (!controller.isClosed) {
              controller.add(
                DownloadProgress(
                  status: DownloadStatus.downloading,
                  bytesReceived: totalReceived,
                  totalBytes: totalExpected,
                  currentFileLabel: tier.mmProjFileName!,
                ),
              );
            }
          },
        );
      }

      await _writeMeta(tier.id, DateTime.now().toUtc());
      if (!controller.isClosed) {
        controller.add(
          DownloadProgress(
            status: DownloadStatus.completed,
            bytesReceived: totalExpected,
            totalBytes: totalExpected,
            currentFileLabel: tier.displayName,
          ),
        );
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (!controller.isClosed) {
          controller.add(
            DownloadProgress(
              status: DownloadStatus.paused,
              totalBytes: totalExpected,
              currentFileLabel: tier.displayName,
              errorMessage: 'Download paused.',
            ),
          );
        }
      } else {
        final msg = _classifyError(e);
        if (!controller.isClosed) {
          controller.add(
            DownloadProgress(
              status: DownloadStatus.error,
              totalBytes: totalExpected,
              currentFileLabel: tier.displayName,
              errorMessage: msg,
            ),
          );
        }
      }
    } catch (e) {
      final isDiskFull = e.toString().toLowerCase().contains('space') ||
          e.toString().toLowerCase().contains('enospc');
      if (!controller.isClosed) {
        controller.add(
          DownloadProgress(
            status: DownloadStatus.error,
            totalBytes: totalExpected,
            currentFileLabel: tier.displayName,
            errorMessage: isDiskFull
                ? 'Not enough storage space to download ${tier.displayName}.'
                : 'Download failed: $e',
          ),
        );
      }
    } finally {
      if (Platform.isAndroid) {
        try {
          await _deviceChannel.invokeMethod('stopDownloadService');
        } catch (_) {}
      }
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      if (identical(_activeCancelToken, cancelToken)) {
        _activeCancelToken = null;
      }
      await controller.close();
    }
  }

  Future<void> _downloadSingleFile({
    required String url,
    required File destination,
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    final partFile = File('${destination.path}.part');
    int existingBytes = 0;
    if (await partFile.exists()) {
      existingBytes = await partFile.length();
    }

    final headers = <String, dynamic>{};
    if (existingBytes > 0) {
      headers['Range'] = 'bytes=$existingBytes-';
    }

    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
      ),
    );

    final statusCode = response.statusCode ?? 200;
    final isResumed = statusCode == 206 && existingBytes > 0;
    if (!isResumed) {
      existingBytes = 0;
    }

    final sink = partFile.openWrite(
      mode: isResumed ? FileMode.append : FileMode.write,
    );

    int received = existingBytes;
    final contentLen = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        0;
    final total = contentLen > 0 ? existingBytes + contentLen : 0;

    try {
      await for (final chunk in response.data!.stream) {
        if (cancelToken.isCancelled) {
          throw DioException.requestCancelled(
            requestOptions: response.requestOptions,
            reason: 'Paused by user',
          );
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (await destination.exists()) {
      await destination.delete();
    }
    await partFile.rename(destination.path);
  }

  String _classifyError(DioException e) {
    final lower = '${e.message} ${e.error}'.toLowerCase();
    if (lower.contains('enospc') || lower.contains('no space')) {
      return 'Device storage is full. Free up space and retry.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Network unavailable. Check your Wi-Fi or mobile connection.';
    }
    return e.message ?? 'Download failed.';
  }

  void pauseDownload() {
    _activeCancelToken?.cancel('Paused by user');
  }

  Future<void> deletePartialDownloads(ModelTier tier) async {
    final dir = await _modelsDirectory();
    for (final name in [tier.modelFileName, tier.mmProjFileName]) {
      if (name == null) continue;
      final part = File(p.join(dir.path, '$name.part'));
      if (await part.exists()) {
        await part.delete();
      }
    }
  }

  Future<void> deleteDownloadedModel() async {
    pauseDownload();
    final dir = await _modelsDirectory();
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }
}
