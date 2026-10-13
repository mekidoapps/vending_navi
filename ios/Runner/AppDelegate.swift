import UIKit
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = serviceValue("GoogleMapsAPIKey"),
       key.range(of: "^AIza[A-Za-z0-9_-]{35}$", options: .regularExpression) != nil {
      if !GMSServices.provideAPIKey(key) {
        NSLog("[iOS configuration] Maps SDK rejected its configuration; value withheld.")
      }
    } else {
      NSLog("[iOS configuration] Maps is not configured. Fill LocalServices.xcconfig and run tool/check_ios_runtime_config.cjs before device testing. No API key was supplied to Maps.")
    }

    let client = serviceValue("GIDClientID")
    let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
    let schemes = urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    if let client = client,
       client.range(of: "^[A-Za-z0-9_-]+\\.apps\\.googleusercontent\\.com$", options: .regularExpression) != nil {
      let prefix = String(client.dropLast(".apps.googleusercontent.com".count))
      if !schemes.contains("com.googleusercontent.apps." + prefix) {
        NSLog("[iOS configuration] Google Sign-In URL scheme does not match the iOS client ID; values withheld.")
      }
    } else {
      NSLog("[iOS configuration] Google Sign-In iOS client ID is missing or invalid. Device testing requires confirmed iOS OAuth configuration; value withheld.")
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func serviceValue(_ name: String) -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: name) as? String else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, !value.contains("$("), !value.contains("${"),
          !value.contains("<"), !value.contains(">"),
          !["YOUR_", "REPLACE_", "EXAMPLE_", "PLACEHOLDER"].contains(where: { value.uppercased().hasPrefix($0) })
    else { return nil }
    return value
  }
}
