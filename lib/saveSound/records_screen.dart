import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'history_service.dart';

class RecordsScreen extends StatefulWidget {
  @override
  _RecordsScreenState createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<AudioRecordModel> _records = [];
  bool _isLoading = true;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ar', null).then((_) {
      _loadRecords();
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _currentlyPlayingId = null;
        });
      }
    });
  }

  // -----------------------------
  // تحديد هل التسجيل مستلم أم مرسل
  // -----------------------------
  bool _isIncoming(AudioRecordModel record) {
    final name = File(record.filePath).uri.pathSegments.last;
    return name.startsWith('IN_'); // المستلم
  }

  Future<void> _loadRecords() async {
    await HistoryService.cleanupOldRecords();
    final records = await HistoryService.getRecords();
    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSave(String id) async {
    await HistoryService.toggleSave(id);
    _loadRecords();
  }

  Future<void> _deleteRecord(String id) async {
    if (_currentlyPlayingId == id) {
      await _audioPlayer.stop();
      _currentlyPlayingId = null;
    }
    await HistoryService.deleteRecord(id);
    _loadRecords();
  }

  Future<void> _playRecord(AudioRecordModel record) async {
    try {
      final file = File(record.filePath);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "الملف الصوتي غير موجود:\n${record.filePath}",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_currentlyPlayingId == record.id) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingId = null);
      } else {
        await _audioPlayer.setAudioSource(
          AudioSource.uri(Uri.file(record.filePath)),
        );
        await _audioPlayer.play();
        setState(() => _currentlyPlayingId = record.id);
      }
    } catch (e) {
      print("Error playing audio: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("حدث خطأ أثناء التشغيل")),
      );
    }
  }

  String _formatDate(DateTime date) {
    try {
      return DateFormat('EEEE, yyyy/MM/dd - hh:mm a', 'ar').format(date);
    } catch (_) {
      return DateFormat('yyyy/MM/dd - hh:mm a').format(date);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('سجل الإرسال والاستلام'),
        backgroundColor: Colors.grey[900],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      )
          : _records.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history,
                size: 80, color: Colors.grey[800]),
            const SizedBox(height: 10),
            const Text(
              "لا توجد تسجيلات",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          final isPlaying = _currentlyPlayingId == record.id;
          final incoming = _isIncoming(record);

          return Dismissible(
            key: Key(record.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (_) async {
              return !record.isSavedForever;
            },
            onDismissed: (_) => _deleteRecord(record.id),
            child: Card(
              color: Colors.grey[850],
              margin: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPlaying
                      ? Colors.orange
                      : incoming
                      ? Colors.blueGrey
                      : Colors.green,
                  child: IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.stop
                          : Icons.play_arrow,
                    ),
                    color: Colors.white,
                    onPressed: () => _playRecord(record),
                  ),
                ),
                title: Text(
                  "${incoming ? '📥 مستلم' : '📤 مرسل'} - ${record.department}\n${_formatDate(record.timestamp)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                isThreeLine: true,
                subtitle: Padding(
                  padding:
                  const EdgeInsets.only(top: 4.0),
                  child: Text(
                    record.isSavedForever
                        ? "محفوظ (لن يُحذف)"
                        : "سيُحذف خلال 24 ساعة",
                    style: TextStyle(
                      color: record.isSavedForever
                          ? Colors.greenAccent
                          : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    record.isSavedForever
                        ? Icons.lock
                        : Icons.lock_open,
                    color: record.isSavedForever
                        ? Colors.greenAccent
                        : Colors.grey,
                  ),
                  onPressed: () => _toggleSave(record.id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
