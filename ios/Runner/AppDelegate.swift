import CoreHaptics
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let haptics = ZeepHaptics()
  private var hapticsChannel: FlutterMethodChannel?
  private var displayChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // `zeep/haptics` channel used by lib/haptics/haptics_service.dart
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ZeepHaptics") else { return }
    let channel = FlutterMethodChannel(name: "zeep/haptics", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "isSupported":
        result(self.haptics.supported)
      case "play":
        self.haptics.play((call.arguments as? String) ?? "inhale")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    hapticsChannel = channel

    // `zeep/display` channel used by lib/tilt/tilt_sensor.dart (Zeep Balance)
    guard let displayRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "ZeepDisplay") else { return }
    let display = FlutterMethodChannel(name: "zeep/display", binaryMessenger: displayRegistrar.messenger())
    display.setMethodCallHandler { call, result in
      switch call.method {
      case "rotation":
        result(ZeepDisplay.rotation())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    displayChannel = display
  }
}

/// Quarter turns of the interface from portrait, matching Android's
/// Surface.ROTATION_* and remapTilt() in lib/tilt/tilt_physics.dart.
/// CoreMotion axes are fixed to the device in portrait (home button / bottom
/// edge down), and sensors_plus reports them in the Android convention.
///
///   interfaceOrientation   device turned        returns
///   .portrait              (natural)            0
///   .landscapeRight        90 deg CCW, home R   1
///   .portraitUpsideDown    180 deg              2
///   .landscapeLeft         90 deg CW, home L    3
///
/// Uses the window scene, so iPad Split View / Slide Over report the real
/// interface orientation rather than the window's shape.
enum ZeepDisplay {
  static func rotation() -> Int {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    switch scene?.interfaceOrientation {
    case .landscapeRight: return 1
    case .portraitUpsideDown: return 2
    case .landscapeLeft: return 3
    default: return 0
    }
  }
}

/// Core Haptics patterns from app/src/haptics.rs. Only discrete pulses at
/// phase transitions - never continuous vibration.
final class ZeepHaptics {
  private var engine: CHHapticEngine?
  private let fallback = UIImpactFeedbackGenerator(style: .soft)

  var supported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

  init() {
    guard supported else { return }
    engine = try? CHHapticEngine()
    engine?.isAutoShutdownEnabled = true
    engine?.playsHapticsOnly = true
    engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
    try? engine?.start()
  }

  func play(_ name: String) {
    guard supported, let engine = engine else {
      // older iPhones without a Taptic Engine pattern player
      fallback.impactOccurred()
      return
    }
    // (relative time, duration, intensity, sharpness)
    let pulses: [(TimeInterval, TimeInterval, Float, Float)]
    switch name {
    case "hold": pulses = [(0, 0.04, 0.6, 0.5), (0.14, 0.04, 0.6, 0.5)]
    case "exhale": pulses = [(0, 0.12, 0.35, 0.1)]
    case "confirm": pulses = [(0, 0.03, 0.4, 0.6)]
    // Zeep Balance edge pulses
    case "edgeOut": pulses = [(0, 0.07, 0.4, 0.15)]
    case "edgeIn": pulses = [(0, 0.015, 0.3, 0.7)]
    case "bloom": pulses = [(0, 0.06, 0.35, 0.2), (0.16, 0.11, 0.5, 0.25)]
    default: pulses = [(0, 0.09, 0.45, 0.2)]
    }
    let events = pulses.map { at, dur, intensity, sharpness in
      CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ],
        relativeTime: at,
        duration: dur)
    }
    do {
      let pattern = try CHHapticPattern(events: events, parameters: [])
      let player = try engine.makePlayer(with: pattern)
      try engine.start()
      try player.start(atTime: CHHapticTimeImmediate)
    } catch {
      fallback.impactOccurred()
    }
  }
}
