import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AudioRecordModel {
  String id;
  String filePath;
  DateTime timestamp;
  String department; // حقل جديد لاسم القسم
  bool isSavedForever;

  AudioRecordModel({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.department, // مطلوب
    this.isSavedForever = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'timestamp': timestamp.toIso8601String(),
      'department': department,
      'isSavedForever': isSavedForever,
    };
  }

  factory AudioRecordModel.fromMap(Map<String, dynamic> map) {
    return AudioRecordModel(
      id: map['id'],
      filePath: map['filePath'],
      timestamp: DateTime.parse(map['timestamp']),
      department: map['department'] ?? 'عام', // قيمة افتراضية
      isSavedForever: map['isSavedForever'] ?? false,
    );
  }
}

class HistoryService {
  static const String _key = 'ptt_audio_history_v2'; // غيرنا المفتاح لتفادي تضارب البيانات القديمة

  // إضافة سجل جديد مع اسم القسم
  static Future<void> addRecord(String filePath, String departmentName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_key) ?? [];

    final newRecord = AudioRecordModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: filePath,
      timestamp: DateTime.now(),
      department: departmentName,
    );

    history.add(jsonEncode(newRecord.toMap()));
    await prefs.setStringList(_key, history);
  }

  static Future<List<AudioRecordModel>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_key) ?? [];

    List<AudioRecordModel> records = [];
    for (var item in history) {
      try {
        records.add(AudioRecordModel.fromMap(jsonDecode(item)));
      } catch (e) {
        print("Error parsing record: $e");
      }
    }

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  static Future<void> toggleSave(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStr = prefs.getStringList(_key) ?? [];

    List<AudioRecordModel> history = historyStr
        .map((e) => AudioRecordModel.fromMap(jsonDecode(e)))
        .toList();

    final index = history.indexWhere((element) => element.id == id);
    if (index != -1) {
      history[index].isSavedForever = !history[index].isSavedForever;

      List<String> updatedHistory = history
          .map((e) => jsonEncode(e.toMap()))
          .toList();
      await prefs.setStringList(_key, updatedHistory);
    }
  }

  static Future<void> cleanupOldRecords() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStr = prefs.getStringList(_key) ?? [];

    List<AudioRecordModel> history = [];
    try {
      history = historyStr.map((e) => AudioRecordModel.fromMap(jsonDecode(e))).toList();
    } catch (e) { return; }

    final now = DateTime.now();
    List<AudioRecordModel> keptRecords = [];

    for (var record in history) {
      final difference = now.difference(record.timestamp);

      if (difference.inHours >= 24 && !record.isSavedForever) {
        final file = File(record.filePath);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) { print("Error deleting file: $e"); }
        }
      } else {
        keptRecords.add(record);
      }
    }

    List<String> updatedHistory = keptRecords
        .map((e) => jsonEncode(e.toMap()))
        .toList();
    await prefs.setStringList(_key, updatedHistory);
  }

  static Future<void> deleteRecord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyStr = prefs.getStringList(_key) ?? [];

    List<AudioRecordModel> history = historyStr
        .map((e) => AudioRecordModel.fromMap(jsonDecode(e)))
        .toList();

    final index = history.indexWhere((element) => element.id == id);

    if (index != -1) {
      final file = File(history[index].filePath);
      if (await file.exists()) {
        await file.delete();
      }
      history.removeAt(index);
    }

    List<String> updatedHistory = history
        .map((e) => jsonEncode(e.toMap()))
        .toList();
    await prefs.setStringList(_key, updatedHistory);
  }
}