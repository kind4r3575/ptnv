package com.example.ptnv

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives Pod Tracker backup files from other apps — "Open with" (ACTION_VIEW)
 * or "Share" (ACTION_SEND) from a messenger, email, Files or Quick Share — and
 * hands their bytes to Dart over `ptnv/incoming_file` (see
 * `lib/services/incoming_file_service.dart`).
 *
 * The activity is `singleTask` (AndroidManifest.xml), so a file opened while
 * the app is already running arrives here via [onNewIntent] instead of
 * starting a second copy of the app with its own state.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** A file that arrived before Dart asked for it (cold launch). */
    private var pending: Map<String, Any?>? = null

    /** Set once Dart has collected [pending]; later files are pushed directly. */
    private var dartListening = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePending" -> {
                        dartListening = true
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // savedInstanceState != null means the system is recreating the
        // activity with the intent it already handled — don't import twice.
        if (savedInstanceState == null) receive(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receive(intent)
    }

    private fun receive(intent: Intent?) {
        if (intent == null) return
        // Reopened from Recents: the original "Open with" intent is replayed, but
        // that file was already handled when the task first started.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val uri = fileUri(intent) ?: return
        // Off the main thread: a cloud-backed provider (e.g. Drive) may have to
        // download the file first.
        Thread {
            val bytes = read(uri)
            runOnUiThread { deliver(mapOf("bytes" to bytes)) }
        }.start()
    }

    private fun fileUri(intent: Intent): Uri? = when (intent.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
        else -> null
    }

    /** The file's bytes, or null if it can't be read or is implausibly large. */
    private fun read(uri: Uri): ByteArray? = try {
        contentResolver.openInputStream(uri)?.use { input ->
            val out = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(64 * 1024)
            var total = 0
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                total += n
                if (total > MAX_BYTES) return@use null
                out.write(buffer, 0, n)
            }
            out.toByteArray()
        }
    } catch (e: Exception) {
        null
    }

    private fun deliver(payload: Map<String, Any?>) {
        val ch = channel
        if (dartListening && ch != null) {
            ch.invokeMethod("fileReceived", payload)
        } else {
            pending = payload
        }
    }

    companion object {
        private const val CHANNEL = "ptnv/incoming_file"

        /** A real backup is well under 1 MB; anything this big isn't one. */
        private const val MAX_BYTES = 10 * 1024 * 1024
    }
}
