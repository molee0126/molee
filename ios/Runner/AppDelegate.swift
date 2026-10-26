import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let privacyChannel = FlutterMethodChannel(
      name: "faceai/privacy",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    privacyChannel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String,
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        result(FlutterError(code: "INVALID_PATH", message: "无法确认私有存储目录", details: nil))
        return
      }
      var directory = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
      let expected = support.appendingPathComponent("faceai_private", isDirectory: true).standardizedFileURL
      guard directory.path == expected.path else {
        result(FlutterError(code: "INVALID_PATH", message: "目录不在私有存储范围内", details: nil))
        return
      }
      do {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: directory.path)
        result(nil)
      } catch {
        result(FlutterError(code: "PRIVACY_SETUP_FAILED", message: "无法设置本机数据保护", details: nil))
      }
    }
  }
}
