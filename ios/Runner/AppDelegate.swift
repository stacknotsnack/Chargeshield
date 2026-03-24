import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FLTFirebaseCorePlugin.registerWithRegistrar calls [FIRApp configure] automatically.
    // FLTGoogleMapsPlugin reads GMSApiKey from Info.plist when the first map is created.
    // Both are handled by the plugins — no manual setup needed here.
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
