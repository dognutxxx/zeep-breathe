import CoreHaptics
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let haptics = ZeepHaptics()
  private var hapticsChannel: FlutterMethodChannel?

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
