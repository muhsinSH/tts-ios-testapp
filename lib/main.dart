import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'BacekroundPTTserves.dart';
import 'ScreeenPTT.dart';
import 'login_screen.dart';

Future<void> _requestPermissions() async {
  if (Platform.isAndroid) {
    await Permission.notification.request();
    await Permission.microphone.request();
    await Permission.storage.request();
    await Permission.ignoreBatteryOptimizations.request();
    await Permission.manageExternalStorage.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  await initializeService();



  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: _checkLogin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final isLoggedIn = snapshot.data ?? false;
          return isLoggedIn
              ? FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final prefs = snap.data!;
              final savedDepartment =
                  prefs.getString('department') ?? 'communications';
              final savedChannel =
                  prefs.getString('channel') ?? 'communications';

              return PTTDemo(
                department: savedDepartment,
                initialChannel: savedChannel,
              );
            },
          )
              : LoginScreen();
        },
      ),
    );
  }

  Future<bool> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'خدمة الاتصال PTT',
    description: 'خدمة استقبال الصوت في الخلفية',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  if (Platform.isIOS || Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'خدمة الاتصال PTT',
      initialNotificationContent: 'جاري التشغيل...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final log = preferences.getStringList('log') ?? <String>[];
  log.add(DateTime.now().toIso8601String());
  await preferences.setStringList('log', log);

  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  //

  final backgroundPTTService = BackgroundPTTService();
  await backgroundPTTService.initialize();

  // إرسال تيارات للواجهة (اختياري)
  backgroundPTTService.streamService.audioStream.listen((audioData) {
    service.invoke('audioData', {
      'data': audioData.data,
      'channel': audioData.channel,
      'timestamp': audioData.timestamp.toIso8601String(),
    });
  });

  backgroundPTTService.streamService.statusStream.listen((status) {
    service.invoke('connectionStatus', {
      'connected': status.connected,
      'channel': status.channel,
      'timestamp': status.timestamp.toIso8601String(),
    });
  });

  backgroundPTTService.streamService.isSpeakingStream.listen((isSpeaking) {
    service.invoke('speakingStatus', {
      'isSpeaking': isSpeaking,
      'timestamp': DateTime.now().toIso8601String(),
    });
  });

  // تغيير القناة من الواجهة
  service.on('setChannel').listen((event) async {
    final newChannel = event?['channel']?.toString() ?? '';
    if (newChannel.isEmpty) return;
    await backgroundPTTService.subscribe(newChannel);
  });

  // إيقاف
  service.on('stopService').listen((event) {
    backgroundPTTService.dispose();
    service.stopSelf();
  });
  service.on('setTalkingState').listen((event) {
    final isTalking = event?['isTalking'] ?? false;
    backgroundPTTService.setLocalTalking(isTalking); // استدعاء الدالة التي أضفناها في الخطوة 1
  });
  // ✅ تحديث الإشعار فقط بـ Timer (بدون while(true))
  Timer.periodic(const Duration(seconds: 3), (timer) async {
    final isConnected = backgroundPTTService.isConnected;
    final channelName = backgroundPTTService.currentChannel;

    String content;
    if (!isConnected) {
      content = "في انتظار الاتصال بالخادم...";
    } else if (channelName.isEmpty) {
      content = "متصل بالخادم، لم يتم الاشتراك بأي قناة";
    } else {
      content = "متصل وجاري الاستماع للقناة: $channelName";
    }

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "خدمة الاتصال PTT",
        content: content,
      );
    }

    service.invoke('update', {
      "current_date": DateTime.now().toIso8601String(),
      "connected": isConnected,
      "channel": channelName,
    });
  });
}

