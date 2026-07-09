package com.pegbounce.pegboardbounce

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ---------------------------------------------------------------
// MainActivity — WebView file-upload bridge.
// ---------------------------------------------------------------
// The hosted WebView's <input type="file"> triggers Flutter's file
// selector callback, which invokes the "pick" method on this
// channel. We open ACTION_GET_CONTENT and return the content:// URIs
// back to the WebView. No file_picker dependency (see gray-part
// pitfalls §1 — file_picker 10+ is Kotlin-only and clashes with
// Flutter's built-in Kotlin support).
// ---------------------------------------------------------------
class MainActivity : FlutterActivity() {
    private val channelId = "bounce/pick"
    private val chooserRequest = 0x50EB
    private var callback: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelId)
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") {
                    val multiple = call.argument<Boolean>("multiple") ?: false
                    val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                    launchChooser(multiple, mimes, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun launchChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // Resolve any orphan request first.
        callback?.success(emptyList<String>())
        callback = result

        val valid = mimes.filter { it.contains("/") }
        val pickIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                valid.isEmpty() -> type = "*/*"
                valid.size == 1 -> type = valid[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, valid.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(Intent.createChooser(pickIntent, null), chooserRequest)
        } catch (_: Exception) {
            callback = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != chooserRequest) return

        val pending = callback
        callback = null
        if (pending == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            pending.success(emptyList<String>())
            return
        }

        val out = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                out.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { out.add(it.toString()) }
        }
        pending.success(out)
    }
}
