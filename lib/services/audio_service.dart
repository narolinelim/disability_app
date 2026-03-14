import 'dart:typed_data';
import 'package:record/record.dart';

import 'decibel_detector.dart';
import 'sound_classifier.dart';

class AudioService {

  final AudioRecorder _recorder = AudioRecorder();

  final SoundClassifier classifier;

  bool isRecording = false;

  AudioService(this.classifier);

  Future<void> startRecording() async {

    if (!await _recorder.hasPermission()) {
      print("Microphone permission denied");
      return;
    }

    print("Recording started...");

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    isRecording = true;

    stream.listen((Uint8List data) {

      // ------------------------
      // PCM16 → double buffer
      // ------------------------

      final int16Buffer = data.buffer.asInt16List();

      List<double> buffer =
      int16Buffer.map((e) => e / 32768.0).toList();

      // ------------------------
      // 计算分贝
      // ------------------------

      double db = DecibelDetector.calculateDb(buffer);

      bool alert = DecibelDetector.isDanger(db);

      if (alert) {

        String label = classifier.classify(buffer);

        print(
            "Got buffer length: ${buffer.length}, dB: ${db.toStringAsFixed(2)}, Alert: $alert, Label: $label");

      } else {

        print(
            "Got buffer length: ${buffer.length}, dB: ${db.toStringAsFixed(2)}, Alert: $alert");

      }

    });

  }

  Future<void> stopRecording() async {

    await _recorder.stop();

    isRecording = false;

    print("Recording stopped");

  }

}