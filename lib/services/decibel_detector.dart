import 'dart:math';

class DecibelDetector {

  // 危险阈值
  static const double threshold = 50.0;

  // 计算分贝
  static double calculateDb(List<double> buffer) {

    if (buffer.isEmpty) {
      return 0;
    }

    double sum = 0;

    for (var sample in buffer) {
      sum += sample * sample;
    }

    double rms = sqrt(sum / buffer.length);

    if (rms == 0) {
      return 0;
    }

    double db = 20 * log(rms) / ln10;

    return db;
  }

  // 判断是否超过阈值
  static bool isDanger(double db) {

    if (db > threshold) {
      return true;
    }

    return false;
  }

}