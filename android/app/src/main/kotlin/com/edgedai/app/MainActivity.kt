package com.edgedai.app

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val deviceChannel = "com.edgedai.app/device"
    private val pickDocRequestCode = 4103
    private var pendingDocResult: MethodChannel.Result? = null

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
                    "pickDocument" -> {
                        if (pendingDocResult != null) {
                            result.error("already_active", "Document picker is already open.", null)
                            return@setMethodCallHandler
                        }
                        pendingDocResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        startActivityForResult(intent, pickDocRequestCode)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickDocRequestCode) return

        val callback = pendingDocResult ?: return
        pendingDocResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            callback.success(null)
            return
        }

        val uri = data.data!!
        Thread {
            try {
                val name = queryDisplayName(uri) ?: "document"
                val maxBytes = 10 * 1024 * 1024
                val out = ByteArrayOutputStream()
                val input = contentResolver.openInputStream(uri)
                    ?: throw java.io.FileNotFoundException("Cannot open selected file.")
                input.use { stream ->
                    val buf = ByteArray(32 * 1024)
                    var total = 0
                    while (true) {
                        val read = stream.read(buf)
                        if (read <= 0) break
                        total += read
                        if (total > maxBytes) {
                            throw IllegalArgumentException("File exceeds the 10 MB limit.")
                        }
                        out.write(buf, 0, read)
                    }
                }
                val bytes = out.toByteArray()
                runOnUiThread {
                    callback.success(
                        mapOf(
                            "name" to name,
                            "bytes" to bytes,
                        )
                    )
                }
            } catch (e: Exception) {
                runOnUiThread {
                    val msg = if (e is java.io.FileNotFoundException) {
                        "File could not be opened. Try picking it from Downloads or Internal Storage."
                    } else {
                        e.message ?: "Failed to read selected file."
                    }
                    callback.error("doc_read_error", msg, null)
                }
            }
        }.start()
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) return cursor.getString(idx)
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }
}
