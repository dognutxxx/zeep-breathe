// SYS.9 sensor side: accelerometer readings from sensors_plus as [Vec3].
// Kept behind [TiltSource] so screens can be driven by fake readings in tests.

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'tilt_physics.dart';

abstract class TiltSource {
  /// Gravity readings in device axes (m/s²). Errors when there is no sensor.
  Stream<Vec3> readings();
}

class AccelerometerTiltSource implements TiltSource {
  const AccelerometerTiltSource();

  @override
  Stream<Vec3> readings() =>
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).map((e) => Vec3(e.x, e.y, e.z));
}

abstract class DisplayRotationSource {
  /// Quarter turns of the screen from the device's natural orientation
  /// (0-3, see [remapTilt]).
  Future<int> rotation();
}

/// Reads the real screen rotation from the `zeep/display` channel
/// (MainActivity.kt / AppDelegate.swift). The window shape alone can't tell:
/// split view, Slide Over and landscape-natural tablets fool it.
class PlatformDisplayRotation implements DisplayRotationSource {
  static const _channel = MethodChannel('zeep/display');

  const PlatformDisplayRotation();

  @override
  Future<int> rotation() async {
    try {
      return (await _channel.invokeMethod<int>('rotation') ?? 0) & 3;
    } catch (_) {
      return 0; // no channel (tests, other platforms): assume natural
    }
  }
}
