class AudioBuffer {

  final int windowSize = 15600;
  final int hopSize = 4000;

  final List<double> _buffer = [];

  void addSamples(List<double> samples) {

    _buffer.addAll(samples);

  }

  bool get isReady => _buffer.length >= windowSize;

  List<double> popWindow() {

    final window = _buffer.sublist(0, windowSize);

    _buffer.removeRange(0, hopSize);

    return window;

  }
}