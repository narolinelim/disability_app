class AudioBuffer {

  final int windowSize = 15600;
  final int hopSize = 8000;

  final List<double> _buffer = [];

  // add samples into buffer
  void addSamples(List<double> samples) {

    _buffer.addAll(samples);

  }

  bool get isReady => _buffer.length >= windowSize;

  // create a fixed size window of samples and using hopsize as the size of sliding window
  List<double> popWindow() {

    final window = _buffer.sublist(0, windowSize);

    _buffer.removeRange(0, hopSize);

    return window;

  }
}