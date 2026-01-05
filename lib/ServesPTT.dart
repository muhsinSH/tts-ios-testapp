//
// import 'dart:async';
// import 'dart:typed_data';
// import 'dart:io';
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'PTTStreamService.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
// class PTTService {
//   late WebSocketChannel _channel;
//   late FlutterSoundRecorder _mRecorder;
//   late FlutterSoundPlayer _mPlayer;
//   String? _sessionId;
//   bool _isConnected = false;
//   bool _isRecording = false;
//   bool _isPlaying = false;
//   String _currentChannel = "عام";
//
//   final PTTStreamService _streamService = PTTStreamService();
//
//   StreamController<Uint8List>? _recordingStreamController;
//   StreamSubscription<Uint8List>? _recordingSubscription;
//
//   static const String _serverUrl = 'ws://72.62.150.219:8383/wss';
//   static const String _httpUrl = 'http://72.62.150.219:8383';
//
//   static const int _sampleRate = 16000;
//   static const int _numChannels = 1;
//   static const Codec _defaultCodec = Codec.pcm16WAV;
//
//   double _dbLevel = 0.0;
//   Timer? _dbLevelTimer;
//
//   Function(Uint8List)? _audioCallback;
//
//   PTTService() {
//     _mRecorder = FlutterSoundRecorder();
//     _mPlayer = FlutterSoundPlayer();
//   }
//
//   PTTStreamService get streamService => _streamService;
//
//   void setAudioCallback(Function(Uint8List) callback) {
//     _audioCallback = callback;
//   }
//
//   Future<void> initialize() async {
//     try {
//       // 1. طلب الإذن أولاً وقبل كل شيء
//       var status = await Permission.microphone.request();
//       if (!status.isGranted) {
//         print("المستخدم رفض صلاحية الميكروفون");
//         return;
//       }
//
//       // 2. إعداد جلسة الصوت لنظام iOS بشكل يدوي لتفادي خطأ Category
//       if (Platform.isIOS) {
//         await _mRecorder.openRecorder();
//         // ضبط الإعدادات لتسمح بالتسجيل والتشغيل معاً وفي الخلفية
//         await _mRecorder.setSubscriptionDuration(const Duration(milliseconds: 10));
//       } else {
//         await _mRecorder.openRecorder();
//       }
//
//       await _mPlayer.openPlayer();
//
//       // 3. تهيئة مشغل PCM
//       await FlutterPcmSound.setup(sampleRate: 16000, channelCount: 1);
//
//       print('PTTService initialized successfully');
//     } catch (e) {
//       print('Error during PTT init: $e');
//       rethrow;
//     }
//   }
//   Future<void> connect() async {
//     try {
//       _streamService.updateStatus(false, 'جاري الاتصال...');
//
//       final response = await _httpGet('/login');
//       final data = jsonDecode(response);
//       _sessionId = data['id'];
//
//       final wsUrl = '$_serverUrl?id=$_sessionId';
//       _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
//
//       _channel.stream.listen(
//         _handleMessage,
//         onError: _handleError,
//         onDone: _handleDisconnect,
//       );
//
//       _isConnected = true;
//       _streamService.updateStatus(true, _currentChannel);
//       _streamService.updateSpeakingStatus(false);
//
//       print('Connected to server with session ID: $_sessionId');
//
//     } catch (e) {
//       print('Connection error: $e');
//       _streamService.addMessage('خطأ في الاتصال: $e');
//       throw Exception('Failed to connect: $e');
//     }
//   }
//
//   Future<void> subscribe(String channel) async {
//     if (!_isConnected) throw Exception('Not connected');
//     try {
//       await _httpGet('/subscribe?channel=$channel&id=$_sessionId');
//       _currentChannel = channel;
//       _streamService.updateStatus(true, channel);
//       _streamService.addMessage('تم الاشتراك في القناة: $channel');
//       print('Subscribed to channel: $channel');
//     } catch (e) {
//       print('Subscribe error: $e');
//       _streamService.addMessage('خطأ في الاشتراك: $e');
//       throw Exception('Subscribe failed: $e');
//     }
//   }
//
//   Future<void> startRecording() async {
//     if (!_isConnected) return;
//     if (_isRecording) return;
//
//
//     try {
//       FlutterBackgroundService().invoke('setTalkingState', {'isTalking': true});
//       _recordingStreamController = StreamController<Uint8List>();
//
//       _recordingSubscription = _recordingStreamController!.stream.listen(
//             (Uint8List buffer) {
//           _sendAudioChunk(buffer);
//         },
//         onError: (error) {
//           print('Error in recording stream: $error');
//         },
//       );
//
//       await _mRecorder.startRecorder(
//         toStream: _recordingStreamController!.sink,
//         codec: _defaultCodec,
//         numChannels: _numChannels,
//         sampleRate: _sampleRate,
//         audioSource: AudioSource.voice_communication,
//         bufferSize: 1024,
//       );
//
//       _isRecording = true;
//       _channel.sink.add('started');
//
//       _startDbLevelMonitoring();
//
//       print('Recording started with stream');
//
//     } catch (e) {
//       print('Recording start error: $e');
//       await _cleanupRecording();
//       throw Exception('Failed to start recording: $e');
//     }
//   }
//
//   void _startDbLevelMonitoring() {
//     _dbLevelTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
//       if (_isRecording) {
//         try {
//           // الحصول على مستوى الصوت
//           _mRecorder.onProgress?.listen((e) {
//             _dbLevel = e.decibels ?? 0.0;
//             _streamService.updateDbLevel(_dbLevel);
//           });
//         } catch (e) {
//           print('Error monitoring db level: $e');
//         }
//       }
//     });
//   }
//
//   Future<void> stopRecording() async {
//     if (!_isRecording) return;
//
//     try {
//       await _mRecorder.stopRecorder();
//       _channel.sink.add('stopped');
//       _isRecording = false;
//
//       await _cleanupRecording();
//
//       print('Recording stopped');
//       FlutterBackgroundService().invoke('setTalkingState', {'isTalking': false});
//     } catch (e) {
//       print('Recording stop error: $e');
//       await _cleanupRecording();
//       throw Exception('Failed to stop recording: $e');
//     }
//   }
//
//   Future<void> _cleanupRecording() async {
//     _dbLevelTimer?.cancel();
//     _dbLevelTimer = null;
//
//     await _recordingSubscription?.cancel();
//     _recordingSubscription = null;
//
//     await _recordingStreamController?.close();
//     _recordingStreamController = null;
//   }
//
//   void _sendAudioChunk(Uint8List audioData) {
//     if (!_isConnected || audioData.isEmpty) return;
//
//     try {
//       final metadata = {
//         'meta': {
//           'encoding': 16,
//           'sampleRate': _sampleRate,
//           'channels': _numChannels,
//           'bufferSize': 1024 ,
//           'type': 'pcm',
//           'timestamp': DateTime.now().millisecondsSinceEpoch,
//           'chunk': true
//         }
//       };
//
//       _channel.sink.add(jsonEncode(metadata));
//       _channel.sink.add(audioData);
//
//     } catch (e) {
//       print('Error sending audio chunk: $e');
//     }
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
//     _streamService.addMessage(message);
//
//     switch (message) {
//       case 'started':
//         print('Server started audio transmission');
//         _streamService.updateSpeakingStatus(true);
//         break;
//       case 'stopped':
//         print('Server stopped audio transmission');
//         _streamService.updateSpeakingStatus(false);
//
//         break;
//       case 'ping':
//         _channel.sink.add('pong');
//         break;
//       default:
//         _handleJsonMessage(message);
//     }
//   }
//
//   void _handleJsonMessage(String message) {
//     try {
//       final data = jsonDecode(message);
//       if (data['meta'] != null) {
//         final meta = data['meta'];
//         print('Received audio metadata: $meta');
//       }
//     } catch (e) {
//       print('Error parsing JSON: $e');
//     }
//   }
//
//   void _handleBinaryMessage(Uint8List data) {
//     _streamService.addAudioData(data, _currentChannel, DateTime.now());
//
//     if (_audioCallback != null) {
//       _audioCallback!(data);
//     }
//
//     try {
//       // 1. تحويل Uint8List إلى Int16List (بايتين لكل عينة)
//       final int16List = data.buffer.asInt16List(data.offsetInBytes, data.length ~/ 2);
//
//       // 2. تحويل Int16List إلى النوع الذي تطلبه المكتبة PcmArrayInt16
//       final pcmArray = PcmArrayInt16.fromList(int16List);
//
//       // 3. إرسال البيانات للمشغل
//       FlutterPcmSound.feed(pcmArray);
//
//       // 4. التأكد من بدء التشغيل
//       if (!_isPlaying) {
//         FlutterPcmSound.start();
//         _isPlaying = true;
//       }
//     } catch (e) {
//       print('Error feeding PCM data: $e');
//     }
//   }
//
//
//
//
//   void _handleError(dynamic error) {
//     print('WebSocket error: $error');
//     _isConnected = false;
//     _streamService.updateStatus(false, 'خطأ في الاتصال');
//   }
//
//   void _handleDisconnect() {
//     print('WebSocket disconnected');
//     _isConnected = false;
//     _streamService.updateStatus(false, 'تم قطع الاتصال');
//
//     Timer(Duration(seconds: 3), () {
//       if (!_isConnected) {
//         print('Attempting to reconnect...');
//         connect().catchError((e) {
//           print('Reconnection failed: $e');
//         });
//       }
//     });
//   }
//
//   Future<String> _httpGet(String endpoint) async {
//     try {
//       final httpClient = HttpClient();
//       final request = await httpClient.getUrl(Uri.parse('$_httpUrl$endpoint'));
//       final response = await request.close();
//
//       if (response.statusCode != 200) {
//         throw Exception('HTTP request failed with status: ${response.statusCode}');
//       }
//
//       return await response.transform(utf8.decoder).join();
//     } catch (e) {
//       print('HTTP request error for $endpoint: $e');
//       if (endpoint.contains('/login')) {
//         return '{"id": "flutter_${DateTime.now().millisecondsSinceEpoch}"}';
//       } else {
//         return '{"status": "success"}';
//       }
//     }
//   }
//
//
//
//   double get dbLevel => _dbLevel;
//   bool get isRecording => _isRecording;
//   bool get isConnected => _isConnected;
//   bool get isPlaying => _isPlaying;
//   String get currentChannel => _currentChannel;
//
//   void dispose() {
//     print('Disposing PTTService...');
//
//     if (_isRecording) {
//       stopRecording();
//     }
//
//     if (_isPlaying) {
//       _mPlayer.stopPlayer();
//     }
//
//     _channel.sink.close();
//     _mRecorder.closeRecorder();
//     _mPlayer.closePlayer();
//     _streamService.dispose();
//
//     _dbLevelTimer?.cancel();
//     _recordingSubscription?.cancel();
//
//     print('PTTService disposed');
//   }
// }

