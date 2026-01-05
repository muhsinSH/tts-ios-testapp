import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:just_audio/just_audio.dart';

import 'PTTStreamService.dart';

class BackgroundPTTService {
  WebSocketChannel? _channel;
  late AudioPlayer _audioPlayer;

  String? _sessionId;
  bool _isConnected = false;

  String _currentChannel = '';
  String _currentDepartment = "عام";

  final PTTStreamService _streamService = PTTStreamService();
  PTTStreamService get streamService => _streamService;

  static const String _serverUrl = 'ws://72.62.150.219:8383/wss';
  static const String _httpUrl = 'http://72.62.150.219:8383';

  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isLocalUserTalking = false;
  bool _pcmReady = false;
  bool _pcmStarted = false;

  BackgroundPTTService() {
    _audioPlayer = AudioPlayer();
  }

  Future<void> initialize() async {
    try {
      await _loadSavedChannel();

      // جهّز PCM مرة واحدة
      await _setupPcm();

      // اتصل
      await _connect();

      // اشترك إذا كان عندنا قناة محفوظة
      if (_currentChannel.isNotEmpty) {
        await subscribe(_currentChannel);
      }
    } catch (e) {
      print('Failed to initialize background PTT service: $e');
      _scheduleReconnect();
    }
  }

  Future<void> _setupPcm() async {
    if (_pcmReady) return;
    await FlutterPcmSound.setup(sampleRate: 16000, channelCount: 1);
    _pcmReady = true;
  }

  void setLocalTalking(bool talking) {
    _isLocalUserTalking = talking;
  }
  Future<void> _loadSavedChannel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedChannel = prefs.getString('channel');
      if (savedChannel != null && savedChannel.isNotEmpty) {
        _currentChannel = savedChannel;
      }

      final savedDepartment = prefs.getString('department');
      if (savedDepartment != null && savedDepartment.isNotEmpty) {
        _currentDepartment = savedDepartment;
      }

      // محاولة استخدام session محفوظة (اختياري)
      final sid = prefs.getString('session_id');
      if (sid != null && sid.isNotEmpty) {
        _sessionId = sid;
      }
    } catch (e) {
      print('Error loading saved channel: $e');
    }
  }

  Future<void> _connect() async {
    try {
      await _closeSocketIfAny();

      // احصل على sessionId من السيرفر إذا غير موجودة
      if (_sessionId == null || _sessionId!.isEmpty) {
        final response = await _httpGet('/login');
        final data = jsonDecode(response);
        _sessionId = data['id']?.toString();

        if (_sessionId == null || _sessionId!.isEmpty) {
          throw Exception("Invalid session id from /login");
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_id', _sessionId!);
      }

      final wsUrl = '$_serverUrl?id=$_sessionId';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
        cancelOnError: true,
      );

      _isConnected = true;
      _streamService.updateStatus(true, _currentChannel);
      _startHeartbeat();

      print('Background service connected to server: $wsUrl');
    } catch (e) {
      print('Background service connection error: $e');
      _isConnected = false;
      _streamService.updateStatus(false, _currentChannel);
      _scheduleReconnect();
    }
  }

  Future<void> subscribe(String channel) async {
    if (channel.isEmpty) return;

    if (!_isConnected) {
      await _connect();
      if (!_isConnected) return;
    }

    try {
      await _httpGet('/subscribe?channel=$channel&id=$_sessionId');
      _currentChannel = channel;
      _streamService.updateStatus(true, channel);
      print('Background service subscribed to channel: $channel');
    } catch (e) {
      print('Background service subscribe error: $e');
    }
  }

  void _handleMessage(dynamic message) {
    if (message is String) {
      _handleTextMessage(message);
    } else if (message is Uint8List) {
      _handleBinaryMessage(message);
    }
  }

  void _handleTextMessage(String message) {
    // print('Background service received text: $message');
    try {
      final data = jsonDecode(message);

      // دعم pong (لو أضفتها في السيرفر)
      if (data is Map && data['type'] == 'pong') return;

      if (data is Map && data['meta'] != null) {
        print('Audio metadata received in background');
      }
    } catch (_) {
      // ليس JSON تجاهل
    }
  }

  Future<void> _handleBinaryMessage(Uint8List data) async {
    if (_isLocalUserTalking) {
      return;
    }
    _streamService.addAudioData(data, _currentChannel, DateTime.now());

    // ✅ اقرأ owner أولاً
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString('audio_owner') ;



    try {
      // تحويل Uint8List إلى Int16List
      final int16List = data.buffer.asInt16List(
        data.offsetInBytes,
        data.length ~/ 2,
      );

      // flutter_pcm_sound يحتاج List<int>
      final pcmArray = PcmArrayInt16.fromList(int16List.toList());

      FlutterPcmSound.feed(pcmArray);



        if (!_pcmStarted ) {
          FlutterPcmSound.start();
          _pcmStarted = true;
        }


    } catch (e) {
      print('Error feeding PCM data: $e');
    }
  }

  void _handleError(dynamic error) {
    print('Background WebSocket error: $error');
    _isConnected = false;
    _streamService.updateStatus(false, _currentChannel);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    print('Background WebSocket disconnected');
    _isConnected = false;
    _streamService.updateStatus(false, _currentChannel);
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_isConnected || _channel == null) return;
      try {
        _channel!.sink.add(jsonEncode({
          "type": "ping",
          "id": _sessionId,
          "channel": _currentChannel,
        }));
      } catch (_) {}
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      if (_isConnected) return;
      print('Background service attempting reconnect...');
      await _connect();
      if (_isConnected && _currentChannel.isNotEmpty) {
        await subscribe(_currentChannel);
      }
    });
  }

  Future<void> _closeSocketIfAny() async {
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<String> _httpGet(String endpoint) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse('$_httpUrl$endpoint'));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('HTTP request failed with status: ${response.statusCode}');
      }

      return await response.transform(utf8.decoder).join();
    } finally {
      httpClient.close(force: true);
    }
  }

  bool get isConnected => _isConnected;
  String get currentChannel => _currentChannel;

  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();

    _closeSocketIfAny();
    _streamService.dispose();
    _tempFilesClear();
  }

  void _tempFilesClear() {
    // إذا عندك ملفات مؤقتة فعلاً امسحها
    // _tempFiles.clear();
  }
}








