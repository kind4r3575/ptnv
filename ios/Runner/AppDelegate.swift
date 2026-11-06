import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: present notifications while the app is running.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IncomingFilePlugin") {
      IncomingFilePlugin.register(with: registrar)
    }
  }
}

/// Receives Pod Tracker backup files opened from other apps ("Open in…" /
/// share sheet from Files, Mail, a messenger or AirDrop — see
/// CFBundleDocumentTypes in Info.plist) and hands their bytes to Dart over
/// `ptnv/incoming_file` (see `lib/services/incoming_file_service.dart`).
///
/// A file that launches the app arrives before Dart is listening, so it is
/// held until Dart asks for it with `takePending`; later ones are pushed
/// with `fileReceived`.
final class IncomingFilePlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  /// A real backup is well under 1 MB; anything this big isn't one.
  private static let maxBytes = 10 * 1024 * 1024

  private let channel: FlutterMethodChannel
  private var pending: [String: Any]?
  private var dartListening = false

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ptnv/incoming_file",
      binaryMessenger: registrar.messenger()
    )
    let instance = IncomingFilePlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "takePending":
      dartListening = true
      result(pending)
      pending = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Scene events (this app uses UIScene; see SceneDelegate.swift)

  /// Cold launch by opening a file.
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let url = connectionOptions?.urlContexts.first(where: { $0.url.isFileURL })?.url
    else { return false }
    receive(url)
    return true
  }

  /// A file opened while the app is running or suspended.
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = URLContexts.first(where: { $0.url.isFileURL })?.url else { return false }
    receive(url)
    return true
  }

  // MARK: - App delegate fallback (no scene lifecycle)

  func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    guard url.isFileURL else { return false }
    receive(url)
    return true
  }

  // MARK: -

  private func receive(_ url: URL) {
    DispatchQueue.global(qos: .userInitiated).async {
      let scoped = url.startAccessingSecurityScopedResource()
      let data = try? Data(contentsOf: url)
      if scoped { url.stopAccessingSecurityScopedResource() }
      // iOS copies the file into Documents/Inbox for us; it's not needed after reading.
      if url.path.contains("/Inbox/") { try? FileManager.default.removeItem(at: url) }

      var payload: [String: Any] = [:]
      if let data = data, data.count <= IncomingFilePlugin.maxBytes {
        payload["bytes"] = FlutterStandardTypedData(bytes: data)
      }
      DispatchQueue.main.async { self.deliver(payload) }
    }
  }

  private func deliver(_ payload: [String: Any]) {
    if dartListening {
      channel.invokeMethod("fileReceived", arguments: payload)
    } else {
      pending = payload
    }
  }
}
