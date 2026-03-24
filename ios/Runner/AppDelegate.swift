import Flutter
import UIKit
import GoogleMaps
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps — key is injected via GOOGLE_MAPS_IOS_API_KEY build setting (xcconfig).
    // Guard: skip if the plist variable was never expanded (literal "$(..." remaining),
    // which would crash the Google Maps SDK with an invalid-key assertion.
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !mapsKey.isEmpty, !mapsKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(mapsKey)
    }

    // Firebase
    FirebaseApp.configure()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
