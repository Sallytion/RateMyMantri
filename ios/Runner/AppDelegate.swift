import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.ratemymantri.app/translit",
      binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      guard call.method == "translitBatch",
            let args   = call.arguments as? [String: Any],
            let texts  = args["texts"]  as? [String],
            let script = args["script"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }

      let transform = StringTransform("Latin-\(script)")
      var output: [String] = []
      for text in texts {
        if let t = text.applyingTransform(transform, reverse: false) {
          output.append(t)
        } else {
          output.append(text) // keep original on failure
        }
      }
      result(output)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