// import 'dart:async';
// import 'dart:typed_data';
// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'PTTStreamService.dart';
//
// class BackgroundPTTService {
//   WebSocketChannel? _channel;
//   String? _sessionId;
//   bool _isConnected = false;
//   String _currentChannel = '';
//   String _currentDepartment = "عام";
//
//   final PTTStreamService _streamService = PTTStreamService();
//   PTTStreamService get streamService => _streamService;
//
//   static const String _serverUrl = 'ws://72.62.150.219:8383/wss';
//   static const String _httpUrl = 'http://72.62.150.219:8383';
//
//   Timer? _reconnectTimer;
//   Timer? _pingTimer;
//   bool _isLocalUserTalking = false;
//   bool _pcmReady = false;
//   bool _pcmStarted = false;
//
//   BackgroundPTTService();
//
//   Future<void> initialize() async {
//     try {
//       await _loadSavedChannel();
//       await _setupPcm(); // تهيئة أولية
//       await _connect();
//       if (_currentChannel.isNotEmpty) {
//         await subscribe(_currentChannel);
//       }
//     } catch (e) {
//       print('Background PTT Init Error: $e');
//       _scheduleReconnect();
//     }
//   }
//
//   Future<void> _setupPcm() async {
//     try {
//       await FlutterPcmSound.setup(sampleRate: 16000, channelCount: 1);
//       _pcmReady = true;
//       print('Background PCM Ready');
//     } catch (e) {
//       print('Background PCM Setup Failed: $e');
//       _pcmReady = false;
//     }
//   }
//
//   void setLocalTalking(bool talking) {
//     _isLocalUserTalking = talking;
//     // عند التحدث محلياً، يفضل إيقاف تشغيل PCM لتوفير الموارد ومنع الصدى
//     if (talking && _pcmStarted) {
//       // FlutterPcmSound.stop(); // اختياري
//     }
//   }
//
//   Future<void> _loadSavedChannel() async {
//     final prefs = await SharedPreferences.getInstance();
//     _currentChannel = prefs.getString('channel') ?? '';
//     _currentDepartment = prefs.getString('department') ?? 'عام';
//     _sessionId = prefs.getString('session_id');
//   }
//
//   Future<void> _connect() async {
//     try {
//       await _closeSocketIfAny();
//       if (_sessionId == null) {
//         final response = await _httpGet('/login');
//         final data = jsonDecode(response);
//         _sessionId = data['id']?.toString();
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('session_id', _sessionId!);
//       }
//
//       _channel = WebSocketChannel.connect(Uri.parse('$_serverUrl?id=$_sessionId'));
//       _channel!.stream.listen(
//         _handleMessage,
//         onError: _handleError,
//         onDone: _handleDisconnect,
//         cancelOnError: true,
//       );
//
//       _isConnected = true;
//       _streamService.updateStatus(true, _currentChannel);
//       _startHeartbeat();
//       print('Background service connected');
//     } catch (e) {
//       _isConnected = false;
//       _scheduleReconnect();
//     }
//   }
//
//   Future<void> subscribe(String channel) async {
//     if (channel.isEmpty || !_isConnected) return;
//     try {
//       await _httpGet('/subscribe?channel=$channel&id=$_sessionId');
//       _currentChannel = channel;
//       _streamService.updateStatus(true, channel);
//     } catch (e) {}
//   }
//
//   void _handleMessage(dynamic message) {
//     if (message is String) {
//       _handleTextMessage(message);
//     } else if (message is Uint8List) {
//       _handleBinaryMessage(message);
//     }
//   }
//
//   void _handleTextMessage(String message) {
//     try {
//       final data = jsonDecode(message);
//       if (data['meta'] != null) print('Meta received in background');
//     } catch (_) {}
//   }
//
//     Future<void> _handleBinaryMessage(Uint8List data) async {
//     if (_isLocalUserTalking) {
//       return;
//     }
//     _streamService.addAudioData(data, _currentChannel, DateTime.now());
//
//     // ✅ اقرأ owner أولاً
//     final prefs = await SharedPreferences.getInstance();
//     final owner = prefs.getString('audio_owner') ;
//
//
//
//     try {
//       // تحويل Uint8List إلى Int16List
//       final int16List = data.buffer.asInt16List(
//         data.offsetInBytes,
//         data.length ~/ 2,
//       );
//
//       // flutter_pcm_sound يحتاج List<int>
//       final pcmArray = PcmArrayInt16.fromList(int16List.toList());
//
//       FlutterPcmSound.feed(pcmArray);
//
//
//
//         if (!_pcmStarted ) {
//           FlutterPcmSound.start();
//           _pcmStarted = true;
//         }
//
//
//     } catch (e) {
//       print('Error feeding PCM data: $e');
//     }
//   }
//   // Future<void> _handleBinaryMessage(Uint8List data) async {
//   //   // منع التشغيل أثناء تحدث المستخدم المحلي
//   //   if (_isLocalUserTalking) return;
//   //
//   //   _streamService.addAudioData(data, _currentChannel, DateTime.now());
//   //
//   //   try {
//   //     // التأكد من التهيئة داخل Isolate الخلفية (حل خطأ Setup)
//   //     if (!_pcmReady) {
//   //       await _setupPcm();
//   //     }
//   //
//   //     final int16List = data.buffer.asInt16List(data.offsetInBytes, data.length ~/ 2);
//   //     final pcmArray = PcmArrayInt16.fromList(int16List.toList());
//   //
//   //     await FlutterPcmSound.feed(pcmArray);
//   //
//   //     if (!_pcmStarted) {
//   //       await FlutterPcmSound.start();
//   //       _pcmStarted = true;
//   //       print("Background PCM Started");
//   //     }
//   //   } catch (e) {
//   //     print('Background Feed Error: $e');
//   //     if (e.toString().contains("setup")) _pcmReady = false;
//   //   }
//   // }
//
//   void _handleError(dynamic error) => _handleDisconnect();
//
//   void _handleDisconnect() {
//     _isConnected = false;
//     _streamService.updateStatus(false, _currentChannel);
//     _scheduleReconnect();
//   }
//
//   void _startHeartbeat() {
//     _pingTimer?.cancel();
//     _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
//       if (_isConnected) {
//         _channel!.sink.add(jsonEncode({"type": "ping", "id": _sessionId, "channel": _currentChannel}));
//       }
//     });
//   }
//
//   void _scheduleReconnect() {
//     _reconnectTimer?.cancel();
//     _reconnectTimer = Timer(const Duration(seconds: 5), () => _connect());
//   }
//
//   Future<void> _closeSocketIfAny() async {
//     _channel?.sink.close();
//     _channel = null;
//   }
//
//   Future<String> _httpGet(String endpoint) async {
//     final httpClient = HttpClient();
//     final request = await httpClient.getUrl(Uri.parse('$_httpUrl$endpoint'));
//     final response = await request.close();
//     return await response.transform(utf8.decoder).join();
//   }
//
//   bool get isConnected => _isConnected;
//   String get currentChannel => _currentChannel;
//
//   void dispose() {
//     _pingTimer?.cancel();
//     _reconnectTimer?.cancel();
//     _closeSocketIfAny();
//     _streamService.dispose();
//   }
// }