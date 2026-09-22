import Flutter
import UIKit

private let blockingChannelName = "com.motify.app/blocking"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Phase 3 (see project README roadmap, needs a Mac/Codemagic to build
  // and test): register a FlutterMethodChannel named `blockingChannelName`
  // here once the Family Controls entitlement is granted, and implement:
  //   - getInstalledApps   -> FamilyActivityPicker selection (opaque tokens, not bundle ids)
  //   - hasBlockingPermission   -> AuthorizationCenter.shared.authorizationStatus
  //   - requestBlockingPermission -> AuthorizationCenter.shared.requestAuthorization
  //   - syncLockState -> ManagedSettingsStore + DeviceActivityMonitor schedules
  // Left unimplemented for now since this file can't be compiled/verified
  // on a non-macOS dev machine.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
