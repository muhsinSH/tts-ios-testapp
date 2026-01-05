import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class PTTStreamService {
  final StreamController<AudioData> _audioStreamController =
  StreamController<AudioData>.broadcast();

  final StreamController<ConnectionStatus> _statusStreamController =
  StreamController<ConnectionStatus>.broadcast();

  final StreamController<String> _messageStreamController =
  StreamController<String>.broadcast();

  final StreamController<bool> _isSpeakingController =
  StreamController<bool>.broadcast();

  final StreamController<double> _dbLevelController =
  StreamController<double>.broadcast();

  Stream<AudioData> get audioStream => _audioStreamController.stream;
  Stream<ConnectionStatus> get statusStream => _statusStreamController.stream;
  Stream<String> get messageStream => _messageStreamController.stream;
  Stream<bool> get isSpeakingStream => _isSpeakingController.stream;
  Stream<double> get dbLevelStream => _dbLevelController.stream;

  void addAudioData(Uint8List data, String channel, DateTime timestamp) {
    if (!_audioStreamController.isClosed) {
      _audioStreamController.add(AudioData(
        data: data,
        channel: channel,
        timestamp: timestamp,
      ));
    }
  }

  void updateStatus(bool connected, String channel) {
    if (!_statusStreamController.isClosed) {
      _statusStreamController.add(ConnectionStatus(
        connected: connected,
        channel: channel,
        timestamp: DateTime.now(),
      ));
    }
  }

  void addMessage(String message) {
    if (!_messageStreamController.isClosed) {
      _messageStreamController.add(message);
    }
  }

  void updateSpeakingStatus(bool isSpeaking) {
    if (!_isSpeakingController.isClosed) {
      _isSpeakingController.add(isSpeaking);
    }
  }

  void updateDbLevel(double dbLevel) {
    if (!_dbLevelController.isClosed) {
      _dbLevelController.add(dbLevel);
    }
  }

  void dispose() {
    _audioStreamController.close();
    _statusStreamController.close();
    _messageStreamController.close();
    _isSpeakingController.close();
    _dbLevelController.close();
  }
}

class AudioData {
  final Uint8List data;
  final String channel;
  final DateTime timestamp;

  AudioData({
    required this.data,
    required this.channel,
    required this.timestamp,
  });
}

class ConnectionStatus {
  final bool connected;
  final String channel;
  final DateTime timestamp;

  ConnectionStatus({
    required this.connected,
    required this.channel,
    required this.timestamp,
  });
}