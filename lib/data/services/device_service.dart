import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

class DeviceCompatibilityReport {
  final double totalRamGb;
  final double effectiveRamGb;
  final int availableStorageBytes;

  const DeviceCompatibilityReport({
    required this.totalRamGb,
    required this.effectiveRamGb,
    required this.availableStorageBytes,
  });

  static const double osHeadroomGb = 1.5;
  static const int storageBufferBytes = 200 * 1024 * 1024; // 200 MB

  bool hasEnoughRam(int runtimeRamGb) {
    if (totalRamGb <= 0) return true; // Unknown RAM — don't block.
    return effectiveRamGb >= runtimeRamGb;
  }

  bool hasEnoughStorage(int requiredBytes) {
    if (availableStorageBytes <= 0) return true;
    return availableStorageBytes >= requiredBytes + storageBufferBytes;
  }
}

class DeviceService {
  static const MethodChannel _channel = MethodChannel('com.edgedai.app/device');
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Battery _battery = Battery();

  Future<DeviceCompatibilityReport> getCompatibilityReport() async {
    int totalRamBytes = 0;
    int availableStorageBytes = 0;

    try {
      totalRamBytes =
          await _channel.invokeMethod<int>('getSystemMemoryBytes') ?? 0;
    } catch (_) {}

    try {
      availableStorageBytes =
          await _channel.invokeMethod<int>('getAvailableStorageBytes') ?? 0;
    } catch (_) {}

    final totalRamGb = totalRamBytes / (1024 * 1024 * 1024);
    final effectiveRamGb =
        (totalRamGb - DeviceCompatibilityReport.osHeadroomGb)
            .clamp(0.0, double.infinity);

    return DeviceCompatibilityReport(
      totalRamGb: totalRamGb,
      effectiveRamGb: effectiveRamGb,
      availableStorageBytes: availableStorageBytes,
    );
  }

  Future<String> buildDeviceContextString() async {
    String deviceName = 'Mobile Device';
    String osVersion = Platform.operatingSystem;

    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        deviceName = '${info.manufacturer} ${info.model}';
        osVersion =
            'Android ${info.version.release} (API ${info.version.sdkInt})';
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        deviceName = info.utsname.machine;
        osVersion = 'iOS ${info.systemVersion}';
      }
    } catch (_) {}

    String batteryStr = 'unknown';
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      batteryStr = '$level% (${state.name})';
    } catch (_) {}

    final report = await getCompatibilityReport();
    final storageGb =
        report.availableStorageBytes / (1024 * 1024 * 1024);

    return 'Device: $deviceName. OS: $osVersion. Battery: $batteryStr. '
        'Available storage: ${storageGb.toStringAsFixed(1)} GB.';
  }
}
