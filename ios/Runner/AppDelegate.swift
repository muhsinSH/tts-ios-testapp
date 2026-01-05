import Flutter
import UIKit
import flutter_background_service_ios // add this
import flutter_local_notifications
import AVFoundation


@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
   let audioSession = AVAudioSession.sharedInstance()
    do {
        // ضبط الفئة لتدعم التسجيل والتشغيل مع إلغاء الصدى والبلوتوث والخلفية
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        try audioSession.setActive(true)
     } catch {
        print("Failed to set up audio session: \(error)")
     }
    SwiftFlutterBackgroundServicePlugin.taskIdentifier = "com.imah.tts"
   FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
    GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
