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
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
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
                    "pickDocument" -> {
                        if (pendingDocResult != null) {
                            result.error("already_active", "Document picker is already open.", null)
                            return@setMethodCallHandler
                        }
                        pendingDocResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
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
                var name = queryDisplayName(uri) ?: "document"
                if (!name.contains('.')) {
                    val mime = contentResolver.getType(uri)
                    val ext = when (mime) {
                        "application/pdf" -> ".pdf"
                        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> ".docx"
                        "text/markdown" -> ".md"
                        "text/plain" -> ".txt"
                        else -> ""
                    }
                    if (ext.isNotEmpty()) name += ext
                }
                val maxBytes = 10 * 1024 * 1024
                val tempFile = java.io.File.createTempFile("picked_", "_doc", cacheDir)
                val input = openDocumentStream(uri, onConvertedExtension = { ext ->
                    if (!name.endsWith(ext, ignoreCase = true)) {
                        name = "$name$ext"
                    }
                })
                try {
                    input.use { stream ->
                        tempFile.outputStream().use { out ->
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
                    }
                } catch (e: Exception) {
                    tempFile.delete()
                    throw e
                }
                val filePath = tempFile.absolutePath
                runOnUiThread {
                    callback.success(
                        mapOf(
                            "name" to name,
                            "path" to filePath,
                        )
                    )
                }
            } catch (e: Exception) {
                android.util.Log.e("EdgedDocPicker", "Failed to open document uri=$uri", e)
                runOnUiThread {
                    val detail = e.message?.takeIf { it.isNotBlank() } ?: e.javaClass.simpleName
                    val msg = if (e is java.io.FileNotFoundException) {
                        "File could not be opened ($detail). Try picking it from Downloads or Internal Storage."
                    } else {
                        detail
                    }
                    callback.error("doc_read_error", msg, null)
                }
            }
        }.start()
    }

    private fun openDocumentStream(
        uri: Uri,
        onConvertedExtension: (String) -> Unit,
    ): java.io.InputStream {
        try {
            contentResolver.openInputStream(uri)?.let { return it }
        } catch (_: Exception) {
        }
        try {
            contentResolver.openAssetFileDescriptor(uri, "r")?.createInputStream()?.let { return it }
        } catch (_: Exception) {
        }
        val streamTypes = contentResolver.getStreamTypes(uri, "*/*") ?: emptyArray()
        for (mime in listOf("application/pdf", "text/plain")) {
            if (streamTypes.isEmpty() || streamTypes.any { it == mime || it == "*/*" }) {
                try {
                    val afd = contentResolver.openTypedAssetFileDescriptor(uri, mime, null)
                    if (afd != null) {
                        onConvertedExtension(if (mime == "application/pdf") ".pdf" else ".txt")
                        return afd.createInputStream()
                    }
                } catch (_: Exception) {
                }
            }
        }
        throw java.io.FileNotFoundException("Cannot open stream for URI")
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
