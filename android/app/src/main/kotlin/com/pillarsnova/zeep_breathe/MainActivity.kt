package com.pillarsnova.zeep_breathe

import android.content.Context
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Surface
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Edge-to-edge on every Android version the app supports, so the Flutter
    // view fills the window like the native launch screen (the splash logo
    // stays put) and screens keep clear of the bars with SafeArea.
    // Flutter's own edgeToEdge mode only covers Android 10+.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyEdgeToEdge()
    }

    // Flutter re-applies its default system UI flags on resume (Android 9 and
    // older): put the edge-to-edge layout flags back.
    override fun onPostResume() {
        super.onPostResume()
        applyEdgeToEdge()
    }

    private fun applyEdgeToEdge() {
        val w = window
        if (Build.VERSION.SDK_INT >= 30) {
            w.setDecorFitsSystemWindows(false)
        } else {
            // Android 7 can't draw dark navigation icons: it gets a dim scrim
            // behind its white icons instead of a clear bar (set below).
            val nav = View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                if (Build.VERSION.SDK_INT >= 26) View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR else 0
            @Suppress("DEPRECATION")
            w.decorView.systemUiVisibility = w.decorView.systemUiVisibility or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR or
                nav
        }
        @Suppress("DEPRECATION")
        w.statusBarColor = Color.TRANSPARENT
        @Suppress("DEPRECATION")
        w.navigationBarColor = if (Build.VERSION.SDK_INT >= 26) Color.TRANSPARENT else 0x66000000
        if (Build.VERSION.SDK_INT >= 29) w.isNavigationBarContrastEnforced = false
    }

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
        // `zeep/display` used by lib/tilt/tilt_sensor.dart (Zeep Balance):
        // quarter turns of the screen from the natural orientation, so the
        // game can turn accelerometer axes into screen axes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zeep/display")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "rotation" -> result.success(displayRotation())
                    else -> result.notImplemented()
                }
            }
    }

    private fun displayRotation(): Int {
        val r = if (Build.VERSION.SDK_INT >= 30) display?.rotation ?: Surface.ROTATION_0
        else @Suppress("DEPRECATION") windowManager.defaultDisplay.rotation
        return when (r) {
            Surface.ROTATION_90 -> 1
            Surface.ROTATION_180 -> 2
            Surface.ROTATION_270 -> 3
            else -> 0
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
            @Suppress("DEPRECATION") v.vibrate(when (name) {
                "exhale" -> 120L
                "edgeIn" -> 15L
                "bloom" -> 110L
                else -> 60L
            })
            return
        }
        val amp = v.hasAmplitudeControl()
        val effect = when (name) {
            "hold" -> VibrationEffect.createWaveform(
                longArrayOf(0, 40, 100, 40),
                intArrayOf(0, if (amp) 150 else 255, 0, if (amp) 150 else 255), -1)
            "exhale" -> VibrationEffect.createOneShot(120, if (amp) 90 else VibrationEffect.DEFAULT_AMPLITUDE)
            "confirm" -> VibrationEffect.createOneShot(30, if (amp) 100 else VibrationEffect.DEFAULT_AMPLITUDE)
            // Zeep Balance edge pulses
            "edgeOut" -> VibrationEffect.createOneShot(70, if (amp) 100 else VibrationEffect.DEFAULT_AMPLITUDE)
            "edgeIn" -> VibrationEffect.createOneShot(15, if (amp) 80 else VibrationEffect.DEFAULT_AMPLITUDE)
            // two soft pulses, the second stronger and longer (a petal opening)
            "bloom" -> VibrationEffect.createWaveform(
                longArrayOf(0, 60, 100, 110),
                intArrayOf(0, if (amp) 90 else 255, 0, if (amp) 130 else 255), -1)
            else -> VibrationEffect.createOneShot(90, if (amp) 115 else VibrationEffect.DEFAULT_AMPLITUDE)
        }
        v.vibrate(effect) // repeat = -1: never loops
    }
}
