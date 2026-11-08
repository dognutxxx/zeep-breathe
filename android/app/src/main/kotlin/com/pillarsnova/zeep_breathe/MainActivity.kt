package com.pillarsnova.zeep_breathe

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zeep/haptics")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(vibrator()?.hasVibrator() == true)
                    "play" -> {
                        play(call.arguments as? String ?: "inhale")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= 31)
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        else @Suppress("DEPRECATION") (getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)

    private fun play(name: String) {
        val v = vibrator() ?: return
        if (!v.hasVibrator()) return
        if (Build.VERSION.SDK_INT < 26) {
            @Suppress("DEPRECATION") v.vibrate(if (name == "exhale") 120L else 60L)
            return
        }
        val amp = v.hasAmplitudeControl()
        val effect = when (name) {
            "hold" -> VibrationEffect.createWaveform(
                longArrayOf(0, 40, 100, 40),
                intArrayOf(0, if (amp) 150 else 255, 0, if (amp) 150 else 255), -1)
            "exhale" -> VibrationEffect.createOneShot(120, if (amp) 90 else VibrationEffect.DEFAULT_AMPLITUDE)
            "confirm" -> VibrationEffect.createOneShot(30, if (amp) 100 else VibrationEffect.DEFAULT_AMPLITUDE)
            else -> VibrationEffect.createOneShot(90, if (amp) 115 else VibrationEffect.DEFAULT_AMPLITUDE)
        }
        v.vibrate(effect) // repeat = -1: never loops
    }
}
