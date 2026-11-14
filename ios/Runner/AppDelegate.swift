import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.edgedai.app/device",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "getSystemMemoryBytes":
          result(Int64(ProcessInfo.processInfo.physicalMemory))
        case "getAvailableStorageBytes":
          let url = URL(fileURLWithPath: NSHomeDirectory())
          let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
          result(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
