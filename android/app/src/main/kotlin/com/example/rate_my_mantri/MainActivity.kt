package com.example.rate_my_mantri

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.ratemymantri.app/translit"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "translitBatch" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
                            result.error("API_TOO_LOW", "Requires API 24+", null)
                            return@setMethodCallHandler
                        }
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val texts = call.argument<List<String>>("texts") ?: emptyList()
                            val icuId  = call.argument<String>("script") ?: "Devanagari"
                            val transliterator =
                                android.icu.text.Transliterator.getInstance("Latin-$icuId")
                            val output = texts.map { transliterator.transliterate(it) }
                            result.success(output)
                        } catch (e: Exception) {
                            result.error("TRANSLIT_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
