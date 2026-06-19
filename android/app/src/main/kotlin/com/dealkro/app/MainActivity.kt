package com.dealkro.app

import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var voiceResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "buyselladda/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val text = call.argument<String>("text").orEmpty()
                val title = call.argument<String>("title") ?: "Share"
                if (text.isBlank()) {
                    result.error("empty_text", "Share text is empty", null)
                    return@setMethodCallHandler
                }

                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                startActivity(Intent.createChooser(intent, title))
                result.success(true)
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "buyselladda/voice")
            .setMethodCallHandler { call, result ->
                if (call.method != "listen") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                voiceResult = result
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault())
                    putExtra(RecognizerIntent.EXTRA_PROMPT, "Search BuySellAdda")
                }
                try {
                    startActivityForResult(intent, 9010)
                } catch (error: Exception) {
                    voiceResult = null
                    result.error("voice_unavailable", "Voice search is unavailable", null)
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 9010) return
        val matches = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
        voiceResult?.success(matches?.firstOrNull().orEmpty())
        voiceResult = null
    }
}