import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'PTTStreamService.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

class PTTService {
  late WebSocketChannel _channel;
  late FlutterSoundRecorder _mRecorder;
  late FlutterSoundPlayer _mPlayer;
  String? _sessionId;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  String _currentChannel = "عام";
  bool _isPcmInitialized = false; // متغير حيوي لمنع الخطأ
  final PTTStreamService _streamService = PTTStreamService();

  StreamController<Uint8List>? _recordingStreamController;
  StreamSubscription<Uint8List>? _recordingSubscription;

  static const String _serverUrl = 'ws://72.62.150.219:8383/wss';
  static const String _httpUrl = 'http://72.62.150.219:8383';

  static const int _sampleRate = 16000;
  static const int _numChannels = 1;
  static const Codec _defaultCodec = Codec.pcm16WAV;

  double _dbLevel = 0.0;
  Timer? _dbLevelTimer;
  bool _recorderOpened = false;

  Function(Uint8List)? _audioCallback;

  PTTService() {
    _mRecorder = FlutterSoundRecorder();
    _mPlayer = FlutterSoundPlayer();
  }

  PTTStreamService get streamService => _streamService;

  void setAudioCallback(Function(Uint8List) callback) {
    _audioCallback = callback;
  }
  Future<void> initialize() async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) return;

    if (!_recorderOpened) {
      await _mRecorder.openRecorder();
      _recorderOpened = true;
    }

    await _mRecorder.setSubscriptionDuration(
      const Duration(milliseconds: 10),
    );

    await _mPlayer.openPlayer();

    await _setupPcm();
  }

  // Future<void> initialize() async {
  //   try {
  //     var status = await Permission.microphone.request();
  //     if (!status.isGranted) return;
  //
  //     // التأكد من إغلاق أي جلسة سابقة قبل الفتح
  //     if (_mRecorder.isRecording) await _mRecorder.stopRecorder();
  //
  //     // فتح المسجل والمشغل
  //     await _mRecorder.openRecorder();
  //     await _mPlayer.openPlayer();
  //
  //     // إعداد PCM
  //     await _setupPcm();
  //
  //     print('PTTService initialized successfully');
  //   } catch (e) {
  //     print('Error during PTT init: $e');
  //   }
  // }
  //
  Future<void> _setupPcm() async {
    try {
      await FlutterPcmSound.setup(sampleRate: _sampleRate, channelCount: _numChannels);
      await FlutterPcmSound.setFeedThreshold(100); // لتقليل التأخير
      _isPcmInitialized = true;
      print('PCM Sound Setup Success');
    } catch (e) {
      _isPcmInitialized = false;
      print('PCM Sound Setup Failed: $e');
    }
  }

  Future<void> connect() async {
    try {
      _streamService.updateStatus(false, 'جاري الاتصال...');
      final response = await _httpGet('/login');
      final data = jsonDecode(response);
      _sessionId = data['id'];

      final wsUrl = '$_serverUrl?id=$_sessionId';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _streamService.updateStatus(true, _currentChannel);
    } catch (e) {
      _streamService.addMessage('خطأ في الاتصال: $e');
    }
  }


  Future<void> subscribe(String channel) async {
    if (!_isConnected) throw Exception('Not connected');
    try {
      await _httpGet('/subscribe?channel=$channel&id=$_sessionId');
      _currentChannel = channel;
      _streamService.updateStatus(true, channel);
      _streamService.addMessage('تم الاشتراك في القناة: $channel');
      print('Subscribed to channel: $channel');
    } catch (e) {
      print('Subscribe error: $e');
      _streamService.addMessage('خطأ في الاشتراك: $e');
      throw Exception('Subscribe failed: $e');
    }
  }
  Future<void> startRecording() async {
    if (!_isConnected || _isRecording) return;

    if (!_recorderOpened) {
      await _mRecorder.openRecorder();
      _recorderOpened = true;
    }
      try {
        FlutterBackgroundService().invoke('setTalkingState', {'isTalking': true});

        _recordingStreamController = StreamController<Uint8List>();
    _recordingSubscription =
        _recordingStreamController!.stream.listen(_sendAudioChunk);

    await _mRecorder.startRecorder(
      toStream: _recordingStreamController!.sink,
      codec: Codec.pcm16,
      numChannels: _numChannels,
      sampleRate: _sampleRate,
    );

    _isRecording = true;
    _channel.sink.add('started');

      } catch (e) {
        print('Recording start error: $e');
        await _cleanupRecording();
      }
  }

  // Future<void> startRecording() async {
  //   if (!_isConnected || _isRecording) return;
  //   try {
  //     _recordingStreamController = StreamController<Uint8List>();
  //     _recordingSubscription = _recordingStreamController!.stream.listen((buffer) {
  //       _sendAudioChunk(buffer);
  //     });
  //
  //     await _mRecorder.startRecorder(
  //       toStream: _recordingStreamController!.sink,
  //       codec: Codec.pcm16, // استخدام الخام لتقليل المعالجة
  //       numChannels: _numChannels,
  //       sampleRate: _sampleRate,
  //     );
  //
  //     _isRecording = true;
  //     _channel.sink.add('started');
  //   } catch (e) {
  //     print('Recording start error: $e');
  //     await _cleanupRecording();
  //   }
  // }

  void _handleMessage(dynamic message) {
    if (message is String) {
      _handleTextMessage(message);
    } else if (message is Uint8List) {
      _handleBinaryMessage(message);
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    try {
      if (_mRecorder.isRecording) {
        await _mRecorder.stopRecorder();
      FlutterBackgroundService().invoke('setTalkingState', {'isTalking': false});

      }

    } catch (_) {}

    _isRecording = false;
    _channel.sink.add('stopped');

    await _cleanupRecording();
  }

  // Future<void> stopRecording() async {
  //   if (!_isRecording) return;
  //
  //   try {
  //     await _mRecorder.stopRecorder();
  //     _channel.sink.add('stopped');
  //     _isRecording = false;
  //
  //     await _cleanupRecording();
  //
  //     print('Recording stopped');
  //     // FlutterBackgroundService().invoke('setTalkingState', {'isTalking': false});
  //   } catch (e) {
  //     print('Recording stop error: $e');
  //     await _cleanupRecording();
  //   }
  // }

  Future<void> _cleanupRecording() async {
    _dbLevelTimer?.cancel();
    _dbLevelTimer = null;
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;
    await _recordingStreamController?.close();
    _recordingStreamController = null;
  }

  void _sendAudioChunk(Uint8List audioData) {
    if (!_isConnected || audioData.isEmpty) return;
    try {
      final metadata = {
        'meta': {
          'encoding': 16,
          'sampleRate': _sampleRate,
          'channels': _numChannels,
          'bufferSize': 1024,
          'type': 'pcm',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'chunk': true
        }
      };
      _channel.sink.add(jsonEncode(metadata));
      _channel.sink.add(audioData);
    } catch (e) {
      print('Error sending audio chunk: $e');
    }
  }



  void _handleTextMessage(String message) {
    _streamService.addMessage(message);
    switch (message) {
      case 'started':
        _streamService.updateSpeakingStatus(true);
        break;
      case 'stopped':
        _streamService.updateSpeakingStatus(false);
        break;
      case 'ping':
        _channel.sink.add('pong');
        break;
      default:
        _handleJsonMessage(message);
    }
  }

  void _handleJsonMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data['meta'] != null) {
        print('Received audio metadata: ${data['meta']}');
      }
    } catch (e) {}
  }

  void _handleBinaryMessage(Uint8List data) async {
    // تحديث الواجهة والـ Callback
    _streamService.addAudioData(data, _currentChannel, DateTime.now());
    if (_audioCallback != null) _audioCallback!(data);

    // التحقق من التهيئة قبل التشغيل لمنع الـ PlatformException
    if (!_isPcmInitialized) {
      await _setupPcm();
    }

    try {
      if (_isPcmInitialized) {
        final int16List = data.buffer.asInt16List(data.offsetInBytes, data.length ~/ 2);
        final pcmArray = PcmArrayInt16.fromList(int16List);

        await FlutterPcmSound.feed(pcmArray);

        // التشغيل إذا لم يكن قد بدأ بعد
        // ملحوظة: في pcm_sound يفضل مناداة start مرة واحدة فقط
        FlutterPcmSound.start();
      }
    } catch (e) {
      print('Error feeding PCM: $e');
    }
  }

  void _handleError(dynamic error) {
    _isConnected = false;
    _streamService.updateStatus(false, 'خطأ في الاتصال');
  }

  void _handleDisconnect() {
    _isConnected = false;
    _streamService.updateStatus(false, 'تم قطع الاتصال');
    Timer(Duration(seconds: 3), () {
      if (!_isConnected) connect().catchError((e) {});
    });
  }

  Future<String> _httpGet(String endpoint) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse('$_httpUrl$endpoint'));
      final response = await request.close();
      return await response.transform(utf8.decoder).join();
    } catch (e) {
      if (endpoint.contains('/login')) {
        return '{"id": "flutter_${DateTime.now().millisecondsSinceEpoch}"}';
      }
      return '{"status": "success"}';
    }
  }

  // void dispose() {
  //   if (_isRecording) stopRecording();
  //   _channel.sink.close();
  //   _isPcmInitialized = false;
  //   FlutterPcmSound.release(); // تحرير الموارد
  //   _mRecorder.closeRecorder();
  //   _mPlayer.closePlayer();
  //   _streamService.dispose();
  //   _dbLevelTimer?.cancel();
  //   _recordingSubscription?.cancel();
  // }
  void dispose() {
    if (_isRecording) {
      stopRecording();
    }

    if (_recorderOpened) {
      _mRecorder.closeRecorder();
      _recorderOpened = false;
    }

    // _channel.sink.close();
    // FlutterPcmSound.release();
    // _mPlayer.closePlayer();
    // _streamService.dispose();
      _channel.sink.close();
      _isPcmInitialized = false;
      FlutterPcmSound.release(); // تحرير الموارد
      _mPlayer.closePlayer();
      _streamService.dispose();
      _dbLevelTimer?.cancel();
      _recordingSubscription?.cancel();
  }

}



