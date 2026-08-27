import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; 
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // ปิดแถบ Debug มุมขวาบน (optional)
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const sound_record(), 
    );
  }
}

class sound_record extends StatefulWidget {
  const sound_record({super.key});

  @override
  State<sound_record> createState() => _sound_recordState();
}

class _sound_recordState extends State<sound_record> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;

  final _audioplayer = AudioPlayer();
  bool isPlaying = false;

  Duration _duration = Duration.zero; // ความยาวไฟล์เสียง
  Duration _position = Duration.zero; // ตำแหน่งเวลา

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      if (kIsWeb) {
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.opus), 
          path: '',
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/my_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), 
          path: path,
        );
      }

      setState(() {
        _isRecording = true;
      });
    }
  }

Future<void> stopRecording() async {
  // หยุดบันทึกและรับ Path/URL ของไฟล์
  final path = await _audioRecorder.stop();
  setState(() {
    _audioPath = path; 
    _isRecording = false;
  });
}

@override
void initState() {
  super.initState();

    _audioplayer.onPlayerStateChanged.listen((state) {
    setState(() {
      isPlaying = (state == PlayerState.playing);
    });

    _audioplayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });

    _audioplayer.onPositionChanged.listen((newPosition){
      setState(() {
        _position = newPosition;
      });
    });

    _audioplayer.onPlayerComplete.listen((_){
      setState(() {
        _position = Duration.zero;
      });
    });

  });
}

  Future<void> playAudio() async {
    if (_audioPath == null) return; // ถ้ายังไม่มีไฟล์ ให้ข้ามไป

    if (isPlaying) {
      await _audioplayer.pause();
    } else {
      // ถ้าหยุดอยู่ ให้เลือกวิธีเปิดฟังตามระบบปฏิบัติการ
      if (kIsWeb) {
        await _audioplayer.play(UrlSource(_audioPath!));
      } else {
        await _audioplayer.play(DeviceFileSource(_audioPath!));
      }
    }
  }

  String formatDuration(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final double maxSeconds = _duration.inSeconds.toDouble();
    final double currentSeconds = _position.inSeconds.toDouble();

    return Scaffold(
      body:Center(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.mic),
            iconSize: 36.0, // Adjust size
            color: _isRecording ? Colors.red : const Color.fromARGB(255, 121, 2, 145), // Adjust color
            onPressed: () {
              if(_isRecording == false){
                startRecording();
              }
              else{
                stopRecording();
              }
            },
          ),
          
          if(_audioPath != null)
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 36.0,
              color: const Color.fromARGB(255, 121, 2, 145),
              onPressed: (){
                playAudio();
              })

              ,Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Slider(
                      // ป้องกันค่า value เกิน max
                      value: currentSeconds.clamp(0.0, maxSeconds > 0 ? maxSeconds : 1.0),
                      min: 0.0,
                      max: maxSeconds > 0 ? maxSeconds : 1.0,
                      activeColor: Colors.blue,
                      inactiveColor: Colors.grey[300],
                      onChanged: (double value) async {
                        final newPosition = Duration(seconds: value.toInt());
                        // สั่งให้เครื่องเล่นข้ามไปยังตำแหน่งที่ลาก
                        await _audioplayer.seek(newPosition);
                      },
                    ),
                    // แสดงตัวเลขเวลา (เวลาปัจจุบัน / ความยาวทั้งหมด)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(_position)),
                        Text(formatDuration(_duration)),
                      ],
                    ),
                  ],
                ),
              ),
            ]
        ),
      ),
    );
  }
}
