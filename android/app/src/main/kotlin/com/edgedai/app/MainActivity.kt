package com.edgedai.app

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceChannel = "com.edgedai.app/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSystemMemoryBytes" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memInfo = ActivityManager.MemoryInfo()
                        am.getMemoryInfo(memInfo)
                        result.success(memInfo.totalMem)
                    }
                    "getAvailableStorageBytes" -> {
                        val stat = StatFs(filesDir.absolutePath)
                        result.success(stat.availableBytes)
                    }
                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                4102,
                            )
                        }
                        result.success(true)
                    }
                    "startDownloadService" -> {
                        val title = call.argument<String>("title") ?: "Downloading AI model"
                        val intent = Intent(this, ModelDownloadService::class.java).apply {
                            action = ModelDownloadService.ACTION_START
                            putExtra(ModelDownloadService.EXTRA_TITLE, title)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "updateDownloadProgress" -> {
                        val progress = call.argument<Int>("progress") ?: -1
                        val subtext = call.argument<String>("subtext") ?: ""
                        val intent = Intent(this, ModelDownloadService::class.java).apply {
                            action = ModelDownloadService.ACTION_UPDATE
                            putExtra(ModelDownloadService.EXTRA_PROGRESS, progress)
                            putExtra(ModelDownloadService.EXTRA_SUBTEXT, subtext)
                        }
                        startService(intent)
                        result.success(true)
                    }
                    "stopDownloadService" -> {
                        val intent = Intent(this, ModelDownloadService::class.java).apply {
                            action = ModelDownloadService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
