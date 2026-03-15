import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

class AudioStreamService {

  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Uint8List>? _subscription;

 // start recording and convert data into certain format(float32)
  Future<void> start(Function(List<double>) onAudioData) async {

    if (await _recorder.hasPermission()) {

      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );

      _subscription = stream.listen((data) {
        // print(data.length);2048

        final samples = _convertToFloat32(data);

        onAudioData(samples);

      });

    } else {

      print("Microphone permission denied");

    }

  }

  // stop recording
  Future<void> stop() async {

    await _subscription?.cancel();

    await _recorder.stop();

  }

  //function to convert data to float32
  List<double> _convertToFloat32(Uint8List data) {

    final int16Buffer = Int16List.view(data.buffer);

    return int16Buffer.map((e) => e / 32768.0).toList();

  }

}