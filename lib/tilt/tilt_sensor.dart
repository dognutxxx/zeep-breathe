// SYS.9 sensor side: accelerometer readings from sensors_plus as [Vec3].
// Kept behind [TiltSource] so screens can be driven by fake readings in tests.

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
