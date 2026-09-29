import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var apnsDeviceToken: Data?
  private var pushRegistrationResults: [FlutterResult] = []
  private var pushRegistrationTimeout: DispatchWorkItem?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // UIScene creates the Flutter engine after launch. Install the notification
    // delegate now; the plugin attaches its channel when that engine is ready.
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    configureStoredFirebase()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureStoredFirebase() {
    guard FirebaseApp.app() == nil,
      let server = UserDefaults.standard.string(forKey: "flutter.accord.push.client_server"), !server.isEmpty,
      let raw = UserDefaults.standard.string(forKey: "flutter.accord.push.client_config"),
      let data = raw.data(using: .utf8),
      let config = try? JSONSerialization.jsonObject(with: data) as? [String: String],
      let appID = config["app_id"], let senderID = config["messaging_sender_id"],
      let apiKey = config["api_key"], let projectID = config["project_id"],
      let bundleID = config["application_id"], bundleID == Bundle.main.bundleIdentifier
    else { return }
    let options = FirebaseOptions(googleAppID: appID, gcmSenderID: senderID)
    options.apiKey = apiKey
    options.projectID = projectID
    options.bundleID = bundleID
    FirebaseApp.configure(options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AccordPushRegistration")
    else { return }
    let channel = FlutterMethodChannel(name: "accord/push_registration", binaryMessenger: registrar.messenger())
    pushChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "register" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.registerPush(result: result)
    }
  }

  private func registerPush(result: @escaping FlutterResult) {
    guard FirebaseApp.app() != nil else {
      result(FlutterError(code: "push_config_firebase_failed", message: "Firebase is not initialized", details: nil))
      return
    }
    // APNs can finish before Flutter plugins or the downloaded Firebase options
    // are ready. Keep that token and bind it after Firebase initialization.
    if let token = apnsDeviceToken {
      Messaging.messaging().apnsToken = token
      result(true)
      return
    }
    pushRegistrationResults.append(result)
    guard pushRegistrationTimeout == nil else { return }
    let timeout = DispatchWorkItem { [weak self] in
      self?.finishPushRegistration(FlutterError(
        code: "push_config_apns_unavailable", message: "APNs registration timed out", details: nil))
    }
    pushRegistrationTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
    UIApplication.shared.registerForRemoteNotifications()
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsDeviceToken = deviceToken
    if FirebaseApp.app() != nil {
      // Let Firebase infer sandbox/production from the signed provisioning
      // profile. A release binary can still carry a development APNs entitlement.
      Messaging.messaging().apnsToken = deviceToken
    }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    if FirebaseApp.app() != nil {
      finishPushRegistration(true)
      pushChannel?.invokeMethod("apnsReady", arguments: nil)
    }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    let nativeError = error as NSError
    let missingEntitlement = nativeError.domain == NSCocoaErrorDomain && nativeError.code == 3000
    finishPushRegistration(FlutterError(
      code: missingEntitlement ? "push_config_apns_entitlement_missing" : "push_config_apns_registration_failed",
      message: nativeError.localizedDescription,
      details: ["domain": nativeError.domain, "code": nativeError.code]))
  }

  private func finishPushRegistration(_ value: Any) {
    pushRegistrationTimeout?.cancel()
    pushRegistrationTimeout = nil
    let results = pushRegistrationResults
    pushRegistrationResults.removeAll()
    for result in results { result(value) }
  }
}
